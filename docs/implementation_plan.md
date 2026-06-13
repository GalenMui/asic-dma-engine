# Implementation Plan

## Roadmap

1. Phase 0: skeleton and docs
2. Phase 1: AXI4-Lite CSR block
3. Phase 2: basic single-shot AXI4 memory-to-memory DMA
4. Phase 3: conservative AXI4 burst transfers
5. Phase 4: linear descriptor-count mode
6. Phase 5: stronger interrupt, error, and observability behavior
7. Phase 6: stronger cocotb coverage with backpressure, reset, errors, and randomized tests
8. Phase 7: bounded outstanding transaction tracking
9. Phase 8: dual-clock split and explicit CDC
10. Phase 8.5: 2D strided/tiled descriptor extension
11. Phase 9: ASIC constraints and synthesis
12. Phase 10: place and route and PPA study

## Current Scope

The integrated top-level build currently covers Phases 1 through 8.5 at a
conservative level: AXI4-Lite CSRs, aligned single-shot DMA, AXI INCR burst
splitting, linear descriptor-count processing, explicit IRQ/error status, basic
observability registers, expanded cocotb tests, bounded outstanding transaction
tables, a dual-clock top-level split with explicit CDC bridges, and a focused
2D strided descriptor mode.

Phase 7 is intentionally conservative: the tables track and validate read/write
responses, but the datapath still issues one burst stream at a time with a
single AXI ID. Phase 8 introduces `cfg_clk`/`cfg_rst_n` and
`dma_clk`/`dma_rst_n` plus explicit control, status, and event crossings. It
does not include ASIC timing constraints or CDC signoff reports.

Phase 8.5 adds 64-byte 2D descriptors that reuse the existing burst datapath
row-by-row and write one descriptor status word after the full tile completes.
It does not add transpose, compression, sparse gather/scatter, AXI4-Stream, or
new completion queues.

The design still does not implement descriptor rings, linked-list
scatter-gather, arbitrary multi-outstanding AXI issue, out-of-order response
handling, completion queues, or ASIC flow.
