#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

rm -rf "$ROOT_DIR/sim/build" "$ROOT_DIR"/sim/*.log "$ROOT_DIR"/sim/*.vcd
rm -rf "$ROOT_DIR/tb/cocotb/sim_build" "$ROOT_DIR/tb/cocotb/results.xml" "$ROOT_DIR"/tb/cocotb/*.vcd
find "$ROOT_DIR/model" -name "__pycache__" -type d -prune -exec rm -rf {} +

echo "[clean] Removed generated simulation and Python artifacts"
