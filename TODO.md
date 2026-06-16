# Backlog

Use this file as the central project backlog. Inline TODO markers were removed
from inactive scaffolds during the lock-down pass so future work is tracked in
one place.

## Immediate Owner Verification

- Install the cocotb toolchain and run `make test`.
- Review `docs/register_map.md` against `rtl/axi_lite_regs.sv`.
- Review `docs/architecture.md` against `rtl/dma_top.sv` and
  `rtl/dma_core.sv`.
- Add directed tests for unsupported descriptor modes and all 2D validation
  error causes.
- Add tests for unexpected AXI response IDs and outstanding-table retire
  errors.
- Add reset tests for each major DMA FSM state.
- Add CDC tests with varied `cfg_clk` and `dma_clk` ratios.

## RTL Review Before New Features

- Decide whether inactive modular RTL shells should be deleted, revived, or
  archived after manual review.
- Review AXI-Lite AW/W buffering and response backpressure behavior under more
  timing combinations.
- Review descriptor status writeback behavior on injected writeback failures.
- Review partial-domain reset behavior.
- Review whether current observability registers are sufficient for debugging.

## Verification Infrastructure

- Decide whether to keep verification primarily in cocotb or revive the
  SystemVerilog testbench scaffolding.
- Build a real Python reference model only if it will be used by tests.
- Add assertions for AXI handshakes, burst lengths, no 4KB crossing, WLAST, and
  outstanding-table consistency.
- Add functional coverage for register access, burst sizes, descriptor types,
  error causes, IRQ states, and reset states.

## ASIC Preparation

- Treat `constraints/dma.sdc` as a starting assumption file, not signoff.
- Add synchronizer attributes or CDC waiver strategy only after CDC review.
- Define realistic clocks, IO delays, reset assumptions, and false paths.
- Create OpenLane/OpenROAD flow collateral only after RTL and verification
  confidence improves.

## Deliberately Out Of Scope For This Baseline

- Descriptor rings or linked-list scatter-gather.
- Completion queues.
- Arbitrary multi-outstanding AXI issue.
- Out-of-order response support.
- Unaligned transfers and data-width conversion.
- AXI4-Stream, cache coherence, QoS, compression, sparse gather/scatter, or
  transpose modes.
