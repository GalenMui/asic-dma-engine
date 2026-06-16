# Handoff Notes

This repository is now documented as a pre-verification, pre-ASIC-flow
baseline. The goal is for the human owner to review, verify, and evolve the
design deliberately rather than relying on generated RTL changes.

## Stable Enough To Study First

- `rtl/dma_pkg.sv`
- `rtl/axi_lite_regs.sv`
- `rtl/cdc_toggle_sync.sv`
- `rtl/cdc_pulse_sync.sv`
- `rtl/cdc_bus_handshake.sv`
- `rtl/outstanding_table.sv`
- `rtl/dma_core.sv`
- `rtl/dma_top.sv`
- `docs/register_map.md`
- `docs/architecture.md`
- `tb/cocotb/test_axi_lite_regs.py`
- `tb/cocotb/test_dma_smoke.py`

These files form the active integration path and the active verification path.

## Needs Manual Review Before Trust

- AXI4 protocol details beyond the currently directed cocotb scenarios.
- CDC behavior under varied clock ratios and partial resets.
- Descriptor error/status behavior across all 2D invalid-field combinations.
- Outstanding table behavior under malformed or unexpected response IDs.
- Reset behavior during each active FSM state.
- SDC constraints and any future ASIC-flow assumptions.

## Files Changed In This Lock-Down Pass

- `Makefile`
- `AGENTS.md`
- `README.md`
- `TODO.md`
- `scripts/clean.sh`
- `docs/architecture.md`
- `docs/verification_plan.md`
- `docs/repo_audit.md`
- `docs/handoff_notes.md`
- Inactive scaffold comments in `rtl/`, `tb/`, and `model/` files that had
  vague inline TODO markers.

## Do Not Trust Yet

- The inactive modular RTL shells not present in `sim/filelist.f`.
- The SystemVerilog-only testbench scaffolding under `tb/`.
- The Python model scaffolding under `model/`.
- ASIC/OpenLane collateral under `asic/` and `constraints/`.
- Any claim of full AXI compliance, production readiness, or ASIC signoff.

## Recommended Reading Order

1. `README.md`
2. `docs/repo_audit.md`
3. `docs/register_map.md`
4. `docs/architecture.md`
5. `rtl/dma_pkg.sv`
6. `rtl/axi_lite_regs.sv`
7. `rtl/dma_top.sv`
8. `rtl/dma_core.sv`
9. `tb/cocotb/test_axi_lite_regs.py`
10. `tb/cocotb/test_dma_smoke.py`
11. `docs/verification_plan.md`

## Recommended Verification Order

1. Install cocotb and Icarus or Verilator, then run `make lint` and
   `make test`.
2. Review `axi_lite_regs` against `docs/register_map.md`.
3. Review single-shot transfer flow in `dma_core` against the smoke tests.
4. Review descriptor fetch, descriptor status writeback, and stop conditions.
5. Add directed tests for missing 2D descriptor error cases.
6. Add tests for unexpected AXI IDs and outstanding-table failure paths.
7. Add varied clock-ratio and partial-reset CDC tests.
8. Only then start changing architecture or ASIC-flow collateral.

## Assumptions Made

- The current integrated RTL is the baseline.
- Cocotb is the active verification path.
- Inactive scaffold modules should remain checked in for now but be clearly
  labeled as inactive.
- No major RTL redesign belongs in this lock-down pass.

## Chosen Non-Changes

- No descriptor rings, linked lists, completion queues, or new counters were
  added.
- No inactive scaffold modules were deleted.
- No DMA FSM rewrite was attempted.
- No ASIC/OpenLane flow was created.
- No full verification environment was generated.
