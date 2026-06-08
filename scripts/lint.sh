#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RTL_FILES=(
  "$ROOT_DIR/rtl/dma_pkg.sv"
  "$ROOT_DIR/rtl/axi_lite_regs.sv"
  "$ROOT_DIR/rtl/dma_core.sv"
  "$ROOT_DIR/rtl/dma_top.sv"
)

if command -v verilator >/dev/null 2>&1; then
  verilator --lint-only --sv -Wall -Wno-fatal "${RTL_FILES[@]}"
elif command -v iverilog >/dev/null 2>&1; then
  iverilog -g2012 -I "$ROOT_DIR/rtl" -s dma_top -o /tmp/asic_dma_lint.out "${RTL_FILES[@]}"
else
  echo "[lint] No Verilator or Icarus Verilog found; install one to lint RTL."
  exit 1
fi
