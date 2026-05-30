# Implementation Plan

## Roadmap

1. Phase 0: skeleton and docs
2. Phase 1: register-programmed DMA MVP with simplified internal memory interface
3. Phase 2: FIFO and backpressure
4. Phase 3: AXI4-Lite control interface
5. Phase 4: descriptor ring
6. Phase 5: completion queue
7. Phase 6: constrained AXI4 memory master
8. Phase 7: outstanding transaction tracking
9. Phase 8: CDC
10. Phase 9: ASIC constraints and synthesis
11. Phase 10: place and route and PPA study

## Current Scope

This commit only establishes Phase 0 scaffolding. The design is not expected to
move data yet, and many modules intentionally return placeholder values while
the implementation plan is refined.
