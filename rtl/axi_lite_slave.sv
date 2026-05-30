`timescale 1ns/1ps

module axi_lite_slave #(
  parameter int ADDR_WIDTH = 16,
  parameter int DATA_WIDTH = 32
) (
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic                    s_axil_awvalid,
  output logic                    s_axil_awready,
  input  logic [ADDR_WIDTH-1:0]   s_axil_awaddr,
  input  logic [2:0]              s_axil_awprot,
  input  logic                    s_axil_wvalid,
  output logic                    s_axil_wready,
  input  logic [DATA_WIDTH-1:0]   s_axil_wdata,
  input  logic [(DATA_WIDTH/8)-1:0] s_axil_wstrb,
  output logic                    s_axil_bvalid,
  input  logic                    s_axil_bready,
  output logic [1:0]              s_axil_bresp,
  input  logic                    s_axil_arvalid,
  output logic                    s_axil_arready,
  input  logic [ADDR_WIDTH-1:0]   s_axil_araddr,
  input  logic [2:0]              s_axil_arprot,
  output logic                    s_axil_rvalid,
  input  logic                    s_axil_rready,
  output logic [DATA_WIDTH-1:0]   s_axil_rdata,
  output logic [1:0]              s_axil_rresp,

  output logic                    reg_req_valid,
  input  logic                    reg_req_ready,
  output logic                    reg_req_write,
  output logic [ADDR_WIDTH-1:0]   reg_req_addr,
  output logic [DATA_WIDTH-1:0]   reg_req_wdata,
  output logic [(DATA_WIDTH/8)-1:0] reg_req_wstrb,
  input  logic                    reg_rsp_valid,
  output logic                    reg_rsp_ready,
  input  logic [DATA_WIDTH-1:0]   reg_rsp_rdata,
  input  logic [1:0]              reg_rsp_resp
);

  // This block will eventually bridge AXI4-Lite software accesses onto the
  // internal register request/response channel consumed by dma_regs.
  // TODO: Handle AW and W independently, buffer them as needed, and only emit
  // a write request once both halves of the transaction are available.
  // TODO: Support backpressure cleanly on read and write responses.

  always_comb begin
    s_axil_awready = 1'b0;
    s_axil_wready  = 1'b0;
    s_axil_bvalid  = 1'b0;
    s_axil_bresp   = 2'b00;
    s_axil_arready = 1'b0;
    s_axil_rvalid  = 1'b0;
    s_axil_rdata   = '0;
    s_axil_rresp   = 2'b00;

    reg_req_valid  = 1'b0;
    reg_req_write  = 1'b0;
    reg_req_addr   = '0;
    reg_req_wdata  = '0;
    reg_req_wstrb  = '0;
    reg_rsp_ready  = 1'b0;
  end

endmodule
