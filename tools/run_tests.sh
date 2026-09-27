#!/usr/bin/env bash
# Esegue i test headless. GODOT puo' puntare a un eseguibile diverso.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/Godot_v4.7.2-stable_linux.x86_64}
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd
