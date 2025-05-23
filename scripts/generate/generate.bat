@echo off
:: Generate test files for Nim projects

:: Get script directory path
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%\..\..

:: Build and run test generator
cd "%ROOT_DIR%" && nim c -r src/test_generator.nim %*