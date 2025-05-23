@echo off
:: Install git hooks for Nim TestKit

:: Get the root directory
for /f "tokens=*" %%g in ('git rev-parse --show-toplevel 2^>nul') do set ROOT_DIR=%%g

if "%ROOT_DIR%"=="" (
  echo Error: Not inside a git repository
  exit /b 1
)

:: Check if hooks directory exists
if not exist "%ROOT_DIR%\.git\hooks" (
  echo Error: .git\hooks directory not found
  exit /b 1
)

:: Get the script directory
set "SCRIPT_PATH=%~dp0"
set "NIM_TESTKIT_DIR=%SCRIPT_PATH%..\..\"

:: Copy the pre-commit hook
copy "%SCRIPT_PATH%pre-commit" "%ROOT_DIR%\.git\hooks\" /Y

echo Git hooks installed successfully