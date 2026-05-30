`timescale 1ns/1ps

module data_fifo #(
  parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
  parameter int DEPTH      = dma_pkg::FIFO_DEPTH
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  push_valid,
  output logic                  push_ready,
  input  logic [DATA_WIDTH-1:0] push_data,
  output logic                  pop_valid,
  input  logic                  pop_ready,
  output logic [DATA_WIDTH-1:0] pop_data,
  output logic                  full,
  output logic                  empty
);

  // Placeholder FIFO shell. Real storage, occupancy tracking, and backpressure
  // handling will land in a later phase once the datapath behavior is defined.
  // TODO: Add assertions for no overflow, no underflow, and ordering.

  always_comb begin
    push_ready = 1'b0;
    pop_valid  = 1'b0;
    pop_data   = '0;
    full       = 1'b0;
    empty      = 1'b1;
  end

endmodule
