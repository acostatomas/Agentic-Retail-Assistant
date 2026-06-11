@echo off
REM Launcher for setup.ps1 that handles execution policy
REM This .bat file can always run, then it launches PowerShell with the right policy

echo ========================================
echo Confluent Inventory Pipeline Setup
echo ========================================
echo.

REM Check if setup.ps1 exists
if not exist "%~dp0setup.ps1" (
    echo ERROR: setup.ps1 not found in the same directory
    pause
    exit /b 1
)

REM Run PowerShell with Bypass execution policy for this script only
powershell.exe -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*

REM Capture the exit code
set EXITCODE=%ERRORLEVEL%

REM If there was an error, pause so user can see it
if %EXITCODE% neq 0 (
    echo.
    echo Script failed with exit code %EXITCODE%
    pause
)

exit /b %EXITCODE%

@REM Made with Bob
