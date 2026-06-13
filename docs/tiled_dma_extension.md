# Tiled DMA Extension

## Motivation

Accelerator data movement often uses tiles rather than long flat buffers. A
GEMM, DSP, or image-processing kernel may need to copy a compact tile out of a
padded matrix, copy a compact tile into padded storage, or move data between two
padded layouts.

Without tiled DMA support, software must emit one linear descriptor per row.
That works, but descriptor fetches, status writebacks, and software queue
management scale with row count.

## Baseline Method

The baseline method represents a tile as many linear descriptors:

```text
for row in 0..num_rows-1:
  descriptor[row].src = src_base + row * src_stride_bytes
  descriptor[row].dst = dst_base + row * dst_stride_bytes
  descriptor[row].len = row_bytes
```

Baseline row-by-row descriptors require one descriptor fetch and one descriptor
status writeback per row.

## Proposed Method

The 2D tiled descriptor represents the full tile with one descriptor. Hardware
generates row addresses internally:

```text
for row in 0..num_rows-1:
  copy row_bytes from src_base + row * src_stride_bytes
                 to dst_base + row * dst_stride_bytes
```

The 2D tiled descriptor requires one base descriptor fetch, one extension fetch,
and one descriptor status writeback for the entire tile.

## Descriptor Format

Existing 32-byte linear descriptors are unchanged. A 2D descriptor uses the
same first 32 bytes plus a 32-byte extension:

| Offset | Field | Description |
| --- | --- | --- |
| `0x00` | `SRC_ADDR_LO` | Row 0 source address bits `[31:0]`. |
| `0x04` | `SRC_ADDR_HI` | Row 0 source address bits `[63:32]`. |
| `0x08` | `DST_ADDR_LO` | Row 0 destination address bits `[31:0]`. |
| `0x0c` | `DST_ADDR_HI` | Row 0 destination address bits `[63:32]`. |
| `0x10` | `ROW_BYTES` | Bytes copied per row. |
| `0x14` | `CONTROL` | Bit 0 valid, bit 2 stop-after, bits `[7:4] = 1` for 2D. |
| `0x18` | `STATUS` | Descriptor status written once after the full tile. |
| `0x1c` | `RESERVED` | Reserved. |
| `0x20` | `NUM_ROWS` | Number of rows. |
| `0x24` | `SRC_STRIDE_BYTES` | Byte distance between source rows. |
| `0x28` | `DST_STRIDE_BYTES` | Byte distance between destination rows. |
| `0x2c`-`0x3c` | `RESERVED` | Reserved. |

## Execution Flow

1. Fetch the base 32-byte descriptor.
2. Decode `CONTROL[7:4]`.
3. For linear mode, use the existing linear descriptor path.
4. For 2D mode, fetch the 32-byte extension.
5. Validate `row_bytes`, `num_rows`, alignment, and strides.
6. Run each row through the existing AXI burst copy engine.
7. After each successful row, add source and destination strides to registered
   row-base address registers.
8. After the final row's write response succeeds, write one descriptor status
   word for the full 2D descriptor.

## Expected Benefits

The research claim is that one 2D descriptor reduces software/control overhead
for tiled accelerator data movement compared with one linear descriptor per row.

For an `N` row tile:

- Baseline: `N` descriptor fetches and `N` descriptor status writebacks.
- 2D tiled: one base descriptor fetch, one extension fetch, and one descriptor
  status writeback.

The data traffic is the same; the control traffic and descriptor management
traffic are reduced.

## Evaluation Plan

Compare a padded-to-compact, compact-to-padded, and padded-to-padded tile using:

- row-by-row linear descriptors
- one 2D tiled descriptor

Useful metrics:

- descriptors fetched
- descriptor status writebacks
- active cycles
- read and write bursts issued
- bytes moved
- completion latency

The current RTL exposes completed descriptor count and completed byte count.
It does not yet expose dedicated descriptor-fetch, status-writeback, burst, or
active-cycle counters.

## Limitations

- No transpose.
- No compression.
- No sparse gather/scatter mode.
- No negative strides.
- No unaligned transfers.
- No overlapping-row support; strides must be at least `row_bytes`.
- No cache coherence.
- No AXI4-Stream.
- No ASIC flow, constraints, or physical implementation work in this phase.
