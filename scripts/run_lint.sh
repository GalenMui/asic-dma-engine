#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_DIR="$ROOT_DIR/sim"

if command -v verilator >/dev/null 2>&1; then
  echo "[lint] Running placeholder Verilator lint"
  (
    cd "$SIM_DIR"
    verilator --lint-only -Wall -Wno-fatal -F filelist.f
  )
else
  echo "[lint] No lint tool detected. Edit scripts/run_lint.sh for your flow."
fi
