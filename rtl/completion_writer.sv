`timescale 1ns/1ps

module completion_writer #(
  parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  comp_valid,
  output logic                  comp_ready,
  input  dma_pkg::completion_t  comp_in,
  output logic                  write_cmd_valid,
  input  logic                  write_cmd_ready,
  output dma_pkg::dma_cmd_t     write_cmd,
  input  logic                  write_rsp_valid,
  output logic                  write_rsp_ready,
  input  logic [1:0]            write_rsp_resp,
  output logic                  comp_head_advance
);

  import dma_pkg::*;

  // Inactive scaffold from an earlier completion-queue direction. The active
  // design writes descriptor status words directly from dma_core.sv.

  always_comb begin
    comp_ready         = 1'b0;
    write_cmd_valid    = 1'b0;
    write_cmd          = '0;
    write_cmd.txn_type = TXN_TYPE_COMP_WRITE;
    write_rsp_ready    = 1'b0;
    comp_head_advance  = 1'b0;
  end

endmodule
