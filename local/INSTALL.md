# Installation Guide

## Prerequisites

Ruby 2.0 or higher is required.

## Installing Dependencies

### GDBM Library

The GDBM library is required to read the Evernote cache database.

#### On Windows

GDBM can be challenging to install on Windows. Here are the options:

**Option 1: Use Ruby installer with DevKit**

If you installed Ruby using RubyInstaller with DevKit:

```powershell
ridk exec pacman -S mingw-w64-x86_64-gdbm
gem install gdbm
```

**Option 2: Use pre-built binary gem**

Some Ruby distributions include GDBM. Check if it's available:

```powershell
ruby -e "require 'gdbm'; puts 'GDBM is available'"
```

**Option 3: Alternative - Use DBM (if GDBM unavailable)**

Note: This would require modifying the code to use DBM instead of GDBM.

#### On Linux/macOS

```bash
# Install GDBM library (if not already installed)
# Ubuntu/Debian:
sudo apt-get install libgdbm-dev

# macOS with Homebrew:
brew install gdbm

# Then install Ruby gem
gem install gdbm
```

### Other Dependencies

All other dependencies are part of Ruby standard library:
- `base64` - Standard library
- `cgi` - Standard library
- `optparse` - Standard library
- `fileutils` - Standard library
- `time` - Standard library

## Verification

After installing dependencies, verify the installation:

```bash
ruby local/bin/enlocal --version
```

If successful, you should see:
```
enlocal version 0.1.0
```

## Testing with Development Cache

To test if everything works, run:

```bash
ruby local/bin/enlocal --cache-dir C:\gits\.evernote-mode stats
```

This will show cache statistics if the cache exists and the tool is working correctly.

## Troubleshooting

### GDBM not available on Windows

If you cannot install GDBM on Windows, you have several options:

1. **Use WSL (Windows Subsystem for Linux)**: Install Ruby and GDBM in WSL
2. **Use Docker**: Run the tool in a Docker container
3. **Modify the code**: Implement a DBM fallback (DBM is included in Ruby standard library)

### Cache directory not found

Make sure the cache directory exists:
```powershell
Test-Path C:\gits\.evernote-mode
```

If it doesn't exist, you need to run evernote-mode in Emacs first to create the cache.

### Permission errors

Make sure you have read permissions on the cache directory and its files.
