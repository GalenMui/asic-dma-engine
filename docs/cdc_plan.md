# CDC Plan

## Clock Domains

The integrated top level has two explicit clock domains:

- `cfg_clk` with `cfg_rst_n`: AXI4-Lite register access, CSR status latches,
  IRQ enable/status, and the top-level `irq` output.
- `dma_clk` with `dma_rst_n`: DMA FSM, descriptor fetch/status writeback,
  burst buffer, AXI4 master interface, and outstanding transaction tables.

The design does not rely on timing constraints to hide clock crossings. All
intentional crossings use small RTL synchronizer or handshake blocks.

## Config to DMA Crossings

`CTRL.start` is treated as the launch event for a coherent control snapshot.
When software writes start, `dma_top` captures these config-domain fields:

- source address
- destination address
- transfer length
- descriptor base address
- descriptor count
- descriptor mode enable

The snapshot is held in the config domain until `cdc_bus_handshake` accepts it.
The DMA side receives the bundle and a one-cycle `dma_start_pulse`.

`CTRL.soft_reset` and `STATUS.error` clear events cross from `cfg_clk` to
`dma_clk` through `cdc_pulse_sync`.

## DMA to Config Crossings

DMA status and observability fields cross from `dma_clk` to `cfg_clk` through a
bus handshake:

- busy
- descriptor active
- descriptor index
- error cause
- bytes remaining
- active source and destination addresses
- completed descriptor count
- completed byte count low word

The status bus is sampled as a coherent snapshot. It is intended for software
visibility, not cycle-accurate performance measurement.

DMA event pulses cross from `dma_clk` to `cfg_clk` through `cdc_pulse_sync`:

- transfer done
- single-shot done
- descriptor done
- descriptor list done
- error

The CSR block latches these synchronized events into `STATUS` and `IRQ_STATUS`.
`irq` is generated only in the config domain.

## Reset Behavior

`cfg_rst_n` resets the CSR block and config-domain CDC state. `dma_rst_n` resets
the DMA core, AXI master state, outstanding tables, and DMA-domain CDC state.

The two resets are independent at the top-level port boundary. Integration
should either assert both resets during full-chip reset or verify the intended
behavior for partial-domain reset sequences.

## Current Non-Crossings

There are no asynchronous FIFO pointers, descriptor ring pointers, completion
queue pointers, or memory data buffers crossing between clock domains in the
current integrated design. The AXI4 master interface remains entirely in
`dma_clk`; the AXI4-Lite slave interface remains entirely in `cfg_clk`.

## Verification Still Needed

- Directed tests for slow `cfg_clk` with fast `dma_clk`, and fast `cfg_clk`
  with slow `dma_clk`.
- Back-to-back start, soft-reset, error-clear, done, and error pulse crossings.
- Status snapshot tests during active transfers and around completion/error
  edges.
- Partial reset tests for each domain.
- CDC lint or formal CDC analysis before ASIC implementation work.

## Known Limitations

- Pulse synchronizers assume events are not generated faster than the
  destination domain can observe the toggle transitions.
- The status snapshot is coherent per handshake, but software can still observe
  an older snapshot while a newer DMA-domain value is in flight.
- No ASIC SDC constraints, false-path declarations, synchronizer attributes, or
  CDC waiver/signoff files are included in this phase.
