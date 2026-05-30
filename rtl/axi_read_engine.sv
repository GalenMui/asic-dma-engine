`timescale 1ns/1ps

module axi_read_engine #(
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
  output logic                        data_valid,
  input  logic                        data_ready,
  output logic [DATA_WIDTH-1:0]       data_out,
  output logic                        data_last,
  output logic [1:0]                  data_resp,
  output logic                        alloc_valid,
  input  logic                        alloc_ready,
  output dma_pkg::outstanding_entry_t alloc_entry,
  output logic [ID_WIDTH-1:0]         m_axi_arid,
  output logic [ADDR_WIDTH-1:0]       m_axi_araddr,
  output logic [7:0]                  m_axi_arlen,
  output logic [2:0]                  m_axi_arsize,
  output logic [1:0]                  m_axi_arburst,
  output logic                        m_axi_arvalid,
  input  logic                        m_axi_arready,
  input  logic [ID_WIDTH-1:0]         m_axi_rid,
  input  logic [DATA_WIDTH-1:0]       m_axi_rdata,
  input  logic [1:0]                  m_axi_rresp,
  input  logic                        m_axi_rlast,
  input  logic                        m_axi_rvalid,
  output logic                        m_axi_rready
);

  localparam logic [2:0] AXI_SIZE_BYTES = $clog2(DATA_WIDTH / 8);

  // Future role: turn internal read commands into constrained AXI4 INCR bursts
  // and stream returned data into the FIFO path.
  // TODO: Generate aligned AR bursts only.
  // TODO: Validate RRESP, RLAST, beat counts, and outstanding allocations.

  always_comb begin
    cmd_ready    = 1'b0;
    data_valid   = 1'b0;
    data_out     = '0;
    data_last    = 1'b0;
    data_resp    = 2'b00;
    alloc_valid  = 1'b0;
    alloc_entry  = '0;

    m_axi_arid    = '0;
    m_axi_araddr  = '0;
    m_axi_arlen   = '0;
    m_axi_arsize  = AXI_SIZE_BYTES;
    m_axi_arburst = 2'b01;
    m_axi_arvalid = 1'b0;
    m_axi_rready  = 1'b0;
  end

endmodule
