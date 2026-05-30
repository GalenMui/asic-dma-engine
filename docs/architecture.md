# Architecture

## Overview

The planned design centers on a software-visible AXI4-Lite control plane and a
DMA datapath that fetches descriptors, schedules memory traffic, buffers data,
writes completion records, and raises interrupts.

## Planned Blocks

- `axi_lite_slave`: AXI4-Lite protocol termination for control registers.
- `dma_regs`: control/status register file and future clock-domain crossing
  control mirrors.
- `descriptor_fetch`: reads descriptor records from memory.
- `descriptor_decode`: validates and converts descriptor records into internal
  commands.
- `descriptor_scheduler`: dispatches work while respecting FIFO and
  outstanding-transaction limits.
- `axi_read_engine`: issues constrained AXI4 read bursts.
- `data_fifo`: buffers read data before writes.
- `axi_write_engine`: issues constrained AXI4 write bursts.
- `completion_writer`: formats completion queue entries.
- `outstanding_table`: tracks in-flight AXI transactions.
- `interrupt_controller`: aggregates completion and error events.
- `cdc_*`: future helpers for cfg/dma clock-domain crossings.

## Phases

- Phase 0: skeleton, documentation, and placeholders.
- Phase 1: register-programmed DMA MVP with a simplified internal memory
  interface.
- Phase 2+: incremental introduction of buffering, descriptor rings, AXI-Lite,
  constrained AXI4, CDC, and ASIC flow artifacts.
