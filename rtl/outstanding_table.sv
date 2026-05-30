`timescale 1ns/1ps

module outstanding_table #(
  parameter int ID_WIDTH = dma_pkg::ID_WIDTH,
  parameter int DEPTH    = dma_pkg::OUTSTANDING_DEPTH
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic                        alloc_valid,
  output logic                        alloc_ready,
  input  dma_pkg::outstanding_entry_t alloc_entry,
  input  logic                        lookup_valid,
  input  logic [ID_WIDTH-1:0]         lookup_id,
  output logic                        lookup_hit,
  output dma_pkg::outstanding_entry_t lookup_entry,
  input  logic                        retire_valid,
  input  logic [ID_WIDTH-1:0]         retire_id,
  output logic                        full,
  output logic                        empty
);

  // Future role: remember in-flight AXI activity and allow responses to be
  // matched back to descriptor state.
  // TODO: Track valid entries, AXI IDs, transaction type, descriptor ID,
  // expected beats, received beats, error state, allocation, lookup, and free.

  always_comb begin
    alloc_ready  = 1'b0;
    lookup_hit   = 1'b0;
    lookup_entry = '0;
    full         = 1'b0;
    empty        = 1'b1;
  end

endmodule
