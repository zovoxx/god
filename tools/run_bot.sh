#!/usr/bin/env bash
# Runs the headless bot. Usage: tools/run_bot.sh [runs] [weapon|all] [extra args...]
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="$HOME/.local/bin/godot"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . -- --bot --runs="${1:-20}" --weapon="${2:-all}" "${@:3}"
