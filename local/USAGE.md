# Evernote Local Cache - Example Usage

This document shows how to use the `enlocal` command-line tool.

## Important: Command Syntax

**Global options must come BEFORE the command:**

```bash
# ✅ Correct
ruby local/bin/enlocal --cache-dir PATH COMMAND [command-options]

# ❌ Wrong
ruby local/bin/enlocal COMMAND --cache-dir PATH
```

## Installation

No installation required. Just run the script directly with Ruby.

**Prerequisites**: GDBM library must be installed (see INSTALL.md)

## Basic Commands

### Show Cache Statistics

```bash
ruby local/bin/enlocal stats

# Use development cache
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode stats
```

Output shows:
- Cache directory location
- Lock status (whether evernote-mode is syncing)
- Number of notebooks, notes, tags, searches
- Last sync time and USN

### List Notebooks

```bash
# List all notebooks
ruby local/bin/enlocal list-notebooks

# Use development cache
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode list-notebooks
```

### List Tags

```bash
# Flat list
ruby local/bin/enlocal list-tags

# Tree view (showing hierarchy)
ruby local/bin/enlocal list-tags --tree
```

### List Saved Searches

```bash
ruby local/bin/enlocal list-searches
```

### List Notes

```bash
# List all notes (sorted by update time)
ruby local/bin/enlocal list-notes

# Filter by notebook
ruby local/bin/enlocal list-notes --notebook <NOTEBOOK_GUID>

# Filter by tag
ruby local/bin/enlocal list-notes --tag <TAG_GUID>

# Limit results
ruby local/bin/enlocal list-notes --limit 10

# Combine filters
ruby local/bin/enlocal list-notes --notebook <GUID> --tag <TAG_GUID> --limit 5
```

### Show Note Details

```bash
# Show note in plain text (default)
ruby local/bin/enlocal show-note <NOTE_GUID>

# Show note in ENML format
ruby local/bin/enlocal show-note <NOTE_GUID> --format enml
```

### Search Notes

```bash
# Search by title (case-insensitive substring match)
ruby local/bin/enlocal search "meeting"

# Limit search results
ruby local/bin/enlocal search "meeting" --limit 5
```

## Using Development Cache

To use the development cache at `C:\gits\.evernote-mode`:

```bash
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode stats
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode list-notes
```

## Examples

### Find notes in a specific notebook

```bash
# First, list notebooks to get GUID
ruby local/bin/enlocal list-notebooks

# Then list notes in that notebook
ruby local/bin/enlocal list-notes --notebook <NOTEBOOK_GUID>
```

### View recent notes

```bash
# Show 10 most recently updated notes
ruby local/bin/enlocal list-notes --limit 10
```

### Search and view

```bash
# Search for notes
ruby local/bin/enlocal search "todo"

# Show a specific note
ruby local/bin/enlocal show-note <GUID_FROM_SEARCH>
```

## Error Handling

The tool will show appropriate error messages:

- If cache directory doesn't exist
- If cache is locked (evernote-mode is syncing)
- If note/notebook/tag not found
- If note content is missing

## Debug Mode

Use `--debug` flag to see detailed error information:

```bash
ruby local/bin/enlocal --debug show-note <GUID>
```
