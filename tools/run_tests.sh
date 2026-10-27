#!/usr/bin/env bash
# Runs the test suite headless. Usage: tools/run_tests.sh [--filter=text] [--file=name]
# The GODOT environment variable names the Godot 4.7 executable (default: godot).
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-godot}"
# The first run, or one after a class was added, needs the editor's import to register the
# script classes. It is quick when nothing changed.
"$godot_bin" --headless --path . --import > /dev/null 2>&1 || true
exec "$godot_bin" --headless --path . -s test/run_tests.gd -- "$@"
