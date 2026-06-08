# Register Map

Offsets are relative to the AXI4-Lite base address. All registers are 32 bits
wide. Unmapped addresses return `SLVERR`; writes to read-only registers are
accepted and ignored.

| Offset | Name | Access | Reset | Description |
| --- | --- | --- | --- | --- |
| `0x00` | `CTRL` | W1P | `0x0000_0000` | Control pulses. Reads as zero. |
| `0x04` | `STATUS` | RO/W1C | `0x0000_0000` | DMA status bits. |
| `0x08` | `SRC_ADDR_LO` | RW | `0x0000_0000` | Source address bits `[31:0]`. |
| `0x0c` | `SRC_ADDR_HI` | RW | `0x0000_0000` | Source address bits `[63:32]`. |
| `0x10` | `DST_ADDR_LO` | RW | `0x0000_0000` | Destination address bits `[31:0]`. |
| `0x14` | `DST_ADDR_HI` | RW | `0x0000_0000` | Destination address bits `[63:32]`. |
| `0x18` | `LEN_BYTES` | RW | `0x0000_0000` | Transfer length in bytes. Must be nonzero and word aligned. |
| `0x1c` | `IRQ_ENABLE` | RW | `0x0000_0000` | IRQ enable mask. |
| `0x20` | `IRQ_STATUS` | W1C | `0x0000_0000` | Latched IRQ status bits. |
| `0x24` | `VERSION` | RO | `0x0001_0000` | Phase 1/2 version constant. |

## Bit Fields

### `CTRL` - `0x00`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `start` | W1P | Write `1` to launch one transfer using the programmed source, destination, and length. |
| `1` | `soft_reset` | W1P | Write `1` to reset the DMA core internal control state. |
| `31:2` | `reserved` | RO | Reads as zero. |

### `STATUS` - `0x04`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `busy` | RO | Set while the DMA core is active. |
| `1` | `done` | W1C | Latched when a transfer completes successfully. Write `1` to clear. |
| `2` | `error` | W1C | Latched on invalid programming or AXI response error. Write `1` to clear. |
| `31:3` | `reserved` | RO | Reads as zero. |

### `IRQ_ENABLE` - `0x1c`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `done_irq_en` | RW | Latch `IRQ_STATUS.done_irq` when a done event occurs. |
| `1` | `error_irq_en` | RW | Latch `IRQ_STATUS.error_irq` when an error event occurs. |
| `31:2` | `reserved` | RO | Reads as zero. |

### `IRQ_STATUS` - `0x20`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `done_irq` | W1C | Latched done interrupt status. Write `1` to clear. |
| `1` | `error_irq` | W1C | Latched error interrupt status. Write `1` to clear. |
| `31:2` | `reserved` | RO | Reads as zero. |
