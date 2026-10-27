#!/usr/bin/env bash
# Saves a screenshot of the app in a named state. See tools/shoot.gd for the scenarios.
# Usage: tools/shoot.sh <scenario> <out.png> [file-to-open] [WIDTHxHEIGHT]
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-godot}"
args=(--scenario="$1" --out="$2")
[ -n "${3:-}" ] && args+=(--open="$3")
[ -n "${4:-}" ] && args+=(--size="$4")
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$(mktemp -d)}"
exec timeout 120 xvfb-run -a -s "-screen 0 1280x800x24" "$godot_bin" --path . \
  --rendering-driver opengl3 -s tools/shoot.gd -- "${args[@]}"
