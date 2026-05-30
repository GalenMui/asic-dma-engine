# TODO

## Phase 0

- Review scaffolded module boundaries and naming.
- Decide default address width, data width, and register field encodings.
- Refine placeholder build, lint, and simulation flow for the preferred tools.

## Phase 1

- Implement a register-programmed DMA MVP with a simplified internal memory interface.
- Add basic control/status register behavior and a minimal datapath.
- Create a directed smoke test and extend the Python model accordingly.

## Phase 2

- Implement FIFO storage and backpressure behavior.
- Add FIFO safety assertions.

## Phase 3

- Implement real AXI4-Lite handshake and register access behavior.
- Add AXI4-Lite driver tasks and protocol assertions.

## Phase 4

- Implement descriptor ring fetch, decode, and scheduling.
- Define descriptor ownership and ring wrap behavior.

## Phase 5

- Implement completion queue formatting, writeback, and head/tail rules.
- Add completion and interrupt tests.

## Phase 6

- Implement constrained AXI4 master read/write burst generation.
- Add `RRESP`/`BRESP` error handling and `RLAST`/`WLAST` checks.

## Phase 7

- Implement outstanding transaction tracking and matching.
- Stress multiple in-flight transactions in randomized verification.

## Phase 8

- Add cfg/dma CDC paths and synchronize software-visible control/status events.
- Constrain and verify cross-domain behavior.

## Phase 9

- Refine SDC constraints and synthesis scripts.
- Start ASIC-oriented lint, timing, and area closure work.

## Phase 10

- Add place-and-route collateral and flow configuration.
- Perform PPA study and document tradeoffs.
