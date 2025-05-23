@echo off
:: Generate code coverage reports for Nim TestKit

:: Get script directory path
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%\..\..

:: Build and run coverage helper
cd "%ROOT_DIR%" && nim c -r src/coverage_helper.nim %*