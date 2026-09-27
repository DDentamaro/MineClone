#!/usr/bin/env bash
# Esegue i test headless. GODOT puo' puntare a un eseguibile diverso.
# Fallisce anche se il log contiene errori di script o del motore: in GDScript
# un errore a runtime non interrompe il test che lo provoca.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/Godot_v4.7.2-stable_linux.x86_64}
LOG=$(mktemp)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error" "$LOG"; then
  echo "ERRORI O WARNING NEL LOG:"
  grep -E "SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error" "$LOG" | sort | uniq -c | head -20
  status=1
fi
rm -f "$LOG"
exit "$status"
