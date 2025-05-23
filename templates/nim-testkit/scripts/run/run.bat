@echo off
:: TestKit test runner

:: スクリプトのディレクトリを取得
set "SCRIPT_PATH=%~dp0"
set "NIM_TESTKIT_DIR=%SCRIPT_PATH%..\..\"
set "PROJECT_ROOT=%NIM_TESTKIT_DIR%..\..\"

:: 引数が指定されていれば使用、なければデフォルトのパターン
set "TEST_PATTERN=%1"
if "%TEST_PATTERN%"=="" set "TEST_PATTERN=test_*.nim"

:: 設定ファイルのパス
set "CONFIG_PATH=%NIM_TESTKIT_DIR%config\nimtestkit.toml"

:: テストの実行
cd "%PROJECT_ROOT%" && nimtestkit_runner --config="%CONFIG_PATH%" "%TEST_PATTERN%"