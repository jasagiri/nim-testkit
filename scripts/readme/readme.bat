@echo off
:: Generate README.md for Nim TestKit

:: Get script directory path
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%\..\..

:: Build and run README generator
cd "%ROOT_DIR%" && nim c -r scripts/readme/generate_readme.nim