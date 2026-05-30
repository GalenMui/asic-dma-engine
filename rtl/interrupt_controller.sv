`timescale 1ns/1ps

module interrupt_controller (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       irq_enable,
  input  logic       completion_event,
  input  logic       error_event,
  input  logic       queue_event,
  input  logic       clear_irq_status,
  output logic       irq,
  output logic [2:0] irq_status
);

  // This shell currently provides a simple combinational view of incoming
  // events. Real sticky pending bits and clear-on-write behavior come later.
  // TODO: Wire IRQ_ENABLE and IRQ_STATUS from the register block.

  always_comb begin
    irq_status = {queue_event, error_event, completion_event};
    irq        = irq_enable && (|irq_status);
  end

endmodule
