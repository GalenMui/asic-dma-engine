# Register Map

The initial register map is placeholder documentation for the future
software-visible control block. Offsets are relative to the AXI4-Lite base.

| Offset | Name | Purpose |
| --- | --- | --- |
| `0x0000` | `CONTROL` | Enable, reset, and software kick bits. |
| `0x0004` | `STATUS` | Busy, idle, and high-level status flags. |
| `0x0008` | `DESC_BASE_LO` | Descriptor ring base address low word. |
| `0x000c` | `DESC_BASE_HI` | Descriptor ring base address high word. |
| `0x0010` | `DESC_HEAD` | Hardware-owned descriptor head pointer. |
| `0x0014` | `DESC_TAIL` | Software-owned descriptor tail pointer. |
| `0x0018` | `DESC_RING_SIZE` | Descriptor ring depth/configuration. |
| `0x001c` | `COMP_BASE_LO` | Completion ring base address low word. |
| `0x0020` | `COMP_BASE_HI` | Completion ring base address high word. |
| `0x0024` | `COMP_HEAD` | Hardware-owned completion head pointer. |
| `0x0028` | `COMP_TAIL` | Software-owned completion tail pointer. |
| `0x002c` | `COMP_RING_SIZE` | Completion ring depth/configuration. |
| `0x0030` | `IRQ_ENABLE` | Interrupt enable mask. |
| `0x0034` | `IRQ_STATUS` | Interrupt status and pending bits. |
| `0x0038` | `ERROR_STATUS` | Latched error reporting. |
| `0x003c` | `CONFIG` | Static configuration visibility. |
| `0x0040` | `MAX_BURST_LEN` | Constrained AXI burst limit. |
| `0x0044` | `PERF_DESC_FETCH_CNT` | Placeholder descriptor-fetch counter. |
| `0x0048` | `PERF_READ_BEATS` | Placeholder read-beat counter. |
| `0x004c` | `PERF_WRITE_BEATS` | Placeholder write-beat counter. |

## Notes

- Ownership between software and hardware is still to be finalized.
- Clear-on-write and write-1-to-clear semantics are intentionally unspecified.
- Future cfg-to-dma CDC handling may require shadow registers or pulse/toggle
  synchronizers.
