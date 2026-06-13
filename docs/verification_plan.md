# Verification Plan

## Directed Testing

- Reset and register accessibility smoke tests.
- Single-shot aligned memory-to-memory transfer checks.
- Burst length checks for single-burst, multi-burst, and final short-burst
  transfers.
- 4KB boundary split checks for read and write bursts.
- Linear descriptor mode tests for one descriptor and multiple descriptors.
- 2D strided descriptor smoke test for padded-to-compact tile movement.
- Invalid descriptor tests for visible global and descriptor status errors.
- IRQ pending, enable, and write-one-to-clear behavior.
- Error cause readback and documented clear behavior.
- AXI read and write response error injection.
- Reset while idle and during an active transfer.
- Split-clock top-level smoke coverage with AXI-Lite helpers on `cfg_clk` and
  AXI memory-side modeling on `dma_clk`.
- Completion queue and deeper CDC stress tests in later phases.

## Randomized Testing

- Random linear descriptor streams with bounded lengths and aligned addresses.
- Random 2D descriptor streams with aligned row sizes and positive strides in a
  later verification pass.
- Randomized AXI backpressure on AR, R, AW, W, and B channels.
- Error-injection scenarios for `RRESP` and `BRESP`.
- Outstanding-table stress with unexpected IDs, table-full scenarios, and
  retire errors once directed table-level tests are added.
- CDC stress with varied `cfg_clk`/`dma_clk` ratios and back-to-back control,
  status, and event crossings.

## Current Cocotb Coverage Checklist

- CSR read/write, read-only `VERSION`, reserved-bit readback, and unmapped
  access responses.
- `STATUS` and `IRQ_STATUS` write-one-to-clear behavior, including writes of
  zero not clearing latched bits.
- Single-shot aligned transfers.
- Burst splitting across `MAX_BURST_BEATS`, final short bursts, and 4KB
  boundaries.
- Linear descriptor mode with one descriptor and multiple descriptors.
- 2D strided descriptor mode with one padded-to-compact smoke test.
- Descriptor validation errors: valid bit clear, zero length, unaligned source,
  unaligned destination, descriptor count zero, and descriptor base unaligned.
- Interrupt behavior for single-shot done, error, descriptor done, and
  descriptor list done pending bits.
- `ERROR_CAUSE` values for programming, descriptor, AXI read, and AXI write
  errors.
- Deterministic AXI backpressure on address, read data, write data, and write
  response channels.
- Deterministic randomized aligned single-shot and descriptor-list tests.
- Reset while idle and while active.
- DMA top-level smoke tests updated for separate `cfg_clk`/`cfg_rst_n` and
  `dma_clk`/`dma_rst_n` domains.

## Running Tests

Run all scripted cocotb tests with:

```sh
./scripts/test.sh
```

The randomized tests use fixed seeds and print the seed in the cocotb log. Test
counts are intentionally small so regressions stay quick and deterministic.

## Known Verification Gaps

- No UVM environment.
- No formal coverage tooling.
- No directed unit tests for `outstanding_table` yet.
- No malformed/unknown AXI ID response tests yet.
- No deep CDC stress or formal CDC analysis yet.
- No broad 2D randomized testing yet.
- No directed tests yet for every 2D validation error code.
- No arbitrary multi-outstanding transaction stress because the RTL
  intentionally issues one transaction stream at a time.
- No ASIC-flow checks yet.

## Checkers

- Scoreboard comparison against a Python reference model.
- Assertions for AXI handshakes, FIFO safety, and completion ordering.
- Coverage for descriptor types, burst lengths, and error conditions.
