# -*- coding: utf-8 -*-
#
# Evernote Prefetch - Fetch note contents from service and populate cache
#
# This tool communicates with Evernote service to download note contents
# that haven't been cached yet. Unlike enlocal (local-only), this requires
# network access and uses the existing enclient.rb infrastructure.
#

require 'fileutils'

# Add parent directory to load path to access enclient.rb
$LOAD_PATH.unshift File.expand_path('../../ruby/bin', __FILE__)

begin
  require_relative '../../ruby/bin/enclient'
rescue LoadError => e
  puts "Error: Cannot load enclient.rb"
  puts "Make sure enclient.rb exists at: ruby/bin/enclient.rb"
  puts "Error details: #{e.message}"
  exit 1
end

module EnPrefetch
  VERSION = '0.1.0'

  class Prefetcher
    attr_reader :dm, :sm, :stats

    def initialize(cache_dir = nil)
      cache_dir ||= File.expand_path("~/.evernote-mode")
      @cache_dir = cache_dir
      
      # Override EnClient::DBManager constants if custom cache dir is specified
      if cache_dir != File.expand_path("~/.evernote-mode")
        override_db_paths(cache_dir)
      end
      
      @dm = EnClient::DBManager.new
      @sm = EnClient::SessionManager.new
      @stats = {
        total: 0,
        cached: 0,
        fetched: 0,
        failed: 0,
        skipped: 0
      }
    end

    # Authenticate with developer token
    def authenticate(token)
      puts "Authenticating with developer token..."
      @sm.authenticate_with_token(token)
      puts "Authentication successful!"
      puts "  Shard ID: #{@sm.shared_id}"
    end

    # Check which notes need content fetching
    def analyze_cache
      puts "Analyzing cache..."
      
      notes = EnClient::DBUtils.get_all_notes(@dm)
      @stats[:total] = notes.size
      
      missing = []
      cached = []
      
      notes.each do |note|
        content_path = @dm.class::CONTENT_DIR + note.guid
        if File.exist?(content_path)
          cached << note
        else
          missing << note
        end
      end
      
      @stats[:cached] = cached.size
      
      puts "\nCache Analysis:"
      puts "  Total notes: #{@stats[:total]}"
      puts "  Cached: #{@stats[:cached]} (#{(@stats[:cached] * 100.0 / @stats[:total]).round(1)}%)"
      puts "  Missing: #{missing.size} (#{(missing.size * 100.0 / @stats[:total]).round(1)}%)"
      
      missing
    end

    # Fetch all missing note contents
    def fetch_all_missing(options = {})
      dry_run = options[:dry_run] || false
      limit = options[:limit]
      missing = analyze_cache
      
      if missing.empty?
        puts "\nAll notes are already cached!"
        return
      end
      
      puts "\nPlan: Fetch #{missing.size} note(s)"
      
      if limit
        missing = missing.take(limit)
        puts "  Limited to: #{limit} note(s)"
      end
      
      if dry_run
        puts "\nDry run mode - no actual fetching"
        missing.each_with_index do |note, i|
          puts "  [#{i + 1}/#{missing.size}] Would fetch: #{note.title}"
        end
        return
      end
      
      puts "\nFetching note contents..."
      puts "  This may take a while for large numbers of notes"
      puts "  Progress will be displayed every 10 notes"
      puts
      
      missing.each_with_index do |note, i|
        begin
          fetch_note_content(note)
          @stats[:fetched] += 1
          
          if (i + 1) % 10 == 0
            progress = ((i + 1) * 100.0 / missing.size).round(1)
            puts "  Progress: #{i + 1}/#{missing.size} (#{progress}%) - Latest: #{note.title[0..50]}"
          end
          
          # Rate limiting - sleep briefly to avoid overwhelming the server
          sleep 0.1
          
        rescue => e
          @stats[:failed] += 1
          puts "  ERROR [#{i + 1}/#{missing.size}] Failed to fetch: #{note.title}"
          puts "    #{e.message}"
          
          # Continue with next note
        end
      end
      
      puts "\nFetch completed!"
      print_stats
    end

    # Fetch content for a specific note by GUID
    def fetch_note(guid)
      note = @dm.transaction do
        @dm.open_note do |db|
          if db.has_key?(guid)
            n = Evernote::EDAM::Type::Note.new
            n.deserialize(db[guid])
            n
          else
            nil
          end
        end
      end
      
      unless note
        puts "Error: Note not found in cache: #{guid}"
        return
      end
      
      puts "Fetching note: #{note.title}"
      fetch_note_content(note)
      puts "Success!"
    end

    # Verify cache integrity
    def verify_cache
      puts "Verifying cache integrity..."
      
      notes = EnClient::DBUtils.get_all_notes(@dm)
      @stats[:total] = notes.size
      
      verified = 0
      missing = 0
      corrupted = 0
      
      notes.each_with_index do |note, i|
        content_path = @dm.class::CONTENT_DIR + note.guid
        
        if File.exist?(content_path)
          # Check if file is readable and has content
          begin
            content = File.read(content_path, encoding: 'UTF-8')
            if content && content.length > 0
              verified += 1
            else
              corrupted += 1
              puts "  WARNING: Empty content file for: #{note.title}"
            end
          rescue => e
            corrupted += 1
            puts "  ERROR: Cannot read content for: #{note.title}"
            puts "    #{e.message}"
          end
        else
          missing += 1
        end
        
        if (i + 1) % 100 == 0
          puts "  Progress: #{i + 1}/#{notes.size}"
        end
      end
      
      puts "\nVerification Results:"
      puts "  Total notes: #{@stats[:total]}"
      puts "  Verified: #{verified} (#{(verified * 100.0 / @stats[:total]).round(1)}%)"
      puts "  Missing: #{missing} (#{(missing * 100.0 / @stats[:total]).round(1)}%)"
      puts "  Corrupted: #{corrupted} (#{(corrupted * 100.0 / @stats[:total]).round(1)}%)"
      
      { verified: verified, missing: missing, corrupted: corrupted }
    end

    private

    def fetch_note_content(note)
      # Fetch full note with content from service
      full_note = @sm.note_store.getNote(
        @sm.auth_token,
        note.guid,
        true,   # withContent
        false,  # withResourcesData
        false,  # withResourcesRecognition
        false   # withResourcesAlternateData
      )
      
      # Set edit mode
      source_app = full_note.attributes ? full_note.attributes.sourceApplication : nil
      full_note.editMode = EnClient::Formatter.get_edit_mode(source_app)
      
      # Format content based on edit mode
      content = format_content(full_note.content, full_note.editMode)
      
      # Save to cache
      EnClient::DBUtils.set_note_and_content(@dm, full_note, content)
    end

    def format_content(enml_content, edit_mode)
      return nil unless enml_content
      
      # Normalize line endings
      enml_content.gsub!(/(?:\r\n)|\n|\r/, "\n")
      
      if edit_mode == "TEXT"
        # Extract content from ENML
        if enml_content =~ /<en-note[^>]*>(.*)<\/en-note>/m
          content = $1
        else
          content = enml_content
        end
        
        # Convert ENML to plain text
        content = content.gsub(/<br[^>]*\/?>/m, "\n")
        content = content.gsub(/&nbsp;/, ' ')
        content = CGI.unescapeHTML(content)
        content
      else
        # XHTML mode - return as is
        enml_content
      end
    end

    def print_stats
      puts "\nStatistics:"
      puts "  Total notes: #{@stats[:total]}"
      puts "  Already cached: #{@stats[:cached]}"
      puts "  Newly fetched: #{@stats[:fetched]}"
      puts "  Failed: #{@stats[:failed]}"
      puts "  Skipped: #{@stats[:skipped]}"
    end
    
    private
    
    def override_db_paths(cache_dir)
      # Remove trailing slash if present, then add it
      cache_dir = cache_dir.chomp('/').chomp('\\') + '/'
      
      # Override DBManager constants
      EnClient::DBManager.send(:remove_const, :ENMODE_SYS_DIR)
      EnClient::DBManager.const_set(:ENMODE_SYS_DIR, cache_dir)
      
      EnClient::DBManager.send(:remove_const, :DB_LOCK)
      EnClient::DBManager.const_set(:DB_LOCK, cache_dir + 'lock')
      
      EnClient::DBManager.send(:remove_const, :DB_SYNC)
      EnClient::DBManager.const_set(:DB_SYNC, cache_dir + 'sync')
      
      EnClient::DBManager.send(:remove_const, :DB_NOTEBOOK)
      EnClient::DBManager.const_set(:DB_NOTEBOOK, cache_dir + 'notebook')
      
      EnClient::DBManager.send(:remove_const, :DB_NOTE)
      EnClient::DBManager.const_set(:DB_NOTE, cache_dir + 'note')
      
      EnClient::DBManager.send(:remove_const, :DB_TAG)
      EnClient::DBManager.const_set(:DB_TAG, cache_dir + 'tag')
      
      EnClient::DBManager.send(:remove_const, :DB_SAVED_SEARCH)
      EnClient::DBManager.const_set(:DB_SAVED_SEARCH, cache_dir + 'saved_search')
      
      EnClient::DBManager.send(:remove_const, :CONTENT_DIR)
      EnClient::DBManager.const_set(:CONTENT_DIR, cache_dir + 'contents/')
    end
  end
end

# Extend EnClient::DBUtils with get_all_notes method
class EnClient::DBUtils
  def self.get_all_notes(dm)
    notes = []
    dm.transaction do
      dm.open_note do |db|
        db.each_value do |value|
          n = Evernote::EDAM::Type::Note.new
          n.deserialize(value)
          notes << n
        end
      end
    end
    notes
  end
end

# CLI interface
if __FILE__ == $0
  require 'optparse'

  options = {
    cache_dir: nil,
    token: ENV['EVERNOTE_TOKEN'],
    dry_run: false,
    limit: nil
  }

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: enprefetch.rb [OPTIONS] COMMAND"
    opts.separator ""
    opts.separator "Commands:"
    opts.separator "  analyze                    Analyze cache and show missing notes"
    opts.separator "  fetch-all                  Fetch all missing note contents"
    opts.separator "  fetch-note GUID            Fetch content for specific note"
    opts.separator "  verify                     Verify cache integrity"
    opts.separator ""
    opts.separator "Options:"

    opts.on("--cache-dir DIR", "Cache directory (default: ~/.evernote-mode)") do |dir|
      options[:cache_dir] = dir
    end

    opts.on("--token TOKEN", "Developer token (or set EVERNOTE_TOKEN env var)") do |token|
      options[:token] = token
    end

    opts.on("--dry-run", "Show what would be fetched without fetching") do
      options[:dry_run] = true
    end

    opts.on("--limit N", Integer, "Limit number of notes to fetch") do |n|
      options[:limit] = n
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit 0
    end

    opts.on("--version", "Show version") do
      puts "enprefetch version #{EnPrefetch::VERSION}"
      exit 0
    end
  end

  parser.parse!

  command = ARGV.shift
  command_args = ARGV

  unless command
    puts "Error: No command specified"
    puts
    puts parser
    exit 1
  end

  # Check if token is required for the command
  requires_token = ['fetch-all', 'fetch-note'].include?(command)
  
  if requires_token && !options[:token]
    puts "Error: Developer token required for '#{command}' command"
    puts "  Set EVERNOTE_TOKEN environment variable, or use --token option"
    puts
    puts "To get a developer token:"
    puts "  1. Go to https://www.evernote.com/api/DeveloperToken.action"
    puts "  2. Sign in and create a token"
    puts "  3. Set it as: $env:EVERNOTE_TOKEN='your-token-here'"
    exit 1
  end

  begin
    prefetcher = EnPrefetch::Prefetcher.new(options[:cache_dir])
    
    # Only authenticate if token is required
    if requires_token
      prefetcher.authenticate(options[:token])
    end

    case command
    when 'analyze'
      prefetcher.analyze_cache

    when 'fetch-all'
      prefetcher.fetch_all_missing(
        :dry_run => options[:dry_run],
        :limit => options[:limit]
      )

    when 'fetch-note'
      if command_args.empty?
        puts "Error: Note GUID required"
        exit 1
      end
      prefetcher.fetch_note(command_args[0])

    when 'verify'
      prefetcher.verify_cache

    else
      puts "Error: Unknown command: #{command}"
      puts
      puts parser
      exit 1
    end

  rescue EnClient::NotAuthedException => e
    puts "Authentication Error: #{e.message}"
    exit 1
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
