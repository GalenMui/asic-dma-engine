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

  // Move infrequent state changes from one clock domain into another by
  // synchronizing a toggle and edge-detecting it at the sink.

  logic sync_ff1;
  logic sync_ff2;
  logic sync_ff2_d;

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      sync_ff1  <= 1'b0;
      sync_ff2  <= 1'b0;
      sync_ff2_d <= 1'b0;
    end else begin
      sync_ff1  <= src_toggle;
      sync_ff2  <= sync_ff1;
      sync_ff2_d <= sync_ff2;
    end
  end

  assign dst_toggle = sync_ff2;
  assign dst_pulse  = sync_ff2 ^ sync_ff2_d;

endmodule
