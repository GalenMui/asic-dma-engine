# Descriptor-Based AXI4 DMA Engine

This project is a scaffold for a descriptor-based AXI4 DMA engine with an
AXI4-Lite control interface, a constrained AXI4 memory-mapped master datapath,
and downstream ASIC timing-closure and physical-design work.

## Current Status

Skeleton only. The repository currently contains module shells, placeholder
verification files, planning documents, a starter SDC, and OpenLane/OpenROAD
placeholders. The DMA is not implemented yet, and no full AXI4 behavior should
be assumed.

## Planned Architecture

- AXI4-Lite slave for software control/status
- Register block for descriptor/completion ring management
- Descriptor fetch, decode, and scheduling pipeline
- Read engine, FIFO buffering, write engine, and completion writer
- Outstanding transaction tracking and interrupt aggregation
- Optional cfg/dma CDC support
- ASIC timing and physical-implementation collateral

## Roadmap

- Phase 0: skeleton and docs
- Phase 1: register-programmed DMA MVP with simplified internal memory interface
- Phase 2: FIFO and backpressure
- Phase 3: AXI4-Lite control interface
- Phase 4: descriptor ring
- Phase 5: completion queue
- Phase 6: constrained AXI4 memory master
- Phase 7: outstanding transaction tracking
- Phase 8: CDC
- Phase 9: ASIC constraints and synthesis
- Phase 10: place and route and PPA study

## Placeholder Commands

Run the placeholder simulation flow:

```sh
make -C sim sim
```

Run the placeholder lint flow:

```sh
make -C sim lint
```

Clean generated placeholder artifacts:

```sh
make -C sim clean
```

