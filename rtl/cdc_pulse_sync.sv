`timescale 1ns/1ps

module cdc_pulse_sync (
  input  logic src_clk,
  input  logic src_rst_n,
  input  logic src_pulse,
  input  logic dst_clk,
  input  logic dst_rst_n,
  output logic dst_pulse
);

  // stretch the meaning of a pulse into a toggle so a slower clock cannot miss it

  logic src_toggle;
  logic dst_toggle;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      src_toggle <= 1'b0;
    end else if (src_pulse) begin
      src_toggle <= ~src_toggle; // every source pulse becomes one visible state change
    end
  end

  // the shared toggle helper handles the synchronizer and destination edge detect
  cdc_toggle_sync u_cdc_toggle_sync (
    .src_clk    (src_clk),
    .src_rst_n  (src_rst_n),
    .src_toggle (src_toggle),
    .dst_clk    (dst_clk),
    .dst_rst_n  (dst_rst_n),
    .dst_toggle (dst_toggle),
    .dst_pulse  (dst_pulse)
  );

endmodule
