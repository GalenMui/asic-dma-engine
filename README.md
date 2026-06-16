# ASIC DMA Engine

`asic-dma-engine` is a small SystemVerilog DMA controller project intended for
ASIC-oriented RTL study. The current baseline is an AXI4-Lite controlled,
memory-mapped AXI4 DMA engine that can copy aligned memory ranges directly or
through a small descriptor flow.

The project is meant to be readable and reviewable: the RTL is compact, the
active integration path is documented, and the remaining verification and ASIC
work is called out explicitly.

## What It Does

The DMA engine moves data from a source address to a destination address without
software copying each word. Software programs control/status registers over
AXI4-Lite, starts the operation, and observes completion, error, and interrupt
status. The memory side uses AXI4 read and write channels.

This is a study-quality baseline, not a production DMA IP block.

## Current Feature Set

Implemented in the active top-level build:

- 32-bit AXI4-Lite CSR interface.
- Source address, destination address, transfer length, descriptor, mode,
  interrupt, status, error, and progress registers.
- `CTRL.start` and `CTRL.soft_reset` write-one pulse behavior.
- Aligned AXI4 memory-to-memory copies.
- AXI INCR burst generation with a default maximum of 16 beats.
- Burst splitting at 4KB boundaries.
- Final short bursts for aligned transfer lengths.
- Linear descriptor-count mode using 32-byte descriptors.
- 2D strided descriptor mode using a 64-byte descriptor format.
- Descriptor status writeback.
- Basic done, error, descriptor done, and descriptor-list-done IRQ status bits.
- Bounded read/write response-tracking tables.
- Separate `cfg_clk` and `dma_clk` domains with explicit CDC bridges.
- Cocotb tests for CSR behavior and DMA smoke/regression scenarios.

Not implemented:

- Descriptor rings, linked lists, ownership bits, or ring wrap.
- Arbitrary multi-outstanding AXI issue.
- Out-of-order response handling.
- Unaligned transfers, narrow transfers, or data-width conversion.
- Completion queues.
- Interrupt coalescing.
- UVM, formal proofs, or full AXI compliance checking.
- OpenLane/OpenROAD ASIC implementation flow.

## Architecture Summary

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
          explicit pulse and bus CDC
                     |
                     v
           +-------------------+
           |     dma_core      |
           | burst copy engine |
           | descriptor flow   |
           | response tracking |
           +----+---------+----+
                |         |
             AXI read  AXI write
                |         |
                +----+----+
                     v
              AXI4 memory map
                   dma_clk
```

The active design is integrated primarily in `axi_lite_regs`, `dma_top`, and
`dma_core`. Older modular RTL shells remain in `rtl/` but are not part of the
active filelist.

## Repository Layout

```text
rtl/              Active RTL plus older inactive scaffold modules
tb/cocotb/        Active cocotb tests and cocotb Makefile
tb/               Older SystemVerilog testbench scaffolding
docs/             Architecture, register map, audit, and handoff docs
scripts/          Lint, test, and clean wrappers
sim/              Simple make entry point and active filelist
model/            Python model scaffolding, not active checking
asic/             Placeholder ASIC-flow notes and seed config
constraints/      Early SDC assumptions, not signoff constraints
```

## Running Checks

From a clean checkout:

```sh
make lint
make test
make clean
```

Equivalent script entry points:

```sh
./scripts/lint.sh
./scripts/test.sh
./scripts/clean.sh
```

`make sim` is an alias for `make test`, and `make check` runs lint then tests.

## Required Tools

- `make`
- Icarus Verilog (`iverilog`) or Verilator for lint/compile checking
- Python 3
- `cocotb` and a supported simulator, normally Icarus, for the cocotb tests

The lint script prefers Verilator when available and falls back to Icarus.

## Tested So Far

The checked-in cocotb suite contains:

- CSR read/write tests.
- Read-only `VERSION` behavior.
- Write-one-to-clear `STATUS` and `IRQ_STATUS` behavior.
- Start and soft-reset pulse checks.
- Single-shot DMA copy smoke tests.
- Multi-burst, final-short-burst, and 4KB-boundary tests.
- Linear descriptor tests.
- One 2D descriptor smoke test.
- Invalid-programming and invalid-descriptor error tests.
- AXI read/write response error tests.
- Deterministic backpressure tests.
- Reset tests.
- Small fixed-seed randomized tests.

The current local lock-down run could not execute cocotb because
`cocotb-config` was not installed in this environment. `make lint` completed
with Icarus Verilog; details are in `docs/repo_audit.md`.

## Next Phase

The next useful phase is owner-led verification and review:

1. Install the cocotb toolchain and run `make test`.
2. Review `docs/register_map.md` against `rtl/axi_lite_regs.sv`.
3. Review `docs/architecture.md` against `rtl/dma_top.sv` and
   `rtl/dma_core.sv`.
4. Add missing directed tests listed in `docs/verification_plan.md`.
5. Review CDC and reset behavior before starting ASIC-flow setup.
