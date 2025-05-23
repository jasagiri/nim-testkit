@echo off
:: TestKit coverage generator

:: スクリプトのディレクトリを取得
set "SCRIPT_PATH=%~dp0"
set "NIM_TESTKIT_DIR=%SCRIPT_PATH%..\..\"
set "PROJECT_ROOT=%NIM_TESTKIT_DIR%..\..\"

:: 設定ファイルのパス
set "CONFIG_PATH=%NIM_TESTKIT_DIR%config\nimtestkit.toml"

:: カバレッジ出力ディレクトリ
if not exist "%PROJECT_ROOT%\build\coverage\html" mkdir "%PROJECT_ROOT%\build\coverage\html"
if not exist "%PROJECT_ROOT%\build\coverage\raw" mkdir "%PROJECT_ROOT%\build\coverage\raw"

:: カバレッジフラグ付きでテスト実行
cd "%PROJECT_ROOT%" && nimtestkit_coverage --config="%CONFIG_PATH%" %*