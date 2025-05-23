#!/bin/sh
# TestKit test runner

# スクリプトのディレクトリを取得
SCRIPT_DIR=$(dirname "$(realpath "$0")")
TESTKIT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
PROJECT_ROOT=$(dirname "$(dirname "$TESTKIT_DIR")")

# 引数が指定されていれば使用、なければデフォルトのパターン
TEST_PATTERN=${1:-"test_*.nim"}

# 設定ファイルのパス
CONFIG_PATH="$TESTKIT_DIR/config/nimtestkit.toml"

# テストの実行
cd "$PROJECT_ROOT" && nimtestkit_runner --config="$CONFIG_PATH" "$TEST_PATTERN"