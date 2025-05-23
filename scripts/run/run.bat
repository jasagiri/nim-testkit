@echo off
:: Run Nim TestKit tests

:: Get script directory path
set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%\..\..

:: Build and run test runner
cd "%ROOT_DIR%" && nim c -r -d:powerAssert src/test_runner.nim %*