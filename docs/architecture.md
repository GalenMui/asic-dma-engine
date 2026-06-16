# Architecture

This document describes the active integrated RTL baseline. It is grounded in
the filelist used by `scripts/lint.sh`, `tb/cocotb/Makefile`, and
`sim/filelist.f`.

## Active Modules

- `dma_pkg`: shared constants, register offsets, descriptor sizes, error cause
  values, and small packed types.
- `axi_lite_regs`: AXI4-Lite CSR block in the `cfg_clk` domain.
- `cdc_toggle_sync`: two-flop toggle synchronizer with edge detection.
- `cdc_pulse_sync`: event-pulse crossing wrapper built on toggle sync.
- `cdc_bus_handshake`: coherent bus snapshot crossing for infrequent control
  and status updates.
- `outstanding_table`: small table used to validate AXI response IDs and
  retire accepted transactions.
- `dma_core`: DMA FSM, burst datapath, descriptor flow, 2D descriptor support,
  response checks, status, and event pulses in the `dma_clk` domain.
- `dma_top`: top-level integration between AXI4-Lite CSRs, CDC, DMA core,
  AXI4 master interface, and IRQ output.

Older modular RTL shells in `rtl/` are not part of the active implementation.

## Control Path Overview

Software programs CSRs over AXI4-Lite in `axi_lite_regs`. The key programming
fields are:

- `SRC_ADDR_LO/HI`
- `DST_ADDR_LO/HI`
- `LEN_BYTES`
- `DESC_BASE_LO/HI`
- `DESC_COUNT`
- `MODE.descriptor_mode_enable`
- `IRQ_ENABLE`

Writing one to `CTRL.start` creates a one-cycle `cfg_clk` pulse. `dma_top`
captures the current programmed fields into a control snapshot and transfers
that snapshot to `dma_clk` through `cdc_bus_handshake`. The destination side
recreates a one-cycle `dma_start_pulse` for `dma_core`.

Writing one to `CTRL.soft_reset` creates a separate pulse that crosses into
`dma_clk` through `cdc_pulse_sync` and clears the DMA core state. Clearing
`STATUS.error` or writing a nonzero value to `ERROR_CAUSE` creates an
error-clear pulse that crosses to the DMA core and clears the latched cause.

## Data Path Overview

The active datapath is intentionally conservative:

1. Prepare the next transfer chunk.
2. Issue one AXI read burst.
3. Store all returned read beats in an internal `burst_buffer_q`.
4. Issue one AXI write burst.
5. Send buffered beats with full write strobes.
6. Wait for the write response.
7. Advance addresses and remaining byte count or finish.

The core does not stream read data directly into writes and does not keep
multiple arbitrary bursts in flight. The response tracking tables are used for
validation and defensive bookkeeping around the currently issued stream.

## Register Block Behavior

`axi_lite_regs` implements a 32-bit AXI4-Lite slave register file.

Important behavior:

- Independent AW and W handshakes are accepted and buffered until both halves
  of a write are present.
- One write response is produced for each accepted write.
- One read response is produced for each accepted read.
- Writable data registers honor byte strobes.
- `CTRL` reads as zero; bits are write-one pulse fields.
- `STATUS.done` and `STATUS.error` are sticky W1C bits.
- `IRQ_STATUS` bits are sticky W1C bits.
- `IRQ_ENABLE` gates only the top-level `irq`; it does not prevent
  `IRQ_STATUS` from latching events.
- Unmapped reads and writes return `SLVERR`.
- Writes to read-only mapped registers are accepted and ignored.

The full register map is in `docs/register_map.md`.

## Descriptor Flow

Descriptor mode is selected by setting `MODE.descriptor_mode_enable`, writing
`DESC_BASE` and `DESC_COUNT`, then writing `CTRL.start`.

Linear descriptor flow:

1. Validate that `DESC_COUNT` is nonzero.
2. Validate that `DESC_BASE` is 32-byte aligned.
3. Fetch one 32-byte descriptor with an 8-beat 32-bit AXI read burst.
4. Decode source address, destination address, length, and control fields.
5. Validate descriptor valid bit, mode field, alignment, and length.
6. Run the normal burst copy datapath.
7. Write one 32-bit descriptor status word at descriptor offset `0x18`.
8. Continue until the configured count completes or `stop_after` is set.

2D descriptor flow:

1. Fetch the base 32-byte descriptor.
2. Detect `CONTROL[7:4] == 1`.
3. Fetch the 32-byte extension at descriptor offset `0x20`.
4. Validate `row_bytes`, `num_rows`, source stride, and destination stride.
5. Run each row through the same burst copy datapath.
6. Write one descriptor status word after the whole tile completes.

Descriptor mode currently assumes `DATA_WIDTH == 32`. Starting descriptor mode
with another data width reports `ERROR_CAUSE_DESC_BUS_UNSUPPORTED`.

## Descriptor Format

Linear descriptors are 32 bytes and must be 32-byte aligned.

| Offset | Field | Description |
| --- | --- | --- |
| `0x00` | `SRC_ADDR_LO` | Source address bits `[31:0]`. |
| `0x04` | `SRC_ADDR_HI` | Source address bits `[63:32]`. |
| `0x08` | `DST_ADDR_LO` | Destination address bits `[31:0]`. |
| `0x0c` | `DST_ADDR_HI` | Destination address bits `[63:32]`. |
| `0x10` | `LEN_BYTES` | Linear transfer length or 2D row byte count. |
| `0x14` | `CONTROL` | Valid, stop, and descriptor mode bits. |
| `0x18` | `STATUS` | Hardware-written descriptor status word. |
| `0x1c` | `RESERVED` | Reserved in this baseline. |

`CONTROL[0]` is the valid bit. `CONTROL[2]` is `stop_after`.
`CONTROL[7:4]` is the descriptor mode: `0` for linear and `1` for 2D.

A 2D descriptor adds this 32-byte extension:

| Offset | Field | Description |
| --- | --- | --- |
| `0x20` | `NUM_ROWS` | Number of rows. Must be nonzero. |
| `0x24` | `SRC_STRIDE_BYTES` | Source stride. Must be aligned and at least `row_bytes`. |
| `0x28` | `DST_STRIDE_BYTES` | Destination stride. Must be aligned and at least `row_bytes`. |
| `0x2c`-`0x3c` | `RESERVED` | Reserved in this baseline. |

Descriptor status bit `0` means done, bit `1` means error, and bits `[15:8]`
hold the low eight bits of `ERROR_CAUSE` when error is set.

## AXI4-Lite Control Interface

The AXI4-Lite interface lives entirely in `cfg_clk`. The implementation accepts
one buffered write address, one buffered write data beat, one write response,
and one read response at a time. It is suitable for simple CSR programming and
the current cocotb tests, but it is not presented as a fully stressed
commercial AXI-Lite subsystem.

## AXI4 Master Read/Write Behavior

The AXI4 master interface lives entirely in `dma_clk`.

Read behavior:

- `ARID` is always zero.
- `ARSIZE` matches the configured data width.
- `ARBURST` is INCR.
- `ARLEN` is `burst_beats - 1`.
- Descriptor fetches use 8 beats at the default 32-bit data width.
- `RRESP` and `RLAST` are checked.

Write behavior:

- `AWID` is always zero.
- `AWSIZE` matches the configured data width.
- `AWBURST` is INCR.
- `AWLEN` is `burst_beats - 1` for data writes.
- Descriptor status writes are one beat.
- Data writes use full write strobes.
- Descriptor status writes strobe only the low status word bytes.
- `BRESP` is checked.

## Boundary Handling

`dma_core` limits each data burst by:

- remaining transfer bytes,
- `MAX_BURST_BEATS`, and
- the source and destination distance to the next 4KB boundary.

This prevents generated bursts from crossing a 4KB boundary on either the
source read side or the destination write side. The design still requires
aligned addresses and aligned byte counts.

## Outstanding Transaction Behavior

Separate read and write `outstanding_table` instances record accepted address
transactions. The tables store the AXI ID, transaction type, descriptor index,
and expected beat count.

The active core drives a single AXI ID of zero and issues a read-buffer-write
stream, so it normally reaches at most one read entry and one write entry. The
tables are still useful for detecting unexpected response IDs or retire errors.
They should not be interpreted as support for arbitrary multi-outstanding AXI
traffic.

## Interrupt Behavior

`IRQ_STATUS` has four pending bits:

- single-shot done,
- error,
- descriptor done,
- descriptor list done.

Events latch pending bits even when masked. `IRQ_ENABLE` controls whether a
pending bit contributes to `irq = |(IRQ_STATUS & IRQ_ENABLE)`.

Clearing `STATUS.error` clears the DMA error cause, but it does not clear
`IRQ_STATUS.error_irq`. Software should clear both when handling an error.

## Reset Behavior

`cfg_rst_n` resets:

- CSR storage,
- AXI-Lite response state,
- sticky status and IRQ bits,
- config-domain CDC state.

`dma_rst_n` resets:

- DMA FSM state,
- burst buffer and beat counters,
- descriptor progress,
- outstanding tables,
- status/observability values,
- DMA-domain CDC state.

`CTRL.soft_reset` resets the DMA core control state and clears `ERROR_CAUSE`.
It does not rewrite the programmed CSR fields or interrupt enables.

The top-level resets are separate. Full-chip integration should either assert
both together or deliberately verify partial-domain reset behavior.

## Backpressure Behavior

AXI-Lite:

- The register block can buffer independent AW and W halves.
- It accepts a new write address/data only when not holding an unresolved
  response for that channel.
- It accepts a new read only when no read response is pending.

AXI4 master:

- Address valid signals are gated by the matching outstanding table being
  ready.
- The read-data state waits on `RVALID`.
- The write-data state waits on `WREADY` for each beat.
- The write-response state waits on `BVALID`.
- Stalls preserve the current state and beat counters.

## Important FSMs

`dma_core` has one main FSM:

- `ST_IDLE`: waits for a valid start.
- `ST_XFER_PREP`: computes burst length and initializes beat counters.
- `ST_XFER_AR`: issues a read address.
- `ST_XFER_R`: captures read data and checks response/last behavior.
- `ST_XFER_AW`: issues a write address.
- `ST_XFER_W`: sends buffered write data.
- `ST_XFER_B`: checks write response and advances or completes.
- `ST_DESC_FETCH_AR`: issues descriptor base fetch.
- `ST_DESC_FETCH_R`: captures descriptor words.
- `ST_DESC_CHECK`: validates base descriptor fields.
- `ST_DESC_EXT_AR`: issues 2D extension fetch.
- `ST_DESC_EXT_R`: captures extension words.
- `ST_TILE_CHECK`: validates 2D fields and initializes row state.
- `ST_DESC_STATUS_AW`: issues descriptor status write address.
- `ST_DESC_STATUS_W`: sends descriptor status word.
- `ST_DESC_STATUS_B`: checks descriptor status write response and advances,
  completes, or errors.

## Key Signals

- `start_i`: one-cycle DMA-domain operation launch pulse.
- `soft_reset_i`: one-cycle DMA-domain reset pulse from software.
- `error_clear_i`: one-cycle DMA-domain error-cause clear pulse.
- `desc_mode_i`: selects descriptor flow instead of direct CSR transfer.
- `busy_o`: high whenever the DMA FSM is not idle.
- `done_pulse_o`: generic successful-operation pulse.
- `single_done_pulse_o`: successful single-shot pulse.
- `desc_done_pulse_o`: successful descriptor status writeback pulse.
- `desc_list_done_pulse_o`: successful end-of-descriptor-list pulse.
- `error_pulse_o`: failing-operation pulse.
- `desc_active_o`: descriptor mode is active and the core is not idle.
- `error_cause_o`: current latched error cause.
- `bytes_remaining_o`: current transfer or row bytes remaining.
- `completed_desc_count_o`: descriptors completed in the current run.
- `completed_byte_count_lo_o`: low 32 bits of completed bytes in the current
  run.

## Limitations

Implemented:

- AXI4-Lite CSR access.
- Aligned single-shot memory-to-memory copies.
- AXI INCR bursts with final short bursts.
- 4KB burst boundary splitting.
- Linear descriptor-count mode.
- 2D strided descriptor mode.
- Descriptor status writeback.
- Basic IRQ status and enable behavior.
- Bounded response tracking.
- Explicit top-level CDC.

Not implemented:

- Descriptor rings or linked-list scatter-gather.
- Arbitrary multi-outstanding AXI issuing.
- Out-of-order response support.
- Completion queues.
- Interrupt coalescing or multiple interrupt lines.
- Unaligned transfers, narrow transfers, or data-width conversion.
- Formal or tool-based CDC signoff.
- ASIC implementation flow.

This design is not production-ready and is not claimed to be fully AXI
feature-complete.
