#!/bin/bash
# Phase 2 测试脚本：在新终端窗口启动一个 client 实例
# 用法：bash scripts/start_client.sh             # 使用 Standard (GDScript) 版本
#      bash scripts/start_client.sh --mono      # 使用 Mono (GDScript + C#) 版本
#      bash scripts/start_client.sh --path=...  # 指定自定义 Godot 路径

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# === 参数解析 ===
USE_MONO=false
CUSTOM_PATH=""
for arg in "$@"; do
	case "$arg" in
		--mono) USE_MONO=true ;;
		--path=*) CUSTOM_PATH="${arg#--path=}" ;;
	esac
done

# === 候选路径（按优先级）===
STANDARD_CANDIDATES=(
	"/Applications/Godot.app/Contents/MacOS/Godot"
	"/Applications/Godot 4.app/Contents/MacOS/Godot"
	"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
	"$HOME/Downloads/Godot 4.app/Contents/MacOS/Godot"
	"/opt/homebrew/bin/godot"
	"/usr/local/bin/godot"
)

MONO_CANDIDATES=(
	"/Applications/Godot_mono.app/Contents/MacOS/Godot"
	"/Applications/Godot Mono.app/Contents/MacOS/Godot"
	"/Applications/Godot 4 Mono.app/Contents/MacOS/Godot"
	"$HOME/Downloads/Godot_mono.app/Contents/MacOS/Godot"
	"/opt/homebrew/bin/godot-mono"
)

# === 查找 Godot ===
find_godot() {
	local candidates=("$@")
	for path in "${candidates[@]}"; do
		if [ -x "$path" ]; then
			echo "$path"
			return 0
		fi
	done
	return 1
}

# 用户自定义路径优先
if [ -n "$CUSTOM_PATH" ] && [ -x "$CUSTOM_PATH" ]; then
	GODOT_BIN="$CUSTOM_PATH"
elif [ "$USE_MONO" = true ]; then
	GODOT_BIN=$(find_godot "${MONO_CANDIDATES[@]}") || \
	GODOT_BIN=$(find_godot "${STANDARD_CANDIDATES[@]}") || true
else
	GODOT_BIN=$(find_godot "${STANDARD_CANDIDATES[@]}") || \
	GODOT_BIN=$(find_godot "${MONO_CANDIDATES[@]}") || true
fi

# === 错误处理 ===
if [ -z "$GODOT_BIN" ]; then
	echo "❌ 找不到 Godot 可执行文件"
	echo ""
	echo "已尝试以下路径："
	printf "  - %s\n" "${STANDARD_CANDIDATES[@]}"
	printf "  - %s\n" "${MONO_CANDIDATES[@]}"
	echo ""
	echo "可以这样做："
	echo "  1) 把 Godot.app 拖到 /Applications/"
	echo "  2) 或者用 --path 参数指定："
	echo "     bash scripts/start_client.sh --path=/你的/Godot/路径"
	exit 1
fi

# === 启动 ===
echo "🚀 启动 client 实例..."
echo "   项目: $PROJECT_DIR"
echo "   Godot: $GODOT_BIN"
echo "   版本: $("$GODOT_BIN" --version 2>&1 | head -1)"
echo ""
echo "💡 在另一个窗口/编辑器里按 F5 启动 host，再回到这里跑这个脚本"
echo "关闭 client 窗口即退出"

exec "$GODOT_BIN" --path "$PROJECT_DIR" -- --client
