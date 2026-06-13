# Architecture

## Overview

The current design is a compact register-programmed DMA engine with optional
linear and 2D strided descriptor processing. Software can either program one
source, destination, and byte length directly, configure a descriptor base/count
for linear descriptors, or use a 64-byte tiled descriptor for row-strided 2D
movement.

The integrated top-level build uses:

- `axi_lite_regs` for AXI4-Lite CSRs, status, and IRQ latches in the
  `cfg_clk` domain.
- Explicit CDC pulse and bus bridges between the configuration and DMA domains.
- `dma_core` for AXI4 memory-side reads and writes in the `dma_clk` domain.
- `outstanding_table` instances for bounded read and write transaction
  tracking.
- `dma_top` to connect the CSR block, CDC bridges, and DMA core.

The memory datapath is intentionally conservative: one AXI read burst is issued,
the returned data is stored in a small internal burst buffer, and then one AXI
write burst is issued. The outstanding tables track issued transactions and
validate responses, but the datapath still does not issue arbitrary multiple
outstanding bursts.

## CSR Block

`axi_lite_regs` terminates a 32-bit AXI4-Lite slave interface and owns the
software-visible registers.

Behavior:

- Accepts independent AXI-Lite address and data handshakes for writes.
- Supports single outstanding read and write responses.
- Applies byte strobes to writable data registers.
- Treats `CTRL.start` and `CTRL.soft_reset` as write-one pulse fields.
- Latches `STATUS.done` and `STATUS.error` from DMA core event pulses.
- Implements write-one-to-clear behavior for `STATUS` and `IRQ_STATUS`.
- Exposes descriptor configuration registers and DMA debug/error readback.
- Raises `irq` when any enabled IRQ status bit is pending.

Unmapped AXI-Lite accesses return `SLVERR`. Writes to read-only registers are
accepted and ignored.

## Clock Domains and CDC

`dma_top` exposes two independent active-low reset clock domains:

- `cfg_clk`/`cfg_rst_n`: AXI4-Lite CSRs, IRQ enable/status latches, and the
  top-level `irq` output.
- `dma_clk`/`dma_rst_n`: DMA control FSM, AXI4 master interface, descriptor
  processing, burst buffer, and outstanding transaction tables.

Crossings are explicit in RTL:

- `CTRL.start` captures the programmed source, destination, length, descriptor
  base/count, and mode into a config-domain snapshot. A bus handshake transfers
  that snapshot into `dma_clk` and recreates a one-cycle DMA-domain start pulse.
- `CTRL.soft_reset` and `STATUS.error` clear pulses cross from `cfg_clk` to
  `dma_clk` through pulse synchronizers.
- DMA status and observability fields cross from `dma_clk` to `cfg_clk` through
  a bus handshake that continuously publishes coherent snapshots.
- DMA completion and error event pulses cross from `dma_clk` to `cfg_clk`
  through pulse synchronizers before they update CSR status and IRQ latches.

There are no asynchronous FIFOs or pointer crossings in the current integrated
datapath. CDC correctness is based on these small synchronizer and handshake
blocks, not on timing constraints alone.

## Burst Transfer Flow

Single-shot mode uses `SRC_ADDR`, `DST_ADDR`, and `LEN_BYTES`. Descriptor mode
uses the same transfer engine after a descriptor has been fetched and decoded.

For each transfer:

1. Validate nonzero length, data-width-aligned addresses, and data-width-aligned
   byte count.
2. Choose the next burst length from the remaining byte count, the configured
   `MAX_BURST_BEATS`, and the source/destination 4KB boundary limits.
3. Issue an AXI read burst with `ARLEN = beats - 1`, `ARSIZE` matching the data
   width, and `ARBURST = INCR`.
4. Capture all returned read beats into the internal burst buffer.
5. Issue an AXI write burst with matching `AWLEN`, `AWSIZE`, and `AWBURST`.
6. Write the buffered beats with full write strobes.
7. Check `RRESP`, `RLAST`, and `BRESP`; stop with error on a failed response or
   unexpected read burst length.
8. Advance source/destination pointers and repeat until the transfer completes.

The default maximum burst length is 16 beats. The implementation supports final
short bursts as long as the transfer length remains aligned to the data width.

## 4KB Boundary Handling

The core does not allow a burst to cross a 4KB address boundary. Burst length is
limited by both the source address and destination address boundary distance, so
a transfer can be split earlier than `MAX_BURST_BEATS` when either side is near
a 4KB page boundary.

This is still a simple aligned-transfer implementation. It does not support
unaligned accesses, narrow transfers, or data width conversion.

## Outstanding Tracking

The DMA core instantiates separate bounded tables for read-channel and
write-channel tracking. Each table records the AXI ID, transaction type,
descriptor index, and expected beat count when an address handshake completes.
Read entries are looked up on accepted `R` beats and retired on the final read
beat. Write entries are looked up and retired on accepted `B` responses.

The default table depth is four entries. The integrated core currently drives a
single AXI ID value of zero and uses an in-order read-buffer-write datapath, so
the active design reaches at most one read entry and one write entry at a time.
The table depth is therefore a defensive bound and response-validation
structure, not a license for arbitrary parallel AXI issuing. Address valid
signals are gated by table availability, and an unexpected response ID or failed
retire reports `ERROR_CAUSE_OUTSTANDING_TABLE`.

## Descriptor Mode

Descriptor mode is enabled by setting `MODE.descriptor_mode_enable`, programming
`DESC_BASE` and `DESC_COUNT`, then writing `CTRL.start`.

Linear descriptor processing:

1. Validate `DESC_COUNT` is nonzero and `DESC_BASE` is 32-byte aligned.
2. Fetch one 32-byte descriptor with an 8-beat 32-bit AXI read burst.
3. Check the descriptor valid bit and transfer fields.
4. Run the transfer using the same burst copy engine as single-shot mode.
5. Write one 32-bit descriptor status word at descriptor offset `0x18`.
6. Advance to the next descriptor until `DESC_COUNT` descriptors complete, a
   descriptor has `stop_after` set, or an error occurs.

Descriptor mode currently assumes the integrated 32-bit DMA data width. If the
core is parameterized to another data width and descriptor mode is started, the
core reports `ERROR_CAUSE_DESC_BUS_UNSUPPORTED`.

## 2D Strided Descriptor Mode

Phase 8.5 adds a layout-aware tiled mode for accelerator-style row-strided
copies. A 2D descriptor describes a whole tile:

```text
for row in 0..num_rows-1:
  copy row_bytes from src_base + row * src_stride_bytes
                 to dst_base + row * dst_stride_bytes
```

The core preserves the existing burst datapath. It fetches the base 32-byte
descriptor, detects `CONTROL[7:4] == 1`, fetches an additional 32-byte extension
at `descriptor + 0x20`, validates the tile fields, then runs each row through
the same burst transfer flow used by linear descriptors.

Row address generation is registered. The core latches row 0 source/destination
addresses, row byte count, row count, and strides. After each row completes and
the row's write response has returned successfully, the core increments running
row-base address registers by the source and destination strides. The next row
starts from those registered row-base addresses.

Descriptor retirement remains ordered. The core writes one descriptor status
word for the entire 2D descriptor after all rows complete, not one status word
per row. If any row sees an AXI read/write error or if descriptor validation
fails, processing stops on the first error and the existing descriptor error
status path is used.

## Descriptor Format

Linear descriptors are 32 bytes and must be 32-byte aligned.

| Offset | Field | Description |
| --- | --- | --- |
| `0x00` | `SRC_ADDR_LO` | Source address bits `[31:0]`. |
| `0x04` | `SRC_ADDR_HI` | Source address bits `[63:32]`. |
| `0x08` | `DST_ADDR_LO` | Destination address bits `[31:0]`. |
| `0x0c` | `DST_ADDR_HI` | Destination address bits `[63:32]`. |
| `0x10` | `LEN_BYTES` | Transfer length in bytes. Must be nonzero and data-width aligned. |
| `0x14` | `CONTROL` | Descriptor control bits. |
| `0x18` | `STATUS` | Descriptor status written by hardware. |
| `0x1c` | `NEXT_OR_RESERVED` | Reserved in this phase. |

### Descriptor `CONTROL`

| Bit | Name | Description |
| --- | --- | --- |
| `0` | `valid` | Must be set for the descriptor to run. |
| `1` | `irq_on_done` | Accepted as part of the descriptor format but ignored in this phase; descriptor interrupts are controlled globally by `IRQ_ENABLE`. |
| `2` | `stop_after` | Stop descriptor processing after this descriptor completes successfully. |
| `7:4` | `descriptor_mode` | `0`: linear descriptor. `1`: 2D strided descriptor with a 32-byte extension. |
| `31:8` | `reserved` | Ignored. |

### 2D Descriptor Extension

A 2D descriptor uses the same first 32 bytes as the linear descriptor. The
linear `LEN_BYTES` field becomes `row_bytes`, and `CONTROL[7:4]` must be `1`.
The descriptor status word is still written at offset `0x18`. The 2D extension
starts at offset `0x20`, making the total descriptor footprint 64 bytes.

| Offset | Field | Description |
| --- | --- | --- |
| `0x20` | `NUM_ROWS` | Number of rows to copy. Must be nonzero. |
| `0x24` | `SRC_STRIDE_BYTES` | Byte distance between source rows. Must be data-width aligned and at least `row_bytes`. |
| `0x28` | `DST_STRIDE_BYTES` | Byte distance between destination rows. Must be data-width aligned and at least `row_bytes`. |
| `0x2c` | `TILE_FLAGS_OR_RESERVED` | Reserved in this phase. |
| `0x30`-`0x3c` | `RESERVED` | Reserved in this phase. |

### Descriptor `STATUS`

| Bit | Name | Description |
| --- | --- | --- |
| `0` | `done` | Set when the descriptor transfer completes successfully. |
| `1` | `error` | Set when descriptor validation or transfer execution fails. |
| `2` | `in_progress` | Not implemented in this phase. |
| `15:8` | `error_code` | Low 8 bits of `ERROR_CAUSE` when `error` is set. |
| `31:16` | `reserved` | Written as zero. |

## Error Handling

The core stops on the first error. In single-shot mode it pulses global error
status immediately. In descriptor mode it writes descriptor error status when a
descriptor has been fetched and status writeback is possible, then pulses global
error status.

`ERROR_CAUSE` records the reason for the most recent error. It is cleared by
clearing `STATUS.error`, writing a nonzero value to `ERROR_CAUSE`, issuing
`CTRL.soft_reset`, or starting a new valid operation.

Descriptor status writeback errors are reported as
`ERROR_CAUSE_DESC_WRITEBACK`. If descriptor status writeback itself fails, the
descriptor status word in memory may not reflect the error, but global
`STATUS.error`, `IRQ_STATUS.error_irq`, and `ERROR_CAUSE` are still updated.

## Interrupts

The CSR block tracks four interrupt status bits:

- single-shot done
- error
- descriptor done
- descriptor list done

`IRQ_STATUS` latches events regardless of the enable mask. `IRQ_ENABLE` only
controls whether a pending bit contributes to the top-level `irq` output:
`irq = |(IRQ_STATUS & IRQ_ENABLE)`. Software clears each pending bit by writing
one to the corresponding `IRQ_STATUS` bit. Clearing `STATUS.error` clears
`ERROR_CAUSE`, but it does not clear `IRQ_STATUS.error_irq`; software should
clear both when it has handled an error interrupt.

Descriptor mode pulses `descriptor_done_irq` after each successful descriptor
status writeback and pulses `descriptor_list_done_irq` when processing stops
successfully because `DESC_COUNT` descriptors completed or `stop_after` was set.
For a one-descriptor list, both descriptor interrupt bits are latched.

## Observability

The design exposes a small set of read-only progress registers:

- `DESC_INDEX`: current descriptor index, retaining the last processed index.
- `BYTES_REMAINING`: byte count remaining in the active transfer.
- `ACTIVE_SRC_LO`: active source address low 32 bits.
- `ACTIVE_DST_LO`: active destination address low 32 bits.
- `COMPLETED_DESC_COUNT`: descriptors completed in the current descriptor run.
- `COMPLETED_BYTE_COUNT_LO`: low 32 bits of bytes completed in the current run.

These registers are intended for basic software visibility and tests. They are
not a performance counter subsystem and reset at the start of each operation.

## Reset Behavior

`cfg_rst_n` clears the CSR register file, status latches, IRQ enable and
pending bits, and config-domain CDC state. `dma_rst_n` clears the DMA FSM,
outstanding tables, descriptor progress, AXI master state, and DMA-domain
observability counters. `CTRL.soft_reset` crosses into the DMA domain, resets
the DMA core state, and clears `ERROR_CAUSE`; it does not rewrite the
programmed CSR source, destination, length, descriptor, mode, or interrupt
enable registers.

## Limitations

Implemented:

- AXI4-Lite CSR access.
- Single-shot memory-to-memory copies.
- AXI INCR burst transfers with final short bursts.
- 4KB burst boundary splitting.
- Linear descriptor-count mode.
- 2D strided/tiled descriptor mode with 64-byte descriptors.
- Descriptor status writeback.
- Bounded outstanding transaction tables for read and write response tracking.
- Separate config and DMA clock domains with explicit control/status/event CDC.
- Four software-visible IRQ status bits with write-one-to-clear behavior.
- Basic progress observability registers.

Not implemented:

- Arbitrary multi-outstanding AXI reads or writes.
- Out-of-order response support.
- Linked-list scatter-gather descriptors.
- Circular descriptor rings.
- Completion queues.
- Interrupt coalescing or multiple interrupt lines.
- Transpose, compression, sparse gather/scatter, cache coherence, QoS, or
  AXI4-Stream operation.
- Negative strides or overlapping-row support.
- Unaligned transfers.
- Narrow transfers or data width conversion.
- Formal or tool-based CDC signoff.
- ASIC implementation flow.

The design is not claimed to be production-ready or fully AXI feature-complete.
