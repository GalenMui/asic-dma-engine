# Repository Audit

This audit captures the pre-verification, pre-ASIC-flow baseline. It is based
on the checked-in RTL, tests, scripts, docs, and local tool results from this
lock-down pass. It does not claim protocol completeness or ASIC readiness.

## Top-Level Directory Map

```text
.
├── asic/          Placeholder ASIC-flow notes and OpenLane seed file.
├── constraints/   Early SDC timing assumptions, not signoff constraints.
├── docs/          Architecture, register map, verification, and handoff docs.
├── model/         Python reference-model scaffolding, not active checking.
├── rtl/           SystemVerilog RTL and older inactive scaffold modules.
├── scripts/       Open-source-friendly lint, test, and clean wrappers.
├── sim/           Simple make entry point and active RTL filelist.
├── tb/            Cocotb tests plus older SystemVerilog testbench scaffolds.
├── AGENTS.md      Repo-specific working rules for future agent sessions.
├── Makefile       Root convenience targets for lint, test, sim, clean, check.
├── README.md      Recruiter-readable project overview and run instructions.
└── TODO.md        Centralized owner backlog for future manual work.
```

## Active RTL Filelist

The active build path is the filelist used by `scripts/lint.sh`,
`tb/cocotb/Makefile`, and `sim/filelist.f`:

- `rtl/dma_pkg.sv`: Shared parameters, register offsets, error cause values,
  descriptor constants, and packed project types.
- `rtl/axi_lite_regs.sv`: AXI4-Lite CSR block in `cfg_clk`. Handles register
  read/write behavior, W1C status, IRQ status, start/soft-reset pulses, and
  software-visible observability.
- `rtl/cdc_toggle_sync.sv`: Two-flop toggle synchronizer with edge detection.
- `rtl/cdc_pulse_sync.sv`: Pulse-to-toggle CDC wrapper for infrequent events.
- `rtl/cdc_bus_handshake.sv`: Small coherent-bus handshake for control and
  status snapshots crossing clock domains.
- `rtl/outstanding_table.sv`: Bounded response-tracking table keyed by AXI ID.
- `rtl/dma_core.sv`: DMA control FSM, aligned burst copy datapath, descriptor
  fetch/decode/status writeback, 2D descriptor extension, error handling, IRQ
  event pulses, and read/write response tracking.
- `rtl/dma_top.sv`: Dual-clock top-level integration for CSRs, CDC bridges,
  DMA core, AXI4-Lite slave pins, AXI4 master pins, and IRQ.

## Inactive Or Scaffolded RTL

These files are not in the active filelist and should not be studied as the
current implementation:

- `rtl/axi_lite_slave.sv`
- `rtl/dma_regs.sv`
- `rtl/axi_read_engine.sv`
- `rtl/axi_write_engine.sv`
- `rtl/descriptor_fetch.sv`
- `rtl/descriptor_decode.sv`
- `rtl/descriptor_scheduler.sv`
- `rtl/completion_writer.sv`
- `rtl/interrupt_controller.sv`
- `rtl/data_fifo.sv`
- `rtl/include/sys_defs.svh`

They preserve an earlier modular architecture direction and may be useful only
as rough notes. They are not wired into `dma_top` and are not verified.

## Current Architecture Summary

The integrated design is a register-programmed memory-to-memory DMA engine.
Software programs CSRs over AXI4-Lite in the `cfg_clk` domain. A start pulse
captures either single-shot transfer fields or descriptor-list configuration,
then crosses into `dma_clk` through an explicit bus handshake.

The DMA core runs one conservative transfer stream at a time. It validates
alignment and nonzero length, splits aligned AXI INCR bursts at
`MAX_BURST_BEATS` and 4KB boundaries, buffers one read burst internally, writes
that burst to the destination, checks response status, and repeats until the
transfer is complete.

Descriptor mode fetches 32-byte descriptors from memory. Linear descriptors
run one copy and write a 32-bit descriptor status word. The 2D mode extends the
descriptor to 64 bytes and repeats the same copy datapath row-by-row using
positive source and destination strides. Descriptor processing is counted by a
CSR-programmed `DESC_COUNT`; circular rings and linked lists are not present.

## Known Assumptions

- The default integrated data width is 32 bits.
- Descriptor mode is supported only when `DATA_WIDTH == 32`.
- Source address, destination address, transfer length, row length, and strides
  must be data-width aligned.
- AXI IDs are driven as zero by the integrated core.
- The active datapath relies on in-order read-buffer-write sequencing.
- CDC pulse synchronizers assume events are infrequent enough for the
  destination clock to observe toggle changes.
- The checked-in SDC is a broad starting point, not an ASIC timing signoff
  artifact.

## Known Limitations

- No descriptor rings, linked-list descriptors, ownership bits, or ring wrap.
- No arbitrary multi-outstanding AXI issue.
- No out-of-order response handling.
- No unaligned transfers, narrow transfers, or data-width conversion.
- No completion queue.
- No interrupt coalescing.
- No formal checks, UVM environment, or CDC signoff.
- No OpenLane/OpenROAD run scripts or completed ASIC flow.
- No performance counter subsystem.

## Current Verification Status

There are 19 cocotb tests:

- 2 tests for `axi_lite_regs`.
- 17 tests for `dma_top` and memory-side DMA behavior.

The tests cover CSR read/write behavior, read-only `VERSION`, W1C status and
IRQ bits, start/soft-reset pulses, aligned single-shot copies, burst splitting,
4KB boundary splitting, descriptor mode, one 2D descriptor smoke test, error
causes, AXI response errors, deterministic backpressure, reset behavior, and
small fixed-seed randomized scenarios.

The SystemVerilog testbench files under `tb/` and the Python model under
`model/` are scaffolding. The active verification flow is cocotb.

## Current Simulation Status

`./scripts/test.sh` could not run in this environment because `cocotb-config`
is not installed or not on `PATH`. No cocotb pass/fail result was produced
during this lock-down pass.

Expected command once dependencies are installed:

```sh
make test
```

## Current Lint/Build Status

`./scripts/lint.sh` completed successfully in this environment using
`/usr/bin/iverilog`. Verilator was not installed. Icarus emitted its known
SystemVerilog limitation messages about constant selects in `always_*`
processes for `rtl/axi_lite_regs.sv` and `rtl/outstanding_table.sv`, but the
command exited with status 0.

Expected command:

```sh
make lint
```

## Unclear Or Risky Areas

- CDC has structural synchronizers and handshake blocks, but no CDC lint or
  formal CDC analysis has been run.
- The outstanding tables are integrated as defensive response checks, but the
  core does not stress table depth because it issues one stream at a time.
- The 2D descriptor path has a smoke test but needs broader invalid-field,
  stride, reset, and randomized coverage.
- AXI protocol coverage is practical cocotb-level coverage, not exhaustive AXI
  compliance verification.
- Partial reset behavior between `cfg_clk` and `dma_clk` domains needs manual
  review.
- The inactive modular RTL and SystemVerilog testbench scaffolds could confuse
  readers if they are mistaken for the active architecture.

## Stale, Unused, Duplicated, Or Misleading Files

- Older inactive RTL shells listed above duplicate concepts now implemented
  directly inside `axi_lite_regs`, `dma_core`, and `dma_top`.
- `tb/tb_dma_top.sv`, `tb/axi_memory_model.sv`, `tb/axi_lite_driver.sv`,
  `tb/dma_scoreboard.sv`, and `tb/dma_assertions.sv` are not the active
  verification environment.
- `model/dma_model.py`, `model/gen_descriptors.py`, and
  `model/run_random_tests.py` are not wired into the cocotb regressions.
- `asic/openlane_config_placeholder.json` and `constraints/dma.sdc` are early
  ASIC-flow seeds only.
- `docs/proposal.md`, `docs/implementation_plan.md`, `docs/cdc_plan.md`, and
  `docs/tiled_dma_extension.md` are useful background, but the most current
  handoff sources are `README.md`, `docs/architecture.md`,
  `docs/register_map.md`, `docs/verification_plan.md`, this audit, and
  `docs/handoff_notes.md`.
