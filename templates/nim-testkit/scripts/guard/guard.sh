#!/bin/sh
# TestKit guard (continuous testing)

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(dirname "$(realpath "$0")")
TESTKIT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
PROJECT_ROOT=$(dirname "$(dirname "$TESTKIT_DIR")")

# 設定ファイルのパス
CONFIG_PATH="$TESTKIT_DIR/config/nimtestkit.toml"

# テストガード実行
cd "$PROJECT_ROOT" && nimtestkit_guard --config="$CONFIG_PATH" "$@"