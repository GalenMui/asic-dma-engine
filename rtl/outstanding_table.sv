`timescale 1ns/1ps

module outstanding_table #(
  parameter int ID_WIDTH = dma_pkg::ID_WIDTH,
  parameter int DEPTH    = dma_pkg::OUTSTANDING_DEPTH
) (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  clear_i,

  input  logic                  alloc_valid,
  output logic                  alloc_ready,
  input  logic [ID_WIDTH-1:0]   alloc_axi_id,
  input  logic [1:0]            alloc_txn_type,
  input  logic [15:0]           alloc_desc_id,
  input  logic [15:0]           alloc_expected_beats,
  output logic                  alloc_error,

  input  logic                  lookup_valid,
  input  logic [ID_WIDTH-1:0]   lookup_id,
  output logic                  lookup_hit,
  output logic [1:0]            lookup_txn_type,
  output logic [15:0]           lookup_desc_id,
  output logic [15:0]           lookup_expected_beats,

  input  logic                  retire_valid,
  input  logic [ID_WIDTH-1:0]   retire_id,
  output logic                  retire_error,

  output logic                  full,
  output logic                  empty
);

  localparam int IDX_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int COUNT_WIDTH = $clog2(DEPTH + 1);

  logic [DEPTH-1:0]           valid_q;
  logic [ID_WIDTH-1:0]        axi_id_q [DEPTH];
  logic [1:0]                 txn_type_q [DEPTH];
  logic [15:0]                desc_id_q [DEPTH];
  logic [15:0]                expected_beats_q [DEPTH];
  logic [DEPTH-1:0]           match_alloc_id;
  logic [IDX_WIDTH-1:0]       alloc_index;
  logic [IDX_WIDTH-1:0]       lookup_index;
  logic [IDX_WIDTH-1:0]       retire_index;
  logic                       alloc_found_empty;
  logic                       lookup_found;
  logic                       retire_found;
  logic [COUNT_WIDTH-1:0]     valid_count;

  always_comb begin
    match_alloc_id = '0;
    alloc_index = '0;
    lookup_index = '0;
    retire_index = '0;
    alloc_found_empty = 1'b0;
    lookup_found = 1'b0;
    retire_found = 1'b0;
    valid_count = '0;
    lookup_txn_type = '0;
    lookup_desc_id = '0;
    lookup_expected_beats = '0;

    for (int idx = 0; idx < DEPTH; idx++) begin
      if (valid_q[idx]) begin
        valid_count = valid_count + 1'b1;
      end

      if (!valid_q[idx] && !alloc_found_empty) begin
        alloc_found_empty = 1'b1;
        alloc_index = idx[IDX_WIDTH-1:0];
      end

      if (valid_q[idx] && (axi_id_q[idx] == alloc_axi_id)) begin
        match_alloc_id[idx] = 1'b1;
      end

      if (valid_q[idx] && (axi_id_q[idx] == lookup_id) && !lookup_found) begin
        lookup_found = 1'b1;
        lookup_index = idx[IDX_WIDTH-1:0];
      end

      if (valid_q[idx] && (axi_id_q[idx] == retire_id) && !retire_found) begin
        retire_found = 1'b1;
        retire_index = idx[IDX_WIDTH-1:0];
      end
    end

    if (lookup_found) begin
      lookup_txn_type = txn_type_q[lookup_index];
      lookup_desc_id = desc_id_q[lookup_index];
      lookup_expected_beats = expected_beats_q[lookup_index];
    end

    alloc_ready = alloc_found_empty && !(|match_alloc_id);
    lookup_hit = lookup_valid && lookup_found;
    full = (valid_count == COUNT_WIDTH'(DEPTH));
    empty = (valid_count == '0);
  end

  assign alloc_error = alloc_valid && !alloc_ready;
  assign retire_error = retire_valid && !retire_found;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int idx = 0; idx < DEPTH; idx++) begin
        valid_q[idx] <= 1'b0;
        axi_id_q[idx] <= '0;
        txn_type_q[idx] <= '0;
        desc_id_q[idx] <= '0;
        expected_beats_q[idx] <= '0;
      end
    end else if (clear_i) begin
      for (int idx = 0; idx < DEPTH; idx++) begin
        valid_q[idx] <= 1'b0;
        axi_id_q[idx] <= '0;
        txn_type_q[idx] <= '0;
        desc_id_q[idx] <= '0;
        expected_beats_q[idx] <= '0;
      end
    end else begin
      if (retire_valid && retire_found) begin
        valid_q[retire_index] <= 1'b0;
        axi_id_q[retire_index] <= '0;
        txn_type_q[retire_index] <= '0;
        desc_id_q[retire_index] <= '0;
        expected_beats_q[retire_index] <= '0;
      end

      if (alloc_valid && alloc_ready) begin
        valid_q[alloc_index] <= 1'b1;
        axi_id_q[alloc_index] <= alloc_axi_id;
        txn_type_q[alloc_index] <= alloc_txn_type;
        desc_id_q[alloc_index] <= alloc_desc_id;
        expected_beats_q[alloc_index] <= alloc_expected_beats;
      end
    end
  end

endmodule
