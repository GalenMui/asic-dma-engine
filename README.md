# ASIC DMA Engine

`asic-dma-engine` is a small ASIC-oriented SystemVerilog DMA controller project.
The current implementation focuses on a clean Phase 1/2 MVP: an AXI4-Lite
control/status register block and a basic single-shot AXI4 memory-to-memory DMA
transfer engine.

The intent is portfolio-quality RTL for digital design roles: readable
synthesizable SystemVerilog, simple interfaces, focused verification, and clear
documentation about what is implemented versus planned.

## Current Status

Implemented now:

- 32-bit AXI4-Lite CSR interface
- Register map for source address, destination address, transfer length,
  status, interrupt enable/status, and version
- `CTRL.start` write-one-pulse transfer launch
- Basic AXI4 master read/write datapath using single-beat aligned transfers
- `busy`, `done`, `error`, and IRQ status behavior
- Cocotb smoke tests for CSR access, successful transfer, and simple error
  handling

Intentionally not implemented yet:

- Descriptor rings or scatter-gather DMA
- Multiple outstanding AXI transactions
- AXI burst coalescing or 4KB boundary splitting
- Unaligned transfers or data width conversion
- Clock domain crossing
- OpenLane/OpenROAD ASIC flow
- UVM or vendor-specific IP

## Block Diagram

```text
                AXI4-Lite slave
                     |
                     v
           +-------------------+
           |  axi_lite_regs    |
           |  CSRs/status/IRQ  |
           +---------+---------+
                     |
      start/src/dst/len/status
                     |
                     v
           +-------------------+
           |     dma_core      |
           | single-shot FSM   |
           +----+---------+----+
                |         |
             AXI read  AXI write
                |         |
                +----+----+
                     v
              AXI4 memory map
```

## Repository Structure

```text
rtl/
  dma_pkg.sv          Shared constants and simple project types
  axi_lite_regs.sv    AXI4-Lite CSR block
  dma_core.sv         Single-shot AXI4 DMA controller
  dma_top.sv          Phase 1/2 top-level integration
tb/cocotb/
  Makefile
  test_axi_lite_regs.py
  test_dma_smoke.py
docs/
  register_map.md
  architecture.md
scripts/
  lint.sh
  test.sh
```

Older descriptor-oriented placeholder modules remain in `rtl/` for later
phases, but the current top-level build uses only the Phase 1/2 files listed
above.

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
