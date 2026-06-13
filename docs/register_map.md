# Register Map

Offsets are relative to the AXI4-Lite base address. All registers are 32 bits
wide and live in the `cfg_clk` domain. Unmapped addresses return `SLVERR`;
writes to read-only registers are accepted and ignored.

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
| `0x24` | `VERSION` | RO | `0x0008_0005` | Phase 8.5 version constant. |
| `0x28` | `DESC_BASE_LO` | RW | `0x0000_0000` | Descriptor list base address bits `[31:0]`. |
| `0x2c` | `DESC_BASE_HI` | RW | `0x0000_0000` | Descriptor list base address bits `[63:32]`. |
| `0x30` | `DESC_COUNT` | RW | `0x0000_0000` | Number of descriptors to process. |
| `0x34` | `MODE` | RW | `0x0000_0000` | DMA operating mode. |
| `0x38` | `DESC_INDEX` | RO | `0x0000_0000` | Current descriptor index while descriptor mode is active; retains the last processed index. |
| `0x3c` | `ERROR_CAUSE` | RO/W1C | `0x0000_0000` | Latched DMA error cause code. |
| `0x40` | `BYTES_REMAINING` | RO | `0x0000_0000` | Current transfer bytes remaining. |
| `0x44` | `ACTIVE_SRC_LO` | RO | `0x0000_0000` | Active source address bits `[31:0]`. |
| `0x48` | `ACTIVE_DST_LO` | RO | `0x0000_0000` | Active destination address bits `[31:0]`. |
| `0x4c` | `COMPLETED_DESC_COUNT` | RO | `0x0000_0000` | Descriptors completed in the current descriptor-mode run. |
| `0x50` | `COMPLETED_BYTE_COUNT_LO` | RO | `0x0000_0000` | Low 32 bits of bytes completed in the current run. |

## Bit Fields

### `CTRL` - `0x00`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `start` | W1P | Write `1` to launch a single-shot transfer or descriptor processing, depending on `MODE.descriptor_mode_enable`. |
| `1` | `soft_reset` | W1P | Write `1` to reset the DMA core internal control state. |
| `31:2` | `reserved` | RO | Reads as zero. |

### `STATUS` - `0x04`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `busy` | RO | Set while the DMA core is active. |
| `1` | `done` | W1C | Latched when a transfer completes successfully. Write `1` to clear. |
| `2` | `error` | W1C | Latched on invalid programming, invalid descriptor, or AXI response error. Write `1` to clear. Clearing this bit also clears `ERROR_CAUSE`. It does not clear `IRQ_STATUS.error_irq`. |
| `3` | `descriptor_active` | RO | Set while descriptor mode is actively fetching, executing, or writing back a descriptor. |
| `31:4` | `reserved` | RO | Reads as zero. |

### `IRQ_ENABLE` - `0x1c`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `single_done_irq_en` | RW | Assert `irq` when `IRQ_STATUS.single_done_irq` is pending. |
| `1` | `error_irq_en` | RW | Assert `irq` when `IRQ_STATUS.error_irq` is pending. |
| `2` | `descriptor_done_irq_en` | RW | Assert `irq` when `IRQ_STATUS.descriptor_done_irq` is pending. |
| `3` | `descriptor_list_done_irq_en` | RW | Assert `irq` when `IRQ_STATUS.descriptor_list_done_irq` is pending. |
| `31:4` | `reserved` | RO | Reads as zero. |

### `IRQ_STATUS` - `0x20`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `single_done_irq` | W1C | Latched when a single-shot transfer completes. Write `1` to clear. |
| `1` | `error_irq` | W1C | Latched error interrupt status. Write `1` to clear. |
| `2` | `descriptor_done_irq` | W1C | Latched when a descriptor finishes successfully. Write `1` to clear. |
| `3` | `descriptor_list_done_irq` | W1C | Latched when descriptor processing stops successfully because the configured count was reached or `stop_after` was set. Write `1` to clear. |
| `31:4` | `reserved` | RO | Reads as zero. |

`IRQ_STATUS` bits latch events even when the corresponding `IRQ_ENABLE` bit is
clear. The top-level `irq` output is the OR of `IRQ_STATUS & IRQ_ENABLE`, so it
deasserts after all enabled pending bits are cleared.

### `MODE` - `0x34`

| Bit | Name | Access | Description |
| --- | --- | --- | --- |
| `0` | `descriptor_mode_enable` | RW | When set, `CTRL.start` fetches and processes descriptors from `DESC_BASE` instead of using the single-shot source, destination, and length CSRs. |
| `31:1` | `reserved` | RO | Reads as zero. |

### Descriptor `CONTROL` Mode Bits

Descriptor word 5 is the in-memory descriptor control word. Existing 32-byte
linear descriptors remain valid when bits `[7:4]` are zero.

| Bits | Name | Description |
| --- | --- | --- |
| `0` | `valid` | Descriptor is valid when set. |
| `2` | `stop_after` | Stop descriptor processing after this descriptor completes successfully. |
| `7:4` | `descriptor_mode` | `0`: linear copy using the 32-byte format. `1`: 2D strided copy using the 64-byte extended format. Other values report `ERROR_CAUSE_DESC_MODE_UNSUPPORTED`. |

### `ERROR_CAUSE` - `0x3c`

`ERROR_CAUSE` is cleared by writing one to `STATUS.error`, by writing a nonzero
value to `ERROR_CAUSE`, by `CTRL.soft_reset`, or by starting a new valid
operation.

| Value | Meaning |
| --- | --- |
| `0x0000_0000` | No latched cause. |
| `0x0000_0001` | Transfer length was zero. |
| `0x0000_0002` | Source address was not data-width aligned. |
| `0x0000_0003` | Destination address was not data-width aligned. |
| `0x0000_0004` | Transfer length was not data-width aligned. |
| `0x0000_0005` | Descriptor base address was not 32-byte aligned. |
| `0x0000_0006` | Descriptor count was zero. |
| `0x0000_0007` | Descriptor valid bit was clear. |
| `0x0000_0008` | AXI read response/protocol error. |
| `0x0000_0009` | AXI write response error. |
| `0x0000_000a` | Descriptor mode was requested with an unsupported DMA data width. |
| `0x0000_000b` | Descriptor status writeback response error. |
| `0x0000_000c` | Outstanding transaction table lookup or retire error. |
| `0x0000_000d` | Descriptor control mode field was unsupported. |
| `0x0000_000e` | 2D descriptor row byte count was zero. |
| `0x0000_000f` | 2D descriptor row count was zero. |
| `0x0000_0010` | 2D source stride was unaligned or smaller than `row_bytes`. |
| `0x0000_0011` | 2D destination stride was unaligned or smaller than `row_bytes`. |
