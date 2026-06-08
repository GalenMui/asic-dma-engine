#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COCOTB_DIR="$ROOT_DIR/tb/cocotb"

if ! command -v cocotb-config >/dev/null 2>&1; then
  echo "[test] cocotb is not installed or cocotb-config is not on PATH."
  exit 1
fi

make -C "$COCOTB_DIR" TOPLEVEL=axi_lite_regs MODULE=test_axi_lite_regs
make -C "$COCOTB_DIR" clean
make -C "$COCOTB_DIR" TOPLEVEL=dma_top MODULE=test_dma_smoke
