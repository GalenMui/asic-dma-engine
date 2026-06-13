# AGENTS.md

## Project

This repo is `asic-dma-engine`, an ASIC-oriented SystemVerilog DMA engine project.

Goal: build a credible RTL portfolio project with AXI4-Lite CSRs, AXI4 memory-side DMA behavior, cocotb verification, and later OpenLane ASIC flow.

Current focus: implement only the phase explicitly requested. Do not implement future phases early.

For the full roadmap, see:
- `docs/project_plan.md`
- `docs/register_map.md`
- `docs/architecture.md`

## Working rules

Think before coding:
- State assumptions before implementation.
- If the task is ambiguous, ask before coding.
- If multiple interpretations exist, present them.
- Push back on overcomplicated requests.

Keep changes simple:
- Minimum code that solves the task.
- No speculative features.
- No abstractions for single-use code.
- No descriptor rings, bursts, outstanding transactions, UVM, vendor IP, or OpenLane flow unless explicitly requested.

Make surgical edits:
- Touch only files required by the task.
- Do not refactor unrelated code.
- Match existing style.
- Do not reformat unrelated files.
- Remove only unused code created by your own changes.

Work against verifiable goals:
- Define success criteria before coding.
- Add or update tests for behavior changes.
- Run relevant lint/tests when possible.
- If checks cannot run, say exactly why.

## RTL style

Use synthesizable SystemVerilog:
- `logic`
- `always_ff` for sequential logic
- `always_comb` for combinational logic
- nonblocking assignments in sequential logic
- blocking assignments in combinational logic
- explicit reset behavior
- no inferred latches
- no unsynthesizable RTL in `rtl/`

## Verification

Prefer cocotb tests.

Expected early tests:
- AXI-Lite CSR reads/writes
- read-only VERSION behavior
- write-one-to-clear status behavior
- start pulse behavior
- DMA memory copy smoke test
- invalid transfer error test

## Documentation

Keep docs honest.

Do not claim:
- production-ready
- high-performance
- fully AXI compliant
- descriptor support
- burst support
- ASIC flow completion

unless actually implemented and verified.