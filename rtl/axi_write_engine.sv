`timescale 1ns/1ps

module axi_write_engine #(
  parameter int ADDR_WIDTH    = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH    = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH      = dma_pkg::ID_WIDTH,
  parameter int MAX_BURST_LEN = dma_pkg::MAX_BURST_LEN
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic                        cmd_valid,
  output logic                        cmd_ready,
  input  dma_pkg::dma_cmd_t           cmd,
  input  logic                        data_valid,
  output logic                        data_ready,
  input  logic [DATA_WIDTH-1:0]       data_in,
  input  logic                        data_last,
  output logic                        write_done_valid,
  input  logic                        write_done_ready,
  output logic [1:0]                  write_resp,
  output logic                        alloc_valid,
  input  logic                        alloc_ready,
  output dma_pkg::outstanding_entry_t alloc_entry,
  output logic [ID_WIDTH-1:0]         m_axi_awid,
  output logic [ADDR_WIDTH-1:0]       m_axi_awaddr,
  output logic [7:0]                  m_axi_awlen,
  output logic [2:0]                  m_axi_awsize,
  output logic [1:0]                  m_axi_awburst,
  output logic                        m_axi_awvalid,
  input  logic                        m_axi_awready,
  output logic [DATA_WIDTH-1:0]       m_axi_wdata,
  output logic [(DATA_WIDTH/8)-1:0]   m_axi_wstrb,
  output logic                        m_axi_wlast,
  output logic                        m_axi_wvalid,
  input  logic                        m_axi_wready,
  input  logic [ID_WIDTH-1:0]         m_axi_bid,
  input  logic [1:0]                  m_axi_bresp,
  input  logic                        m_axi_bvalid,
  output logic                        m_axi_bready
);

  localparam logic [2:0] AXI_SIZE_BYTES = $clog2(DATA_WIDTH / 8);

  // Inactive scaffold from an earlier split datapath. The active AXI write
  // behavior is integrated in dma_core.sv.

  always_comb begin
    cmd_ready        = 1'b0;
    data_ready       = 1'b0;
    write_done_valid = 1'b0;
    write_resp       = 2'b00;
    alloc_valid      = 1'b0;
    alloc_entry      = '0;

    m_axi_awid    = '0;
    m_axi_awaddr  = '0;
    m_axi_awlen   = '0;
    m_axi_awsize  = AXI_SIZE_BYTES;
    m_axi_awburst = 2'b01;
    m_axi_awvalid = 1'b0;
    m_axi_wdata   = '0;
    m_axi_wstrb   = '0;
    m_axi_wlast   = 1'b0;
    m_axi_wvalid  = 1'b0;
    m_axi_bready  = 1'b0;
  end

endmodule
