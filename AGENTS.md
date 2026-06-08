# AGENTS.md

## Project Identity

This repository is `asic-dma-engine`, an ASIC-oriented SystemVerilog DMA
controller project.

The current implementation target is Phase 1 and Phase 2 only:

- AXI4-Lite register interface
- Register-programmed single-shot memory-to-memory DMA
- Basic busy, done, error, and IRQ status behavior
- Focused cocotb smoke tests

## Scope Guardrails

Keep the design small, readable, and synthesizable. Do not implement descriptor
rings, scatter-gather, multiple outstanding AXI transactions, optimized bursts,
4KB boundary splitting, unaligned transfers, CDC, UVM, vendor IP, or OpenLane
flow unless explicitly requested.

Future-looking placeholder files may remain in the repository, but current
documentation and tests should be clear about what is actually implemented.
