# -*- coding: utf-8 -*-
#
# Evernote Local Cache Reader
# Phase 1: Basic read-only operations
#

begin
  require 'gdbm'
  GDBM_AVAILABLE = true
rescue LoadError
  GDBM_AVAILABLE = false
  # GDBM not available - some features will be disabled
end

require 'base64'
require 'cgi'
require 'fileutils'

module EnLocal
  VERSION = '0.1.0'

  class CacheError < StandardError; end
  class NotFoundError < CacheError; end
  class LockError < CacheError; end

  # EDAM object base module for deserialization
  module Serializable
    def deserialize(str)
      fields = str.split ","
      fields.each do |f|
        f =~ /\A([^=]*)=(.*)\z/
        next if $1.nil?
        
        varsym = $1.to_sym
        varval_str = $2
        vartype = serialized_fields[varsym]
        
        varval = decode_field_value(varval_str, vartype, varsym)
        setter = (varsym.to_s + "=").to_sym
        send(setter, varval) if respond_to?(setter)
      end
      self
    end

    private

    def decode_field_value(str, type, name)
      return nil if str.nil? || str.empty?
      
      case type
      when :field_type_int, :field_type_timestamp
        str.to_i
      when :field_type_bool
        str == "true"
      when :field_type_string
        str.force_encoding('UTF-8')
      when :field_type_string_array
        str.force_encoding('UTF-8').split("|")
      when :field_type_base64
        Base64.decode64(str).force_encoding('UTF-8')
      when :field_type_base64_array
        str.force_encoding('UTF-8').split("|").map { |s| Base64.decode64(s).force_encoding('UTF-8') }
      when :field_type_object
        decode_object(str, name)
      else
        str
      end
    end

    def decode_object(str, name)
      if name == :attributes
        attr = NoteAttributes.new
        deserialized = Base64.decode64(str)
        attr.deserialize(deserialized)
        attr
      else
        nil
      end
    end
  end

  # EDAM Type: Notebook
  class Notebook
    include Serializable
    
    attr_accessor :guid, :name, :updateSequenceNum, :defaultNotebook,
                  :serviceCreated, :serviceUpdated

    def serialized_fields
      {
        :guid => :field_type_string,
        :name => :field_type_base64,
        :updateSequenceNum => :field_type_int,
        :defaultNotebook => :field_type_bool,
        :serviceCreated => :field_type_timestamp,
        :serviceUpdated => :field_type_timestamp
      }
    end

    def to_s
      "Notebook(#{guid[0..7]}..., #{name})"
    end
  end

  # EDAM Type: Note
  class Note
    include Serializable
    
    attr_accessor :guid, :title, :created, :updated, :updateSequenceNum,
                  :notebookGuid, :tagGuids, :tagNames, :editMode,
                  :attributes, :resources, :contentFile

    def serialized_fields
      {
        :guid => :field_type_string,
        :title => :field_type_base64,
        :created => :field_type_timestamp,
        :updated => :field_type_timestamp,
        :updateSequenceNum => :field_type_int,
        :notebookGuid => :field_type_string,
        :tagGuids => :field_type_string_array,
        :tagNames => :field_type_base64_array,
        :editMode => :field_type_string,
        :attributes => :field_type_object,
        :resources => :field_type_string_array,
        :contentFile => :field_type_base64
      }
    end

    def to_s
      "Note(#{guid[0..7]}..., #{title})"
    end
  end

  # EDAM Type: NoteAttributes
  class NoteAttributes
    include Serializable
    
    attr_accessor :subjectDate, :latitude, :longitude, :altitude,
                  :author, :source, :sourceURL, :sourceApplication,
                  :shareDate, :reminderOrder, :reminderDoneTime,
                  :reminderTime, :placeName, :contentClass,
                  :lastEditedBy, :creatorId, :lastEditorId

    def serialized_fields
      {
        :subjectDate => :field_type_timestamp,
        :latitude => :field_type_int,
        :longitude => :field_type_int,
        :altitude => :field_type_int,
        :author => :field_type_string,
        :source => :field_type_string,
        :sourceURL => :field_type_string,
        :sourceApplication => :field_type_base64,
        :shareDate => :field_type_timestamp,
        :reminderOrder => :field_type_int,
        :reminderDoneTime => :field_type_timestamp,
        :reminderTime => :field_type_timestamp,
        :placeName => :field_type_string,
        :contentClass => :field_type_string,
        :lastEditedBy => :field_type_string,
        :creatorId => :field_type_string,
        :lastEditorId => :field_type_string
      }
    end
  end

  # EDAM Type: Tag
  class Tag
    include Serializable
    
    attr_accessor :guid, :name, :parentGuid, :updateSequenceNum

    def serialized_fields
      {
        :guid => :field_type_string,
        :name => :field_type_base64,
        :parentGuid => :field_type_string,
        :updateSequenceNum => :field_type_int
      }
    end

    def to_s
      "Tag(#{guid[0..7]}..., #{name})"
    end
  end

  # EDAM Type: SavedSearch
  class SavedSearch
    include Serializable
    
    attr_accessor :guid, :name, :query, :format, :updateSequenceNum

    def serialized_fields
      {
        :guid => :field_type_string,
        :name => :field_type_base64,
        :query => :field_type_base64,
        :format => :field_type_int,
        :updateSequenceNum => :field_type_int
      }
    end

    def to_s
      "SavedSearch(#{guid[0..7]}..., #{name})"
    end
  end

  # Database Manager - handles GDBM operations
  class DBManager
    attr_reader :sys_dir

    def initialize(sys_dir = nil)
      @sys_dir = sys_dir || File.expand_path("~/.evernote-mode")
      @lock_file = nil
      @in_transaction = false
      
      unless GDBM_AVAILABLE
        raise CacheError, "GDBM library not available. Please install: gem install gdbm"
      end
      
      validate_cache_directory!
    end

    def validate_cache_directory!
      unless File.directory?(@sys_dir)
        raise CacheError, "Cache directory not found: #{@sys_dir}"
      end
    end

    def lock_file_path
      File.join(@sys_dir, 'lock')
    end

    def sync_db_path
      File.join(@sys_dir, 'sync')
    end

    def notebook_db_path
      File.join(@sys_dir, 'notebook')
    end

    def note_db_path
      File.join(@sys_dir, 'note')
    end

    def tag_db_path
      File.join(@sys_dir, 'tag')
    end

    def search_db_path
      File.join(@sys_dir, 'saved_search')
    end

    def content_dir_path
      File.join(@sys_dir, 'contents')
    end

    def note_content_path(guid)
      File.join(content_dir_path, guid)
    end

    # Check if cache is locked (evernote-mode is syncing)
    def locked?
      return false unless File.exist?(lock_file_path)
      
      begin
        File.open(lock_file_path, 'r') do |f|
          # Try to get exclusive lock (non-blocking)
          return !f.flock(File::LOCK_EX | File::LOCK_NB)
        end
      rescue
        false
      end
    end

    # Transaction wrapper (read-only for phase 1)
    def transaction(&block)
      if @in_transaction
        yield
        return
      end

      @lock_file = File.open(lock_file_path, 'r')
      
      # Try to get shared lock (allows multiple readers)
      unless @lock_file.flock(File::LOCK_SH | File::LOCK_NB)
        @lock_file.close
        raise LockError, "Cache is locked (evernote-mode may be syncing)"
      end
      
      @in_transaction = true
      begin
        yield
      ensure
        @in_transaction = false
        @lock_file.flock(File::LOCK_UN)
        @lock_file.close
        @lock_file = nil
      end
    end

    # Read all entries from a GDBM database
    def read_all(db_path, klass)
      items = []
      transaction do
        GDBM.open(db_path, 0666, GDBM::READER) do |db|
          db.each_value do |value|
            obj = klass.new
            obj.deserialize(value)
            items << obj
          end
        end
      end
      items
    end

    # Read a single entry by key
    def read_one(db_path, key, klass)
      obj = nil
      transaction do
        GDBM.open(db_path, 0666, GDBM::READER) do |db|
          if db.has_key?(key)
            obj = klass.new
            obj.deserialize(db[key])
          end
        end
      end
      obj
    end

    # Read note content from file
    def read_note_content(guid)
      path = note_content_path(guid)
      return nil unless File.exist?(path)
      
      File.read(path, encoding: 'UTF-8')
    end

    # Get sync info
    def get_sync_info
      info = {}
      transaction do
        GDBM.open(sync_db_path, 0666, GDBM::READER) do |db|
          info[:last_sync] = db['last_sync']&.to_i || 0
          info[:usn] = db['usn']&.to_i || 0
        end
      end
      info
    end
  end

  # Cache Reader - high-level operations
  class CacheReader
    attr_reader :db

    def initialize(cache_dir = nil)
      @db = DBManager.new(cache_dir)
    end

    # Get all notebooks, sorted by name
    def list_notebooks
      notebooks = @db.read_all(@db.notebook_db_path, Notebook)
      notebooks.sort_by { |nb| nb.name || '' }
    end

    # Get notebook by GUID
    def get_notebook(guid)
      notebook = @db.read_one(@db.notebook_db_path, guid, Notebook)
      raise NotFoundError, "Notebook not found: #{guid}" unless notebook
      notebook
    end

    # Get all tags, sorted by name
    def list_tags
      tags = @db.read_all(@db.tag_db_path, Tag)
      tags.sort_by { |t| t.name || '' }
    end

    # Get tag by GUID
    def get_tag(guid)
      tag = @db.read_one(@db.tag_db_path, guid, Tag)
      raise NotFoundError, "Tag not found: #{guid}" unless tag
      tag
    end

    # Build tag hierarchy
    def build_tag_tree
      tags = list_tags
      
      # Create hash for quick lookup
      tag_hash = {}
      tags.each { |t| tag_hash[t.guid] = { tag: t, children: [] } }
      
      # Build tree
      roots = []
      tags.each do |tag|
        if tag.parentGuid && tag_hash[tag.parentGuid]
          tag_hash[tag.parentGuid][:children] << tag_hash[tag.guid]
        else
          roots << tag_hash[tag.guid]
        end
      end
      
      roots
    end

    # Get all saved searches, sorted by name
    def list_searches
      searches = @db.read_all(@db.search_db_path, SavedSearch)
      searches.sort_by { |s| s.name || '' }
    end

    # Get saved search by GUID
    def get_search(guid)
      search = @db.read_one(@db.search_db_path, guid, SavedSearch)
      raise NotFoundError, "Saved search not found: #{guid}" unless search
      search
    end

    # List all notes, sorted by updated time (newest first)
    def list_notes(notebook_guid: nil, tag_guids: nil)
      notes = @db.read_all(@db.note_db_path, Note)
      
      # Filter by notebook
      if notebook_guid
        notes.select! { |n| n.notebookGuid == notebook_guid }
      end
      
      # Filter by tags (note must have ALL specified tags)
      if tag_guids && !tag_guids.empty?
        notes.select! do |n|
          n.tagGuids && (tag_guids - n.tagGuids).empty?
        end
      end
      
      notes.sort_by { |n| -(n.updated || 0) }
    end

    # Get note by GUID
    def get_note(guid)
      note = @db.read_one(@db.note_db_path, guid, Note)
      raise NotFoundError, "Note not found: #{guid}" unless note
      note
    end

    # Get note content (ENML format)
    def get_note_content_enml(guid)
      note = get_note(guid)
      
      # Check if content file exists
      if note.contentFile && File.exist?(note.contentFile)
        return File.read(note.contentFile, encoding: 'UTF-8')
      end
      
      # Try default location
      content = @db.read_note_content(guid)
      return content if content
      
      raise NotFoundError, "Note content not found: #{guid}"
    end

    # Get note content as plain text (convert from ENML if needed)
    def get_note_content_text(guid)
      note = get_note(guid)
      enml = get_note_content_enml(guid)
      
      if note.editMode == 'TEXT'
        ENMLFormatter.enml_to_text(enml)
      else
        enml
      end
    end

    # Search notes by title (simple substring match)
    def search_notes_by_title(query)
      notes = list_notes
      pattern = Regexp.new(Regexp.escape(query), Regexp::IGNORECASE)
      notes.select { |n| n.title&.match?(pattern) }
    end

    # Get sync information
    def get_sync_info
      @db.get_sync_info
    end

    # Get cache statistics
    def get_stats
      {
        notebooks: list_notebooks.size,
        notes: list_notes.size,
        tags: list_tags.size,
        searches: list_searches.size,
        sync_info: get_sync_info
      }
    end
  end

  # ENML Formatter - convert between ENML and text
  module ENMLFormatter
    ENML_HEADER = '<?xml version="1.0" encoding="UTF-8"?>' \
                  '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">'
    ENML_OPEN = '<en-note>'
    ENML_CLOSE = '</en-note>'

    def self.enml_to_text(enml)
      return '' unless enml
      
      # Extract content between <en-note> tags
      if enml =~ /<en-note[^>]*>(.*)<\/en-note>/m
        content = $1
      else
        content = enml
      end
      
      # Convert ENML to plain text
      content = content.gsub(/<br[^>]*\/?>/m, "\n")
      content = content.gsub(/&nbsp;/, ' ')
      content = CGI.unescapeHTML(content)
      
      # Normalize line endings
      content.gsub(/(?:\r\n)|\r/, "\n")
    end

    def self.text_to_enml(text)
      return ENML_HEADER + ENML_OPEN + ENML_CLOSE if text.nil? || text.empty?
      
      # Escape HTML
      content = CGI.escapeHTML(text)
      
      # Convert formatting
      content = content.gsub(/ /, '&nbsp;')
      content = content.gsub(/(?:\r\n)|\n|\r/, '<br clear="none"/>')
      
      ENML_HEADER + ENML_OPEN + content + ENML_CLOSE
    end

    # Get edit mode from sourceApplication field
    def self.get_edit_mode(source_app)
      return 'XHTML' unless source_app
      
      if source_app.strip =~ /\Aemacs-enclient\s*\{.*:editmode\s*=>\s*"(TEXT|XHTML)"[^\}]*\}\z/
        $1
      else
        'XHTML'
      end
    end
  end
end
