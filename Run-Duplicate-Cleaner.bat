@echo off
REM SD Card Duplicate File Cleaner - Desktop Launcher
REM This batch file runs the PowerShell script with -Execute -CompressOrphans parameters

echo =====================================
echo SD Card Duplicate File Cleaner
echo =====================================
echo.
echo This tool will:
echo - Find and DELETE duplicate files
echo - Compress orphan files to ZIP format
echo - DELETE original orphan files after compression
echo.
echo WARNING: This is NOT a dry run!
echo Files WILL be permanently deleted!
echo.
pause

REM Change to the directory where this batch file is located
cd /d "%~dp0"

REM Check if the PowerShell script exists
if not exist "duplicate-cleaner.ps1" (
    echo ERROR: duplicate-cleaner.ps1 not found in the same folder!
    echo Please make sure both files are in the same directory.
    echo.
    pause
    exit /b 1
)

echo.
echo Starting PowerShell script...
echo.

REM Run PowerShell script with execution policy bypass and desired parameters
powershell.exe -ExecutionPolicy Bypass -File "duplicate-cleaner.ps1" -Execute -CompressOrphans

REM Check if PowerShell completed successfully
if %ERRORLEVEL% neq 0 (
    echo.
    echo PowerShell script encountered an error.
    echo Error code: %ERRORLEVEL%
) else (
    echo.
    echo Script completed successfully.
)

echo.
echo =====================================
echo Press any key to close this window...
pause >nul