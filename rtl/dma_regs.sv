`timescale 1ns/1ps

module dma_regs #(
  parameter int ADDR_WIDTH     = dma_pkg::ADDR_WIDTH,
  parameter int REG_ADDR_WIDTH = 16,
  parameter int REG_DATA_WIDTH = 32
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      reg_req_valid,
  output logic                      reg_req_ready,
  input  logic                      reg_req_write,
  input  logic [REG_ADDR_WIDTH-1:0] reg_req_addr,
  input  logic [REG_DATA_WIDTH-1:0] reg_req_wdata,
  input  logic [(REG_DATA_WIDTH/8)-1:0] reg_req_wstrb,
  output logic                      reg_rsp_valid,
  input  logic                      reg_rsp_ready,
  output logic [REG_DATA_WIDTH-1:0] reg_rsp_rdata,
  output logic [1:0]                reg_rsp_resp,

  input  logic                      dma_busy_i,
  input  logic                      dma_error_i,
  output logic                      dma_enable_o,
  output logic                      irq_enable_o,
  output logic [ADDR_WIDTH-1:0]     desc_base_addr_o,
  output logic [15:0]               desc_head_o,
  output logic [15:0]               desc_tail_o,
  output logic [15:0]               desc_ring_size_o,
  output logic [ADDR_WIDTH-1:0]     comp_base_addr_o,
  output logic [15:0]               comp_head_o,
  output logic [15:0]               comp_tail_o,
  output logic [15:0]               comp_ring_size_o,
  output logic [7:0]                max_burst_len_o
);

  localparam logic [REG_ADDR_WIDTH-1:0] CONTROL             = 'h0000;
  localparam logic [REG_ADDR_WIDTH-1:0] STATUS              = 'h0004;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_BASE_LO        = 'h0008;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_BASE_HI        = 'h000c;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_HEAD           = 'h0010;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_TAIL           = 'h0014;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_RING_SIZE      = 'h0018;
  localparam logic [REG_ADDR_WIDTH-1:0] COMP_BASE_LO        = 'h001c;
  localparam logic [REG_ADDR_WIDTH-1:0] COMP_BASE_HI        = 'h0020;
  localparam logic [REG_ADDR_WIDTH-1:0] COMP_HEAD           = 'h0024;
  localparam logic [REG_ADDR_WIDTH-1:0] COMP_TAIL           = 'h0028;
  localparam logic [REG_ADDR_WIDTH-1:0] COMP_RING_SIZE      = 'h002c;
  localparam logic [REG_ADDR_WIDTH-1:0] IRQ_ENABLE          = 'h0030;
  localparam logic [REG_ADDR_WIDTH-1:0] IRQ_STATUS          = 'h0034;
  localparam logic [REG_ADDR_WIDTH-1:0] ERROR_STATUS        = 'h0038;
  localparam logic [REG_ADDR_WIDTH-1:0] CONFIG              = 'h003c;
  localparam logic [REG_ADDR_WIDTH-1:0] MAX_BURST_LEN_REG   = 'h0040;
  localparam logic [REG_ADDR_WIDTH-1:0] PERF_DESC_FETCH_CNT = 'h0044;
  localparam logic [REG_ADDR_WIDTH-1:0] PERF_READ_BEATS     = 'h0048;
  localparam logic [REG_ADDR_WIDTH-1:0] PERF_WRITE_BEATS    = 'h004c;

  // Inactive scaffold from an earlier descriptor-ring register map. The active
  // build uses axi_lite_regs.sv and the register map in docs/register_map.md.

  always_comb begin
    reg_req_ready     = 1'b0;
    reg_rsp_valid     = 1'b0;
    reg_rsp_rdata     = '0;
    reg_rsp_resp      = 2'b00;

    dma_enable_o      = 1'b0;
    irq_enable_o      = 1'b0;
    desc_base_addr_o  = '0;
    desc_head_o       = '0;
    desc_tail_o       = '0;
    desc_ring_size_o  = '0;
    comp_base_addr_o  = '0;
    comp_head_o       = '0;
    comp_tail_o       = '0;
    comp_ring_size_o  = '0;
    max_burst_len_o   = dma_pkg::MAX_BURST_LEN;
  end

endmodule
