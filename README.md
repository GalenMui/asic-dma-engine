# ASIC DMA Engine

`asic-dma-engine` is a small ASIC-oriented SystemVerilog DMA controller project.
The current implementation includes an AXI4-Lite control/status register block,
a conservative AXI4 burst memory-to-memory DMA engine, and a simple linear
descriptor-count mode. The current phase adds bounded outstanding transaction
tracking and a dual-clock top-level split with explicit CDC between the
configuration and DMA datapath domains. Phase 8.5 adds a focused 2D
strided/tiled descriptor mode for accelerator-style row-based movement.

The intent is portfolio-quality RTL for digital design roles: readable
synthesizable SystemVerilog, simple interfaces, focused verification, and clear
documentation about what is implemented versus planned.

## Current Status

Implemented now:

- 32-bit AXI4-Lite CSR interface
- Register map for source address, destination address, transfer length,
  descriptor setup, status, interrupt enable/status, error cause, and version
- `CTRL.start` write-one-pulse transfer launch
- AXI4 master read/write datapath using aligned INCR bursts
- Burst splitting at `MAX_BURST_BEATS` and 4KB address boundaries
- Final short bursts for aligned transfer lengths
- Linear descriptor-count mode with descriptor fetch and status writeback
- 2D strided/tiled descriptors using a 64-byte extended descriptor format
- Bounded read/write outstanding transaction tables in the DMA clock domain
- `busy`, `done`, `error`, descriptor-active, IRQ status, and error-cause
  behavior
- Single-shot done, error, descriptor done, and descriptor list done interrupt
  pending bits
- Basic observability registers for bytes remaining, active addresses,
  completed descriptors, and completed byte count
- Separate `cfg_clk`/`cfg_rst_n` and `dma_clk`/`dma_rst_n` top-level domains
- Explicit pulse and bus CDC structures for control, status, and DMA events
- Cocotb tests for CSR access, burst transfers, descriptor transfers, and
  interrupt/error/reset/backpressure/randomized behavior, with DMA smoke tests
  updated for the split clocks

Intentionally not implemented yet:

- Descriptor rings or linked-list scatter-gather DMA
- Arbitrary multi-outstanding AXI issue or out-of-order response handling
- Transpose, compression, sparse gather/scatter, cache coherence, QoS, or
  AXI4-Stream
- Unaligned transfers or data width conversion
- Deep CDC stress, formal CDC checks, or ASIC timing constraints
- Interrupt coalescing or multiple interrupt lines
- OpenLane/OpenROAD ASIC flow
- UVM or vendor-specific IP

## Block Diagram

```text
                AXI4-Lite slave
                   cfg_clk
                     |
                     v
           +-------------------+
           |  axi_lite_regs    |
           |  CSRs/status/IRQ  |
           +---------+---------+
                     |
          explicit CDC pulse/bus bridges
                     |
                     v
           +-------------------+
           |     dma_core      |
           | burst + descriptor|
           | outstanding tables|
           +----+---------+----+
                |         |
             AXI read  AXI write
                |         |
                +----+----+
                     v
              AXI4 memory map
                   dma_clk
```

## Repository Structure

```text
rtl/
  dma_pkg.sv          Shared constants and simple project types
  axi_lite_regs.sv    AXI4-Lite CSR block
  dma_core.sv         Burst AXI4 DMA controller with descriptor mode
  dma_top.sv          Dual-clock top-level integration
  outstanding_table.sv
  cdc_toggle_sync.sv
  cdc_pulse_sync.sv
  cdc_bus_handshake.sv
tb/cocotb/
  Makefile
  test_axi_lite_regs.py
  test_dma_smoke.py
docs/
  register_map.md
  architecture.md
  cdc_plan.md
  tiled_dma_extension.md
scripts/
  lint.sh
  test.sh
```

Older descriptor-oriented placeholder modules remain in `rtl/`, but the current
top-level build uses the active integration files listed above.

## Running Checks

Run RTL lint:

```sh
./scripts/lint.sh
```

Run cocotb tests:

```sh
./scripts/test.sh
```

The test script expects `cocotb`, `make`, and a supported simulator such as
Icarus Verilog to be installed. The lint script uses Verilator when available
and falls back to Icarus Verilog for compile checking.
