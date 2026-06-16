`timescale 1ns/1ps

module descriptor_decode (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  desc_in_valid,
  output logic                  desc_in_ready,
  input  dma_pkg::descriptor_t  desc_in,
  output logic                  cmd_out_valid,
  input  logic                  cmd_out_ready,
  output dma_pkg::dma_cmd_t     cmd_out,
  output logic                  decode_error
);

  import dma_pkg::*;

  // Inactive scaffold from an earlier modular descriptor pipeline. The active
  // descriptor decode checks are integrated in dma_core.sv.

  always_comb begin
    desc_in_ready = 1'b0;
    cmd_out_valid = 1'b0;
    cmd_out       = '0;
    cmd_out.txn_type = TXN_TYPE_SOURCE_READ;
    decode_error  = 1'b0;
  end

endmodule
