`ifndef ASIC_DMA_SYS_DEFS_SVH
`define ASIC_DMA_SYS_DEFS_SVH

// old compatibility defines for early experiments, new rtl should use dma_pkg
`define DMA_ADDR_W      64
`define DMA_DATA_W      64
`define DMA_STRB_W      (`DMA_DATA_W / 8)
`define DMA_LEN_W       16
`define DMA_TAG_W       4
`define DMA_DESC_WORDS  8
`define DMA_COMP_WORDS  8

`endif
