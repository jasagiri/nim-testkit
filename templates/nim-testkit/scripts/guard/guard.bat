@echo off
:: TestKit guard (continuous testing)

:: スクリプトのディレクトリを取得
set "SCRIPT_PATH=%~dp0"
set "NIM_TESTKIT_DIR=%SCRIPT_PATH%..\..\"
set "PROJECT_ROOT=%NIM_TESTKIT_DIR%..\..\"

:: 設定ファイルのパス
set "CONFIG_PATH=%NIM_TESTKIT_DIR%config\nimtestkit.toml"

:: テストガード実行
cd "%PROJECT_ROOT%" && nimtestkit_guard --config="%CONFIG_PATH%" %*