#!/usr/bin/env bash
# Re-imports the project (registers new class_name scripts), then runs check_all and the tests.
set -u
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="$HOME/.local/bin/godot"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s tools/check_all.gd 2>&1 | grep -E "check_all|ERROR|✗" ; c=${PIPESTATUS[0]}
"$GODOT" --headless --path . -s tests/run_tests.gd 2>&1 | grep -E "^(PASS|FAIL|  |[0-9]+ passed)|SCRIPT ERROR|ERROR" ; t=${PIPESTATUS[0]}
echo "check_all exit=$c tests exit=$t"
[ "$c" -eq 0 ] && [ "$t" -eq 0 ]
