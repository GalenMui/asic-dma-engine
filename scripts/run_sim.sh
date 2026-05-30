#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/sim/build"
SIM_DIR="$ROOT_DIR/sim"

mkdir -p "$BUILD_DIR"

if command -v iverilog >/dev/null 2>&1; then
  echo "[sim] Compiling placeholder testbench with Icarus Verilog"
  (
    cd "$SIM_DIR"
    iverilog -g2012 -f filelist.f -s tb_dma_top -o "$BUILD_DIR/tb_dma_top.out"
    vvp "$BUILD_DIR/tb_dma_top.out"
  )
else
  echo "[sim] No simulator detected. Edit scripts/run_sim.sh for your toolchain."
fi
