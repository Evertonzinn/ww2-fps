#!/usr/bin/env bash
# Regression gate for WW2 FPS remaster. Run from any working directory.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/Downloads/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "ERROR: Godot executable not found: $GODOT_BIN" >&2
  echo 'Run with GODOT_BIN=/absolute/path/to/godot bash tools/run_remaster_smokes.sh' >&2
  exit 2
fi
cd "$ROOT"
python3 tools/check_remaster_assets.py
"$GODOT_BIN" --headless --editor --path "$ROOT" --quit
tests=(
  tests/v0180_enemy_capsule_fallback_smoke.gd
  tests/v172_enemy_sweep_smoke.gd
  tests/v170_enemy_prone_smoke.gd
  tests/v160_weapon_hands_smoke.gd
  tests/v190_remaster_smoke.gd
  tests/v200_ballistics_smoke.gd
)
for test in "${tests[@]}"; do
  echo "=== SMOKE $test ==="
  "$GODOT_BIN" --headless --path "$ROOT" --script "res://$test"
done
echo "WW2 FPS remaster regression gate: PASS"
