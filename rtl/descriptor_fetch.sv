`timescale 1ns/1ps

module descriptor_fetch #(
  parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH
) (
  input  logic                     clk,
  input  logic                     rst_n,
  input  logic                     fetch_req_valid,
  output logic                     fetch_req_ready,
  input  logic [ADDR_WIDTH-1:0]    fetch_req_addr,
  output logic                     read_cmd_valid,
  input  logic                     read_cmd_ready,
  output dma_pkg::dma_cmd_t        read_cmd,
  input  logic                     read_rsp_valid,
  output logic                     read_rsp_ready,
  input  logic [DATA_WIDTH-1:0]    read_rsp_data,
  input  logic                     read_rsp_last,
  input  logic [1:0]               read_rsp_resp,
  output logic                     desc_valid,
  input  logic                     desc_ready,
  output dma_pkg::descriptor_t     desc_out,
  output logic                     desc_error
);

  import dma_pkg::*;

  // Inactive scaffold from an earlier modular descriptor pipeline. The active
  // descriptor fetch path is integrated in dma_core.sv.

  always_comb begin
    fetch_req_ready = 1'b0;
    read_cmd_valid  = 1'b0;
    read_cmd        = '0;
    read_cmd.txn_type = TXN_TYPE_DESC_FETCH;
    read_rsp_ready  = 1'b0;
    desc_valid      = 1'b0;
    desc_out        = '0;
    desc_error      = 1'b0;
  end

endmodule
