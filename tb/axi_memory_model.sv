`timescale 1ns/1ps

module axi_memory_model #(
  parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH   = dma_pkg::ID_WIDTH
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic [ID_WIDTH-1:0]       s_axi_awid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  logic [7:0]                s_axi_awlen,
  input  logic [2:0]                s_axi_awsize,
  input  logic [1:0]                s_axi_awburst,
  input  logic                      s_axi_awvalid,
  output logic                      s_axi_awready,
  input  logic [DATA_WIDTH-1:0]     s_axi_wdata,
  input  logic [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
  input  logic                      s_axi_wlast,
  input  logic                      s_axi_wvalid,
  output logic                      s_axi_wready,
  output logic [ID_WIDTH-1:0]       s_axi_bid,
  output logic [1:0]                s_axi_bresp,
  output logic                      s_axi_bvalid,
  input  logic                      s_axi_bready,
  input  logic [ID_WIDTH-1:0]       s_axi_arid,
  input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
  input  logic [7:0]                s_axi_arlen,
  input  logic [2:0]                s_axi_arsize,
  input  logic [1:0]                s_axi_arburst,
  input  logic                      s_axi_arvalid,
  output logic                      s_axi_arready,
  output logic [ID_WIDTH-1:0]       s_axi_rid,
  output logic [DATA_WIDTH-1:0]     s_axi_rdata,
  output logic [1:0]                s_axi_rresp,
  output logic                      s_axi_rlast,
  output logic                      s_axi_rvalid,
  input  logic                      s_axi_rready
);

  // Inactive SystemVerilog memory model scaffold. The active behavioral memory
  // model lives in tb/cocotb/test_dma_smoke.py.

  always_comb begin
    s_axi_awready = 1'b0;
    s_axi_wready  = 1'b0;
    s_axi_bid     = '0;
    s_axi_bresp   = 2'b00;
    s_axi_bvalid  = 1'b0;
    s_axi_arready = 1'b0;
    s_axi_rid     = '0;
    s_axi_rdata   = '0;
    s_axi_rresp   = 2'b00;
    s_axi_rlast   = 1'b0;
    s_axi_rvalid  = 1'b0;
  end

endmodule
