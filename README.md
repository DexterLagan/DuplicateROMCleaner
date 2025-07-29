# Duplicate ROM Cleaner (PowerShell)

A powerful PowerShell script for finding and removing duplicate files on any disk drive. This command-line tool identifies files that exist both as compressed `.zip` archives and as standalone files with other extensions, helping you reclaim storage space while maintaining data integrity. Perfect for ROM collections, media archives, and automated cleanup workflows.
A cross-platform Python prototype (`duplicate-cleaner-py.py`) is included for CRC-based duplication checks and runs with Python 3.8 or newer.

## 🎯 Features

### Core Functionality
- **Smart Duplicate Detection**: Finds files with identical basenames where one is a `.zip` and another has a different extension
- **Content Verification**: Validates that duplicate files actually exist inside ZIP archives with matching file sizes
- **Orphan File Compression**: Automatically compresses standalone files (without corresponding ZIPs) into individual ZIP archives
- **Multi-Extension Support**: Handles any file extensions (`.rom`, `.stm`, `.mp3`, `.pdf`, etc.) alongside ZIP files

### Command-Line Power
- **Dry Run Mode**: Default safe mode that previews changes without executing them
- **Batch Processing**: Process entire drives automatically with command-line parameters
- **Scriptable**: Integrate into automated workflows and batch files
- **Per-Folder Confirmation**: Interactive mode with confirmation for each folder
- **Detailed Logging**: Comprehensive console output with colored status messages

### Safety Features
- **Double Confirmation**: Two-level confirmation system prevents accidental deletions
- **Protected Directory Handling**: Automatically skips system and hidden directories
- **Drive Selection GUI**: Interactive dropdown for selecting target drives
- **Verification Checks**: Ensures ZIP contents match before any deletions
- **Error Handling**: Graceful recovery from access issues

## 📋 How It Works

### Duplicate Detection Process
1. **Recursive Scanning**: Walks through all directories on the selected drive
2. **File Grouping**: Groups files by basename (filename without extension)
3. **ZIP Matching**: Identifies groups containing both `.zip` files and other extensions
4. **Content Verification**: Extracts and compares file sizes to ensure actual duplicates
5. **Safe Deletion**: Only deletes verified duplicates after user confirmation

### Orphan Processing
1. **Orphan Identification**: Finds files without corresponding ZIP archives
2. **Individual Compression**: Creates separate ZIP file for each orphan
3. **Integrity Verification**: Confirms successful compression before deleting originals
4. **Rollback Protection**: Keeps originals if compression fails

### Example Scenario
```
Before:
E:\ROMS\arcade\
├── pacman.zip      (contains pacman.rom)
├── pacman.rom      (duplicate - will be deleted)
├── galaga.zip      (contains galaga.rom)
├── galaga.rom      (duplicate - will be deleted)
├── pinball.rom     (orphan - will be compressed)
└── readme.txt      (no ZIP pair - ignored)

After:
E:\ROMS\arcade\
├── pacman.zip      (unchanged)
├── galaga.zip      (unchanged)
├── pinball.zip     (newly created from pinball.rom)
└── readme.txt      (unchanged)
```

## 🚀 Quick Start

### Option 1: Interactive Mode (Recommended)
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/[your-username]/duplicate-rom-cleaner/main/duplicate-cleaner.ps1" -OutFile "duplicate-cleaner.ps1"

# Run in safe dry-run mode
.\duplicate-cleaner.ps1
```

### Option 2: Direct Execution
```powershell
# Execute with orphan compression
.\duplicate-cleaner.ps1 -Execute -CompressOrphans

# Dry run with orphan compression preview
.\duplicate-cleaner.ps1 -CompressOrphans
```

### Option 3: One-Click Batch File
Create `CleanROMs.bat`:
```batch
@echo off
powershell.exe -ExecutionPolicy Bypass -File "duplicate-cleaner.ps1" -Execute -CompressOrphans
pause
```

### Option 4: Python Prototype
```bash
python duplicate-cleaner-py.py PATH_TO_DRIVE_OR_FOLDER [-e] [-c]
# Example: process drive D with deletion and compression
python duplicate-cleaner-py.py D:\\ -e -c
```

## 📖 Usage Instructions

### Command-Line Parameters
```powershell
.\duplicate-cleaner.ps1 [Parameters]

Parameters:
  -Execute           Actually perform deletions (default: dry run only)
  -CompressOrphans   Enable orphan file compression to ZIP
```

### Usage Examples
```powershell
# Safe preview mode (default)
.\duplicate-cleaner.ps1

# Preview with orphan compression
.\duplicate-cleaner.ps1 -CompressOrphans

# Execute duplicate removal only
.\duplicate-cleaner.ps1 -Execute

# Full cleanup: duplicates + orphan compression
.\duplicate-cleaner.ps1 -Execute -CompressOrphans
```

### Interactive Workflow
1. **Drive Selection**: GUI popup shows available drives (D: and above)
2. **Folder Processing**: Script processes each folder individually
3. **Results Display**: Shows found duplicates and orphans with file sizes
4. **Confirmation Prompts**: 
   - First confirmation: "Delete these X files?"
   - Second confirmation: "Are you REALLY sure?"
5. **Progress Updates**: Real-time status with colored output
6. **Final Summary**: Total statistics at completion

### Sample Output
```
SD Card Duplicate File Cleaner
================================
Selected drive: E:

*** DRY RUN MODE - No files will be deleted ***
*** ORPHAN COMPRESSION ENABLED ***

Scanning for folders...
Found 1,247 folders to process.

================================================================================
Processing folder: E:\ROMS\arcade
================================================================================

Phase 1: Scanning for duplicates...
  Checking: pacman.rom vs pacman.zip...
    [MATCH] Match confirmed!

Found 1 duplicate(s):
  - pacman.rom (2.5 MB)

[DRY RUN] These files would be deleted.

Phase 2: Scanning for orphan files...
Found 1 orphan file(s):
  - pinball.rom (1.8 MB)
    Would compress: pinball.rom -> pinball.zip

[DRY RUN] These files would be compressed and originals deleted.

================================================================================
FINAL SUMMARY
================================================================================
Duplicates found: 245
Duplicates removed: 0
Orphans found: 89
Orphans compressed: 0
```

## 🛠️ System Requirements

### Windows Compatibility
- **Operating System**: Windows 10/11, Windows Server 2016+
- **PowerShell**: Version 5.1 or higher (included with Windows)
- **Execution Policy**: Must allow script execution (handled by batch file)
- **Permissions**: Standard user account sufficient

### Dependencies
- **Built-in**: Uses only native Windows PowerShell modules
- **System.Windows.Forms**: For drive selection GUI (included)
- **System.Shell.Application**: For ZIP file operations (included)
- **No external dependencies**: Works on any Windows system out-of-the-box

### Performance
- **Memory Usage**: Minimal - processes one file at a time
- **Disk I/O**: Efficient streaming for large files
- **Error Handling**: Graceful recovery from access denied errors
- **Threading**: Single-threaded with progress reporting

## 🏗️ Installation & Setup

### Method 1: Direct Download
```powershell
# Download script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/[your-username]/duplicate-rom-cleaner/main/duplicate-cleaner.ps1" -OutFile "duplicate-cleaner.ps1"

# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the script
.\duplicate-cleaner.ps1
```

### Method 2: Git Clone
```bash
git clone https://github.com/[your-username]/duplicate-rom-cleaner.git
cd duplicate-rom-cleaner
```

### Method 3: Manual Setup
1. Download `duplicate-cleaner.ps1` to any folder
2. Right-click the file → "Run with PowerShell"
3. Or create a batch file for one-click execution

### Execution Policy Issues
If you get execution policy errors:
```powershell
# Temporary bypass (recommended)
powershell.exe -ExecutionPolicy Bypass -File "duplicate-cleaner.ps1"

# Or enable for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 🔧 Advanced Usage

### Automated Workflows
```powershell
# Process multiple drives
foreach ($drive in @('D:', 'E:', 'F:')) {
    Write-Host "Processing $drive..."
    .\duplicate-cleaner.ps1 -Execute -CompressOrphans -DrivePath $drive
}

# Integration with task scheduler
schtasks /create /tn "ROM Cleanup" /tr "powershell.exe -File C:\Scripts\duplicate-cleaner.ps1 -Execute" /sc weekly
```

### Custom Filtering
The script can be modified to:
- Skip specific file extensions
- Process only certain folder patterns
- Add custom compression levels
- Implement size-based filtering

### Logging Output
```powershell
# Save log to file
.\duplicate-cleaner.ps1 -Execute 2>&1 | Tee-Object -FilePath "cleanup-log.txt"

# Detailed timestamps
.\duplicate-cleaner.ps1 -Execute | ForEach-Object { "$(Get-Date): $_" }
```

## 🐛 Troubleshooting

### Common Issues

**Execution Policy Errors**
```
Solution: Use -ExecutionPolicy Bypass parameter or set RemoteSigned policy
```

**Access Denied Errors**
```
Behavior: Script automatically skips and continues - this is normal
Common Causes: System folders, encrypted files, files in use
```

**ZIP Verification Failures**
```
Behavior: Files are kept safe, warnings displayed
Common Causes: Corrupted archives, incomplete downloads
```

**Drive Not Listed**
```
Cause: Only drives D: and above are shown (excludes system drive C:)
Solution: This is by design for safety
```

### Debug Mode
```powershell
# Enable detailed debug output
$DebugPreference = "Continue"
.\duplicate-cleaner.ps1 -Execute -CompressOrphans
```

### Performance Optimization
- **Large Collections**: Process subfolders individually
- **Network Drives**: Ensure stable connections
- **Low Memory**: Close other applications during processing

## 🤝 Contributing

Contributions are welcome! This PowerShell script is perfect for:
- Adding custom filtering options
- Implementing new compression formats
- Enhancing error handling
- Adding logging features

### Development Guidelines
- Test thoroughly in dry-run mode first
- Maintain backward compatibility
- Add appropriate error handling
- Document new parameters and features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
