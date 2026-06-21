#!/bin/bash
# Phase 2 测试脚本：在新终端窗口启动一个 client 实例
# 用法：在终端运行 bash scripts/start_client.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

if [ ! -x "$GODOT_BIN" ]; then
	echo "❌ 找不到 Godot 可执行文件: $GODOT_BIN"
	echo "请修改此脚本中的 GODOT_BIN 为你的实际路径"
	echo "常见路径："
	echo "  - /Applications/Godot.app/Contents/MacOS/Godot  (官方下载)"
	echo "  - /opt/homebrew/bin/godot                       (Homebrew)"
	exit 1
fi

echo "🚀 启动 client 实例..."
echo "   项目: $PROJECT_DIR"
echo "   Godot: $GODOT_BIN"
echo ""
echo "关闭 client 窗口即退出。当前窗口可以继续用 F5 启动 host。"

exec "$GODOT_BIN" --path "$PROJECT_DIR" -- --client
