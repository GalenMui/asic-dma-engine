# Architecture

## Overview

The current design is a compact register-programmed DMA engine. Software writes
source address, destination address, and length through AXI4-Lite, then writes
`CTRL.start`. The DMA core copies aligned words from the source AXI address
range to the destination AXI address range and reports completion or error
through status registers.

## Phase 1: CSR Block

`axi_lite_regs` terminates a 32-bit AXI4-Lite slave interface and owns the
software-visible registers.

Behavior:

- Accepts independent AXI-Lite address and data handshakes for writes.
- Supports single outstanding read and write responses.
- Applies byte strobes to writable data registers.
- Treats `CTRL.start` and `CTRL.soft_reset` as write-one pulse fields.
- Latches `STATUS.done` and `STATUS.error` from DMA core event pulses.
- Implements write-one-to-clear behavior for `STATUS` and `IRQ_STATUS`.
- Raises `irq` when any IRQ status bit is set.

Unmapped AXI-Lite accesses return `SLVERR`. Writes to the `VERSION` register
are ignored.

## Phase 2: DMA Core

`dma_core` is a single-shot memory-to-memory controller. The implementation is
intentionally simple:

1. Validate `LEN_BYTES`, source address, and destination address on
   `CTRL.start`.
2. Issue one single-beat AXI4 read transaction.
3. Capture the returned read data.
4. Issue one single-beat AXI4 write transaction.
5. Repeat until the programmed byte count is transferred.
6. Pulse `done` on success or `error` on invalid programming or AXI response
   error.

The core uses fixed `AWLEN/ARLEN = 0` single-beat transfers, `INCR` burst type,
and full write strobes for every beat. It does not issue a write until the
corresponding read data has returned.

## Top-Level Integration

`dma_top` instantiates:

- `axi_lite_regs`
- `dma_core`

The Phase 1/2 top uses one clock and active-low reset for both control and DMA
logic. Clock domain crossing is deliberately deferred.

## Limitations

The current implementation supports only aligned word transfers. `LEN_BYTES`
must be nonzero and a multiple of the AXI data bus byte width. Source and
destination addresses must be aligned to the same width.

Not yet implemented:

- Descriptor rings
- Scatter-gather operation
- Multiple outstanding reads or writes
- AXI burst optimization
- 4KB boundary splitting
- Unaligned accesses
- Data width conversion
- Separate config and DMA clock domains
- Completion queues
- ASIC implementation flow

These are future phases and should not be assumed by software or tests.
