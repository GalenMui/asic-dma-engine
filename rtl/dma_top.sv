`timescale 1ns/1ps

module dma_top #(
  parameter int AXIL_ADDR_WIDTH = 32,
  parameter int AXIL_DATA_WIDTH = 32,
  parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH        = dma_pkg::ID_WIDTH
) (
  input  logic                          clk,
  input  logic                          rst_n,

  input  logic [AXIL_ADDR_WIDTH-1:0]    s_axil_awaddr,
  input  logic [2:0]                    s_axil_awprot,
  input  logic                          s_axil_awvalid,
  output logic                          s_axil_awready,
  input  logic [AXIL_DATA_WIDTH-1:0]    s_axil_wdata,
  input  logic [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb,
  input  logic                          s_axil_wvalid,
  output logic                          s_axil_wready,
  output logic [1:0]                    s_axil_bresp,
  output logic                          s_axil_bvalid,
  input  logic                          s_axil_bready,
  input  logic [AXIL_ADDR_WIDTH-1:0]    s_axil_araddr,
  input  logic [2:0]                    s_axil_arprot,
  input  logic                          s_axil_arvalid,
  output logic                          s_axil_arready,
  output logic [AXIL_DATA_WIDTH-1:0]    s_axil_rdata,
  output logic [1:0]                    s_axil_rresp,
  output logic                          s_axil_rvalid,
  input  logic                          s_axil_rready,

  output logic [ID_WIDTH-1:0]           m_axi_awid,
  output logic [ADDR_WIDTH-1:0]         m_axi_awaddr,
  output logic [7:0]                    m_axi_awlen,
  output logic [2:0]                    m_axi_awsize,
  output logic [1:0]                    m_axi_awburst,
  output logic                          m_axi_awvalid,
  input  logic                          m_axi_awready,
  output logic [DATA_WIDTH-1:0]         m_axi_wdata,
  output logic [(DATA_WIDTH/8)-1:0]     m_axi_wstrb,
  output logic                          m_axi_wlast,
  output logic                          m_axi_wvalid,
  input  logic                          m_axi_wready,
  input  logic [ID_WIDTH-1:0]           m_axi_bid,
  input  logic [1:0]                    m_axi_bresp,
  input  logic                          m_axi_bvalid,
  output logic                          m_axi_bready,

  output logic [ID_WIDTH-1:0]           m_axi_arid,
  output logic [ADDR_WIDTH-1:0]         m_axi_araddr,
  output logic [7:0]                    m_axi_arlen,
  output logic [2:0]                    m_axi_arsize,
  output logic [1:0]                    m_axi_arburst,
  output logic                          m_axi_arvalid,
  input  logic                          m_axi_arready,
  input  logic [ID_WIDTH-1:0]           m_axi_rid,
  input  logic [DATA_WIDTH-1:0]         m_axi_rdata,
  input  logic [1:0]                    m_axi_rresp,
  input  logic                          m_axi_rlast,
  input  logic                          m_axi_rvalid,
  output logic                          m_axi_rready,

  output logic                          irq
);

  logic                      start_pulse;
  logic                      soft_reset_pulse;
  logic [ADDR_WIDTH-1:0]     src_addr;
  logic [ADDR_WIDTH-1:0]     dst_addr;
  logic [31:0]               len_bytes;
  logic [1:0]                irq_enable;
  logic                      dma_busy;
  logic                      dma_done_pulse;
  logic                      dma_error_pulse;

  axi_lite_regs #(
    .REG_ADDR_WIDTH (AXIL_ADDR_WIDTH),
    .REG_DATA_WIDTH (AXIL_DATA_WIDTH),
    .ADDR_WIDTH     (ADDR_WIDTH)
  ) u_axi_lite_regs (
    .clk                (clk),
    .rst_n              (rst_n),
    .s_axil_awaddr      (s_axil_awaddr),
    .s_axil_awprot      (s_axil_awprot),
    .s_axil_awvalid     (s_axil_awvalid),
    .s_axil_awready     (s_axil_awready),
    .s_axil_wdata       (s_axil_wdata),
    .s_axil_wstrb       (s_axil_wstrb),
    .s_axil_wvalid      (s_axil_wvalid),
    .s_axil_wready      (s_axil_wready),
    .s_axil_bresp       (s_axil_bresp),
    .s_axil_bvalid      (s_axil_bvalid),
    .s_axil_bready      (s_axil_bready),
    .s_axil_araddr      (s_axil_araddr),
    .s_axil_arprot      (s_axil_arprot),
    .s_axil_arvalid     (s_axil_arvalid),
    .s_axil_arready     (s_axil_arready),
    .s_axil_rdata       (s_axil_rdata),
    .s_axil_rresp       (s_axil_rresp),
    .s_axil_rvalid      (s_axil_rvalid),
    .s_axil_rready      (s_axil_rready),
    .busy_i             (dma_busy),
    .done_set_i         (dma_done_pulse),
    .error_set_i        (dma_error_pulse),
    .start_pulse_o      (start_pulse),
    .soft_reset_pulse_o (soft_reset_pulse),
    .src_addr_o         (src_addr),
    .dst_addr_o         (dst_addr),
    .len_bytes_o        (len_bytes),
    .irq_enable_o       (irq_enable),
    .irq_o              (irq)
  );

  dma_core #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .ID_WIDTH   (ID_WIDTH)
  ) u_dma_core (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_i        (start_pulse),
    .soft_reset_i   (soft_reset_pulse),
    .src_addr_i     (src_addr),
    .dst_addr_i     (dst_addr),
    .len_bytes_i    (len_bytes),
    .busy_o         (dma_busy),
    .done_pulse_o   (dma_done_pulse),
    .error_pulse_o  (dma_error_pulse),
    .m_axi_awid     (m_axi_awid),
    .m_axi_awaddr   (m_axi_awaddr),
    .m_axi_awlen    (m_axi_awlen),
    .m_axi_awsize   (m_axi_awsize),
    .m_axi_awburst  (m_axi_awburst),
    .m_axi_awvalid  (m_axi_awvalid),
    .m_axi_awready  (m_axi_awready),
    .m_axi_wdata    (m_axi_wdata),
    .m_axi_wstrb    (m_axi_wstrb),
    .m_axi_wlast    (m_axi_wlast),
    .m_axi_wvalid   (m_axi_wvalid),
    .m_axi_wready   (m_axi_wready),
    .m_axi_bid      (m_axi_bid),
    .m_axi_bresp    (m_axi_bresp),
    .m_axi_bvalid   (m_axi_bvalid),
    .m_axi_bready   (m_axi_bready),
    .m_axi_arid     (m_axi_arid),
    .m_axi_araddr   (m_axi_araddr),
    .m_axi_arlen    (m_axi_arlen),
    .m_axi_arsize   (m_axi_arsize),
    .m_axi_arburst  (m_axi_arburst),
    .m_axi_arvalid  (m_axi_arvalid),
    .m_axi_arready  (m_axi_arready),
    .m_axi_rid      (m_axi_rid),
    .m_axi_rdata    (m_axi_rdata),
    .m_axi_rresp    (m_axi_rresp),
    .m_axi_rlast    (m_axi_rlast),
    .m_axi_rvalid   (m_axi_rvalid),
    .m_axi_rready   (m_axi_rready)
  );

endmodule
