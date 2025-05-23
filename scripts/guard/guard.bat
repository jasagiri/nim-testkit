@echo off
:: Start the Nim TestKit guard (continuous testing)

:: Get script directory path
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%\..\..

:: Build and run test guard
cd "%ROOT_DIR%" && nim c -r src/test_guard.nim %*