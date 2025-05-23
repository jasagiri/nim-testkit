#!/bin/sh
# TestKit test generator

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(dirname "$(realpath "$0")")
TESTKIT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
PROJECT_ROOT=$(dirname "$(dirname "$TESTKIT_DIR")")

# 設定ファイルのパス
CONFIG_PATH="$TESTKIT_DIR/config/nimtestkit.toml"

# テスト生成
cd "$PROJECT_ROOT" && nimtestkit_generator --config="$CONFIG_PATH" "$@"