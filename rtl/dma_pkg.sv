`timescale 1ns/1ps

`include "sys_defs.svh"

package dma_pkg;

  typedef logic [`DMA_ADDR_W-1:0] dma_addr_t;
  typedef logic [`DMA_DATA_W-1:0] dma_data_t;
  typedef logic [`DMA_STRB_W-1:0] dma_strb_t;
  typedef logic [`DMA_LEN_W-1:0]  dma_len_t;
  typedef logic [`DMA_TAG_W-1:0]  dma_tag_t;

endpackage
