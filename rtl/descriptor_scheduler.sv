`timescale 1ns/1ps

module descriptor_scheduler (
  input  logic               clk,
  input  logic               rst_n,
  input  logic               cmd_in_valid,
  output logic               cmd_in_ready,
  input  dma_pkg::dma_cmd_t  cmd_in,
  output logic               read_cmd_valid,
  input  logic               read_cmd_ready,
  output dma_pkg::dma_cmd_t  read_cmd,
  output logic               write_cmd_valid,
  input  logic               write_cmd_ready,
  output dma_pkg::dma_cmd_t  write_cmd
);

  import dma_pkg::*;

  // Inactive scaffold from an earlier modular descriptor pipeline. The active
  // sequencing behavior is integrated in dma_core.sv.

  always_comb begin
    cmd_in_ready    = 1'b0;
    read_cmd_valid  = 1'b0;
    read_cmd        = '0;
    write_cmd_valid = 1'b0;
    write_cmd       = '0;
  end

endmodule
