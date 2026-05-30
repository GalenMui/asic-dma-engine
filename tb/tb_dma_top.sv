`timescale 1ns/1ps

module tb_dma_top;

  localparam int AXIL_ADDR_WIDTH = 16;
  localparam int AXIL_DATA_WIDTH = 32;
  localparam int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH;
  localparam int DATA_WIDTH      = dma_pkg::DATA_WIDTH;
  localparam int ID_WIDTH        = dma_pkg::ID_WIDTH;

  logic                       cfg_clk;
  logic                       cfg_rst_n;
  logic                       dma_clk;
  logic                       dma_rst_n;

  logic                       s_axil_awvalid;
  logic                       s_axil_awready;
  logic [AXIL_ADDR_WIDTH-1:0] s_axil_awaddr;
  logic [2:0]                 s_axil_awprot;
  logic                       s_axil_wvalid;
  logic                       s_axil_wready;
  logic [AXIL_DATA_WIDTH-1:0] s_axil_wdata;
  logic [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb;
  logic                       s_axil_bvalid;
  logic                       s_axil_bready;
  logic [1:0]                 s_axil_bresp;
  logic                       s_axil_arvalid;
  logic                       s_axil_arready;
  logic [AXIL_ADDR_WIDTH-1:0] s_axil_araddr;
  logic [2:0]                 s_axil_arprot;
  logic                       s_axil_rvalid;
  logic                       s_axil_rready;
  logic [AXIL_DATA_WIDTH-1:0] s_axil_rdata;
  logic [1:0]                 s_axil_rresp;

  logic [ID_WIDTH-1:0]        m_axi_awid;
  logic [ADDR_WIDTH-1:0]      m_axi_awaddr;
  logic [7:0]                 m_axi_awlen;
  logic [2:0]                 m_axi_awsize;
  logic [1:0]                 m_axi_awburst;
  logic                       m_axi_awvalid;
  logic                       m_axi_awready;
  logic [DATA_WIDTH-1:0]      m_axi_wdata;
  logic [(DATA_WIDTH/8)-1:0]  m_axi_wstrb;
  logic                       m_axi_wlast;
  logic                       m_axi_wvalid;
  logic                       m_axi_wready;
  logic [ID_WIDTH-1:0]        m_axi_bid;
  logic [1:0]                 m_axi_bresp;
  logic                       m_axi_bvalid;
  logic                       m_axi_bready;
  logic [ID_WIDTH-1:0]        m_axi_arid;
  logic [ADDR_WIDTH-1:0]      m_axi_araddr;
  logic [7:0]                 m_axi_arlen;
  logic [2:0]                 m_axi_arsize;
  logic [1:0]                 m_axi_arburst;
  logic                       m_axi_arvalid;
  logic                       m_axi_arready;
  logic [ID_WIDTH-1:0]        m_axi_rid;
  logic [DATA_WIDTH-1:0]      m_axi_rdata;
  logic [1:0]                 m_axi_rresp;
  logic                       m_axi_rlast;
  logic                       m_axi_rvalid;
  logic                       m_axi_rready;
  logic                       irq;

  always #10 cfg_clk = ~cfg_clk;
  always #2.5 dma_clk = ~dma_clk;

  initial begin
    cfg_clk        = 1'b0;
    cfg_rst_n      = 1'b0;
    dma_clk        = 1'b0;
    dma_rst_n      = 1'b0;
    s_axil_awvalid = 1'b0;
    s_axil_awaddr  = '0;
    s_axil_awprot  = '0;
    s_axil_wvalid  = 1'b0;
    s_axil_wdata   = '0;
    s_axil_wstrb   = '0;
    s_axil_bready  = 1'b0;
    s_axil_arvalid = 1'b0;
    s_axil_araddr  = '0;
    s_axil_arprot  = '0;
    s_axil_rready  = 1'b0;
    m_axi_awready  = 1'b0;
    m_axi_wready   = 1'b0;
    m_axi_bid      = '0;
    m_axi_bresp    = '0;
    m_axi_bvalid   = 1'b0;
    m_axi_arready  = 1'b0;
    m_axi_rid      = '0;
    m_axi_rdata    = '0;
    m_axi_rresp    = '0;
    m_axi_rlast    = 1'b0;
    m_axi_rvalid   = 1'b0;

    repeat (5) @(posedge cfg_clk);
    cfg_rst_n <= 1'b1;
    repeat (5) @(posedge dma_clk);
    dma_rst_n <= 1'b1;
  end

  initial begin
    // TODO: Add directed register programming and descriptor submission flows.
    // TODO: Hook up the future AXI-Lite driver, memory model, scoreboard, and
    // assertions once functional behavior exists.
    repeat (50) @(posedge cfg_clk);
    $finish;
  end

  dma_top #(
    .AXIL_ADDR_WIDTH (AXIL_ADDR_WIDTH),
    .AXIL_DATA_WIDTH (AXIL_DATA_WIDTH),
    .ADDR_WIDTH      (ADDR_WIDTH),
    .DATA_WIDTH      (DATA_WIDTH),
    .ID_WIDTH        (ID_WIDTH)
  ) dut (
    .cfg_clk         (cfg_clk),
    .cfg_rst_n       (cfg_rst_n),
    .dma_clk         (dma_clk),
    .dma_rst_n       (dma_rst_n),
    .s_axil_awvalid  (s_axil_awvalid),
    .s_axil_awready  (s_axil_awready),
    .s_axil_awaddr   (s_axil_awaddr),
    .s_axil_awprot   (s_axil_awprot),
    .s_axil_wvalid   (s_axil_wvalid),
    .s_axil_wready   (s_axil_wready),
    .s_axil_wdata    (s_axil_wdata),
    .s_axil_wstrb    (s_axil_wstrb),
    .s_axil_bvalid   (s_axil_bvalid),
    .s_axil_bready   (s_axil_bready),
    .s_axil_bresp    (s_axil_bresp),
    .s_axil_arvalid  (s_axil_arvalid),
    .s_axil_arready  (s_axil_arready),
    .s_axil_araddr   (s_axil_araddr),
    .s_axil_arprot   (s_axil_arprot),
    .s_axil_rvalid   (s_axil_rvalid),
    .s_axil_rready   (s_axil_rready),
    .s_axil_rdata    (s_axil_rdata),
    .s_axil_rresp    (s_axil_rresp),
    .m_axi_awid      (m_axi_awid),
    .m_axi_awaddr    (m_axi_awaddr),
    .m_axi_awlen     (m_axi_awlen),
    .m_axi_awsize    (m_axi_awsize),
    .m_axi_awburst   (m_axi_awburst),
    .m_axi_awvalid   (m_axi_awvalid),
    .m_axi_awready   (m_axi_awready),
    .m_axi_wdata     (m_axi_wdata),
    .m_axi_wstrb     (m_axi_wstrb),
    .m_axi_wlast     (m_axi_wlast),
    .m_axi_wvalid    (m_axi_wvalid),
    .m_axi_wready    (m_axi_wready),
    .m_axi_bid       (m_axi_bid),
    .m_axi_bresp     (m_axi_bresp),
    .m_axi_bvalid    (m_axi_bvalid),
    .m_axi_bready    (m_axi_bready),
    .m_axi_arid      (m_axi_arid),
    .m_axi_araddr    (m_axi_araddr),
    .m_axi_arlen     (m_axi_arlen),
    .m_axi_arsize    (m_axi_arsize),
    .m_axi_arburst   (m_axi_arburst),
    .m_axi_arvalid   (m_axi_arvalid),
    .m_axi_arready   (m_axi_arready),
    .m_axi_rid       (m_axi_rid),
    .m_axi_rdata     (m_axi_rdata),
    .m_axi_rresp     (m_axi_rresp),
    .m_axi_rlast     (m_axi_rlast),
    .m_axi_rvalid    (m_axi_rvalid),
    .m_axi_rready    (m_axi_rready),
    .irq             (irq)
  );

endmodule
