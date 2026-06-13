`timescale 1ns/1ps

module cdc_bus_handshake #(
  parameter int WIDTH = 1
) (
  input  logic             src_clk,
  input  logic             src_rst_n,
  input  logic             src_valid,
  output logic             src_ready,
  input  logic [WIDTH-1:0] src_data,

  input  logic             dst_clk,
  input  logic             dst_rst_n,
  output logic             dst_valid_pulse,
  output logic [WIDTH-1:0] dst_data
);

  logic             src_busy_q;
  logic             src_req_toggle_q;
  logic [WIDTH-1:0] src_data_q;
  logic [WIDTH-1:0] dst_data_q;
  logic             dst_req_toggle;
  logic             dst_req_pulse;
  logic             dst_ack_toggle_q;
  logic             src_ack_toggle;
  logic             src_ack_pulse;

  assign src_ready = !src_busy_q;
  assign dst_valid_pulse = dst_req_pulse;
  assign dst_data = dst_data_q;

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      src_busy_q       <= 1'b0;
      src_req_toggle_q <= 1'b0;
      src_data_q       <= '0;
    end else begin
      if (src_ack_pulse) begin
        src_busy_q <= 1'b0;
      end

      if (src_valid && !src_busy_q) begin
        src_data_q       <= src_data;
        src_req_toggle_q <= ~src_req_toggle_q;
        src_busy_q       <= 1'b1;
      end
    end
  end

  cdc_toggle_sync u_req_sync (
    .src_clk    (src_clk),
    .src_rst_n  (src_rst_n),
    .src_toggle (src_req_toggle_q),
    .dst_clk    (dst_clk),
    .dst_rst_n  (dst_rst_n),
    .dst_toggle (dst_req_toggle),
    .dst_pulse  (dst_req_pulse)
  );

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      dst_data_q       <= '0;
      dst_ack_toggle_q <= 1'b0;
    end else if (dst_req_pulse) begin
      dst_data_q       <= src_data_q;
      dst_ack_toggle_q <= ~dst_ack_toggle_q;
    end
  end

  cdc_toggle_sync u_ack_sync (
    .src_clk    (dst_clk),
    .src_rst_n  (dst_rst_n),
    .src_toggle (dst_ack_toggle_q),
    .dst_clk    (src_clk),
    .dst_rst_n  (src_rst_n),
    .dst_toggle (src_ack_toggle),
    .dst_pulse  (src_ack_pulse)
  );

endmodule
