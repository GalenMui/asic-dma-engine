# Proposal

This repository will host a descriptor-based AXI4 DMA engine with AXI4-Lite
control and a constrained AXI4 memory-mapped master datapath intended for ASIC
implementation work.

The current integrated RTL includes AXI4-Lite CSRs, aligned single-shot DMA,
conservative AXI INCR burst transfers, and a simple linear descriptor-count
mode. It also includes explicit interrupt pending bits, error-cause readback,
basic observability registers, bounded outstanding transaction tracking, and a
dual-clock top-level split with explicit CDC between the AXI-Lite configuration
domain and DMA datapath domain. Phase 8.5 adds a layout-aware 2D strided
descriptor mode so one descriptor can describe a multi-row tile transfer.

It is still intentionally limited: no descriptor rings, linked-list
scatter-gather, arbitrary multi-outstanding AXI issuing, out-of-order response
handling, completion queues, transpose/compression/sparse modes, AXI4-Stream,
ASIC constraints, or implementation flow are implemented yet.
