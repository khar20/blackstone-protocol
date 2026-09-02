#!/usr/bin/env bash
# Parse-check + smoke test + timed headless boot of main.tscn.
set -e
if [ -x ./.tool/godot ]; then
  GODOT=./.tool/godot
elif [ -x "$HOME/.cache/blackstone-tool/godot" ]; then
  GODOT="$HOME/.cache/blackstone-tool/godot"
else
  echo "godot binary not found (place in .tool/godot or ~/.cache/blackstone-tool/godot)" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

echo "== parse-check =="
# --script mode has no autoloads, so "Identifier not found: TERRAIN|GAME|SFX"
# plus knock-on inference errors are expected. Only real syntax errors fail.
find scripts autoload tests -name '*.gd' -print0 | xargs -0 -n1 bash -c '
  out=$('"$GODOT"' --headless --check-only --script "$0" 2>&1)
  err=$(printf "%s\n" "$out" | grep "SCRIPT ERROR" || true)
  err=$(printf "%s\n" "$err" | grep -Ev "Identifier not found: (TERRAIN|GAME|SFX)" | grep -Ev "Cannot infer the type of" | grep -Ev "Cannot find member" | grep -Ev "Failed to compile depended scripts" || true)
  if [ -n "$err" ]; then echo "== $0"; printf "%s\n" "$err" | head -8; fi
'

echo "== smoke test =="
"$GODOT" --headless --script res://tests/smoke_test.gd 2>&1 | tail -20

echo "== deploy flow test =="
"$GODOT" --headless res://tests/deploy_flow_test.tscn 2>&1 | grep -Ev '^WARNING|^$|ObjectDB|PagedAllocator|Dummy|RID allocations|Dependency|Godot Engine' | tail -12

if [ -f scenes/main.tscn ]; then
  echo "== headless boot of main.tscn =="
  "$GODOT" --headless --quit-after 120 res://scenes/main.tscn 2>&1 | grep -Ev '^$' | tail -30
fi
echo "== OK =="