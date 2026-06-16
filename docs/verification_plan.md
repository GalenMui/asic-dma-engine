# Verification Plan

This plan is a practical handoff for continuing verification. It records what
exists, how to run it, what each test is meant to prove, and what still needs
manual owner work.

## Current Test Entry Points

Run all active cocotb tests:

```sh
make test
```

Run only the CSR block tests:

```sh
make -C tb/cocotb TOPLEVEL=axi_lite_regs MODULE=test_axi_lite_regs
```

Run only the integrated DMA tests:

```sh
make -C tb/cocotb TOPLEVEL=dma_top MODULE=test_dma_smoke
```

Clean generated simulator outputs:

```sh
make clean
```

Expected behavior: all cocotb tests should pass with `cocotb`, `make`, and a
supported simulator installed. In this lock-down environment, `make test`
failed before simulation because `cocotb-config` was not installed.

## Current Tests

`tb/cocotb/test_axi_lite_regs.py`:

- `register_read_write_and_status_clear`: checks writable CSRs, read-only
  `VERSION`, observability readback, W1C `STATUS`, W1C `IRQ_STATUS`, IRQ
  gating, and unmapped `SLVERR` behavior.
- `ctrl_write_generates_pulses`: checks `CTRL.start` and `CTRL.soft_reset`
  write-one pulse generation.

`tb/cocotb/test_dma_smoke.py`:

- `dma_memory_to_memory_smoke`: checks a 16-byte aligned copy, burst metadata,
  done status, IRQ status, and clear behavior.
- `dma_unaligned_address_sets_error`: checks source alignment error behavior.
- `dma_multi_burst_transfer`: checks splitting above `MAX_BURST_BEATS`.
- `dma_final_short_burst_transfer`: checks final short aligned burst behavior.
- `dma_splits_bursts_at_4kb_boundaries`: checks source/destination 4KB burst
  boundary splitting.
- `descriptor_mode_single_descriptor`: checks one linear descriptor fetch,
  copy, and status writeback.
- `descriptor_mode_2d_padded_to_compact`: checks one 2D padded-to-compact tile
  copy and completed byte/descriptor counters.
- `descriptor_mode_multiple_descriptors`: checks a two-descriptor linear list.
- `descriptor_mode_invalid_descriptor_sets_error`: checks invalid descriptor
  status writeback and global error.
- `irq_error_clear_and_error_cause`: checks error IRQ clear and
  `ERROR_CAUSE` clear behavior.
- `axi_read_error_response_sets_error`: checks injected `RRESP` error handling.
- `axi_write_error_response_sets_error`: checks injected `BRESP` error
  handling.
- `dma_backpressure_transfer_and_observability`: checks deterministic channel
  stalls and progress register visibility.
- `randomized_aligned_single_shot_transfers`: runs a small fixed-seed set of
  aligned single-shot copies.
- `randomized_descriptor_list`: runs a small fixed-seed linear descriptor list.
- `descriptor_validation_error_causes`: checks selected descriptor start and
  descriptor field validation errors.
- `reset_idle_and_active_clears_state`: checks reset while idle and while an
  operation is active.

## Current Non-Active Test Assets

- `tb/tb_dma_top.sv` is a simple SystemVerilog top-level scaffold, not an
  active directed test.
- `tb/axi_memory_model.sv`, `tb/axi_lite_driver.sv`, `tb/dma_scoreboard.sv`,
  and `tb/dma_assertions.sv` are scaffolds only.
- The active memory model and AXI-Lite helpers live in the cocotb Python tests.
- `model/` contains Python scaffolding that is not wired into regression
  checking.

## Missing Directed Tests

- AXI-Lite writes with independent AW/W timing over more stall patterns.
- AXI-Lite reads and writes while DMA status events arrive in nearby cycles.
- Back-to-back `CTRL.start` writes while the control CDC handshake is busy.
- `CTRL.soft_reset` during each major `dma_core` FSM state.
- Error clear while a new operation is starting.
- Descriptor `stop_after` behavior.
- Unsupported descriptor mode values.
- All 2D validation error causes, including zero row count, zero row bytes,
  source stride errors, destination stride errors, and unsupported mode fields.
- Descriptor extension fetch read errors.
- Descriptor status writeback `BRESP` error behavior.
- Unexpected read response IDs.
- Unexpected write response IDs.
- Outstanding table full/duplicate-ID behavior at unit-test level.
- Partial reset cases with only `cfg_rst_n` or only `dma_rst_n` asserted.

## Randomized Test Ideas

- Random aligned single-shot transfers across page boundaries.
- Random descriptor lists with mixed short and multi-burst lengths.
- Random descriptor `stop_after` placement.
- Random legal 2D tile shapes with positive aligned strides.
- Random deterministic channel backpressure on AR, R, AW, W, and B.
- Random `RRESP` and `BRESP` error injection by beat or address.
- Random reset injection while preserving reproducible seeds.

Keep randomized tests bounded and deterministic until the directed test suite is
stronger.

## AXI Protocol Corner Cases

- AW and W accepted in different cycles.
- R channel stalls on every beat, including final beat.
- W channel stalls on every beat, including final beat.
- B channel delayed after WLAST.
- Unexpected `RLAST` early or late.
- Non-OKAY `RRESP` before final beat.
- Non-OKAY `BRESP`.
- Response ID mismatch.
- Address handshake attempted while the tracking table is full.

This project does not yet claim full AXI compliance. These are practical
project-level checks to add before any stronger claim.

## Descriptor Corner Cases

- `DESC_COUNT == 0`.
- Unaligned `DESC_BASE`.
- Descriptor valid bit clear.
- Zero transfer length.
- Unaligned source or destination.
- Length not data-width aligned.
- Unsupported descriptor mode.
- 2D row count zero.
- 2D row bytes zero.
- 2D source or destination stride unaligned.
- 2D source or destination stride smaller than row bytes.
- Descriptor status writeback failure.
- End-of-list versus `stop_after` completion.

## Reset Corner Cases

- Reset before any operation.
- Reset during descriptor fetch.
- Reset during descriptor extension fetch.
- Reset during AXI read data capture.
- Reset during AXI write data issue.
- Reset while waiting for `BRESP`.
- Reset during descriptor status writeback.
- Reset with pending IRQ bits.
- Reset one clock domain without the other.

## Interrupt Corner Cases

- IRQ status latches when enables are zero.
- Enabling an already-pending interrupt asserts `irq`.
- Clearing one pending bit leaves other enabled pending bits asserted.
- Clearing `STATUS.error` clears `ERROR_CAUSE` but not `IRQ_STATUS.error_irq`.
- Descriptor done and descriptor list done both set on a one-descriptor list.
- Error interrupt during descriptor mode after descriptor status writeback.

## Backpressure Corner Cases

- Long ARREADY deassertion.
- Long RVALID gaps.
- WREADY deassertion on first, middle, and final beats.
- Delayed BVALID.
- Combined stalls across read and write channels.
- Progress register reads while a stalled transfer is active.

## Error Handling And Unsupported Behavior

Unsupported or intentionally limited behavior should produce an error or remain
documented as unsupported rather than silently appearing to work:

- Unaligned source/destination/length.
- Descriptor mode with unsupported data width.
- Unsupported descriptor control mode.
- AXI read/write response errors.
- Descriptor status writeback response errors.
- Out-of-order or mismatched AXI IDs.
- Descriptor rings, linked lists, and completion queues.

## Suggested Coverage Points

- CSR address coverage for every mapped register plus unmapped access.
- W1C bit coverage for `STATUS` and `IRQ_STATUS`.
- Transfer length buckets: 1 beat, less than max burst, exactly max burst, more
  than max burst, final short burst.
- 4KB boundary split positions for source and destination.
- Descriptor count buckets: 1, 2, several.
- Descriptor type: linear and 2D.
- Error cause value coverage.
- IRQ pending/enable/clear combinations.
- Reset state coverage across the DMA FSM.
- CDC clock-ratio coverage.

## Suggested Assertions

- AXI-Lite response is eventually produced for each accepted request.
- `CTRL.start` and `CTRL.soft_reset` are one-cycle pulses in the CSR domain.
- No burst crosses a 4KB boundary.
- `m_axi_wlast` matches the programmed burst length.
- Read beat count matches `ARLEN + 1`.
- Descriptor status writeback is one beat with the expected strobe.
- Outstanding table allocations and retires do not underflow or overflow.
- `busy_o` is low only in `ST_IDLE`.
- Error states pulse `error_pulse_o` exactly once per failing operation.
- CDC handshake source data remains stable while the source side is busy.
