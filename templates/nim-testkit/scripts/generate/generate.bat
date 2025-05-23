@echo off
:: TestKit test generator

:: スクリプトのディレクトリを取得
set "SCRIPT_PATH=%~dp0"
set "NIM_TESTKIT_DIR=%SCRIPT_PATH%..\..\"
set "PROJECT_ROOT=%NIM_TESTKIT_DIR%..\..\"

:: 設定ファイルのパス
set "CONFIG_PATH=%NIM_TESTKIT_DIR%config\nimtestkit.toml"

:: テスト生成
cd "%PROJECT_ROOT%" && nimtestkit_generator --config="%CONFIG_PATH%" %*