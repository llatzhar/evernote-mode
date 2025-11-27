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

### Export Notes

```bash
# Export a single note to Markdown
ruby local/bin/enlocal export-note <NOTE_GUID> --output my-note.md

# Export all notes in a notebook
ruby local/bin/enlocal export-notebook <NOTEBOOK_GUID> --output notebook-export

# Export all notes (flat structure)
ruby local/bin/enlocal export-all --output all-notes

# Export all notes organized by notebook
ruby local/bin/enlocal export-all --output all-notes --structure notebook

# Export with different filename formats
ruby local/bin/enlocal export-all --output all-notes --filename title
ruby local/bin/enlocal export-all --output all-notes --filename timestamp-title
ruby local/bin/enlocal export-all --output all-notes --filename guid-title

# Export with metadata index
ruby local/bin/enlocal export-all --output all-notes --structure notebook --index

# Export organized by date (YYYY/MM/)
ruby local/bin/enlocal export-all --output all-notes --structure date

# Export organized by tags
ruby local/bin/enlocal export-all --output all-notes --structure tag
```

**Export Options:**
- `--structure`: Directory organization
  - `flat`: All files in one directory (default)
  - `notebook`: Organize by notebook folders
  - `date`: Organize by creation date (YYYY/MM/)
  - `tag`: Organize by tags (one folder per tag)
- `--filename`: Filename format
  - `guid`: Use note GUID (default)
  - `title`: Use note title
  - `timestamp-title`: Use creation timestamp + title
  - `guid-title`: Use GUID + title
- `--index`: Create index.json with metadata

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

### Export workflow

```bash
# 1. List notebooks to find what you want to export
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode list-notebooks

# 2. Export a specific notebook with nice filenames
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-notebook <NOTEBOOK_GUID> \
  --output my-notebook \
  --filename timestamp-title

# 3. Export everything organized by notebook
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode \
  export-all \
  --output complete-backup \
  --structure notebook \
  --filename timestamp-title \
  --index
```

**Result structure:**
```
complete-backup/
├── index.json
├── Work/
│   ├── 20250115_meeting-notes.md
│   └── 20250120_project-plan.md
├── Personal/
│   ├── 20250110_shopping-list.md
│   └── 20250118_recipe.md
└── Archive/
    └── 20240301_old-note.md
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
