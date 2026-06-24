`timescale 1ns/1ps

module cdc_toggle_sync (
  input  logic src_clk,
  input  logic src_rst_n,
  input  logic src_toggle,
  input  logic dst_clk,
  input  logic dst_rst_n,
  output logic dst_toggle,
  output logic dst_pulse
);

  // move an infrequent event across clocks as a level, then spot the change

  logic sync_ff1;
  logic sync_ff2;
  logic sync_ff2_d;

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      sync_ff1  <= 1'b0;
      sync_ff2  <= 1'b0;
      sync_ff2_d <= 1'b0;
    end else begin
      sync_ff1   <= src_toggle; // first flop can take the metastability hit
      sync_ff2   <= sync_ff1;   // second flop is the clean destination copy
      sync_ff2_d <= sync_ff2;   // delayed copy lets us turn the change into a pulse
    end
  end

  assign dst_toggle = sync_ff2;
  assign dst_pulse  = sync_ff2 ^ sync_ff2_d; // high for one dst clock on either toggle edge

endmodule
