# Verification Plan

## Directed Testing

- Reset and register accessibility smoke tests.
- Phase 1 transfer sanity checks with a simplified memory interface.
- Descriptor ring pointer movement tests once ring support exists.
- Completion queue and interrupt sequencing tests in later phases.

## Randomized Testing

- Random descriptor streams with bounded lengths and aligned addresses.
- Randomized AXI backpressure on AR, R, AW, W, and B channels.
- Error-injection scenarios for `RRESP` and `BRESP`.
- Outstanding-transaction stress once multiple in-flight commands exist.

## Checkers

- Scoreboard comparison against a Python reference model.
- Assertions for AXI handshakes, FIFO safety, and completion ordering.
- Coverage for descriptor types, burst lengths, and error conditions.
