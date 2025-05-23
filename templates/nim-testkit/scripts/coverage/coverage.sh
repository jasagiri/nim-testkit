#!/bin/sh
# TestKit coverage generator

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(dirname "$(realpath "$0")")
TESTKIT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
PROJECT_ROOT=$(dirname "$(dirname "$TESTKIT_DIR")")

# 設定ファイルのパス
CONFIG_PATH="$TESTKIT_DIR/config/nimtestkit.toml"

# カバレッジ出力ディレクトリ
mkdir -p "$PROJECT_ROOT/build/coverage/html" "$PROJECT_ROOT/build/coverage/raw"

# カバレッジフラグ付きでテスト実行
cd "$PROJECT_ROOT" && nimtestkit_coverage --config="$CONFIG_PATH" "$@"