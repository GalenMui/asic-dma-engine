`timescale 1ns/1ps

module dma_top #(
  parameter int AXIL_ADDR_WIDTH = 16,
  parameter int AXIL_DATA_WIDTH = 32,
  parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH        = dma_pkg::ID_WIDTH
) (
  input  logic                        cfg_clk,
  input  logic                        cfg_rst_n,
  input  logic                        dma_clk,
  input  logic                        dma_rst_n,

  input  logic                        s_axil_awvalid,
  output logic                        s_axil_awready,
  input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_awaddr,
  input  logic [2:0]                  s_axil_awprot,
  input  logic                        s_axil_wvalid,
  output logic                        s_axil_wready,
  input  logic [AXIL_DATA_WIDTH-1:0]  s_axil_wdata,
  input  logic [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb,
  output logic                        s_axil_bvalid,
  input  logic                        s_axil_bready,
  output logic [1:0]                  s_axil_bresp,
  input  logic                        s_axil_arvalid,
  output logic                        s_axil_arready,
  input  logic [AXIL_ADDR_WIDTH-1:0]  s_axil_araddr,
  input  logic [2:0]                  s_axil_arprot,
  output logic                        s_axil_rvalid,
  input  logic                        s_axil_rready,
  output logic [AXIL_DATA_WIDTH-1:0]  s_axil_rdata,
  output logic [1:0]                  s_axil_rresp,

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
  output logic                        m_axi_bready,

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
  output logic                        m_axi_rready,

  output logic                        irq
);

  import dma_pkg::*;

  localparam int AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;

  // AXI-Lite to register-file placeholder channel.
  logic                       reg_req_valid;
  logic                       reg_req_ready;
  logic                       reg_req_write;
  logic [AXIL_ADDR_WIDTH-1:0] reg_req_addr;
  logic [AXIL_DATA_WIDTH-1:0] reg_req_wdata;
  logic [AXIL_STRB_WIDTH-1:0] reg_req_wstrb;
  logic                       reg_rsp_valid;
  logic                       reg_rsp_ready;
  logic [AXIL_DATA_WIDTH-1:0] reg_rsp_rdata;
  logic [1:0]                 reg_rsp_resp;

  // Register outputs for future DMA scheduling and IRQ control.
  logic                       cfg_dma_enable;
  logic                       cfg_irq_enable;
  logic [ADDR_WIDTH-1:0]      cfg_desc_base_addr;
  logic [15:0]                cfg_desc_head;
  logic [15:0]                cfg_desc_tail;
  logic [15:0]                cfg_desc_ring_size;
  logic [ADDR_WIDTH-1:0]      cfg_comp_base_addr;
  logic [15:0]                cfg_comp_head;
  logic [15:0]                cfg_comp_tail;
  logic [15:0]                cfg_comp_ring_size;
  logic [7:0]                 cfg_max_burst_len;

  // Descriptor pipeline scaffolding.
  logic                       desc_fetch_req_valid;
  logic                       desc_fetch_req_ready;
  logic [ADDR_WIDTH-1:0]      desc_fetch_req_addr;
  logic                       desc_fetch_mem_cmd_valid;
  logic                       desc_fetch_mem_cmd_ready;
  dma_cmd_t                   desc_fetch_mem_cmd;
  logic                       desc_fetch_mem_rsp_valid;
  logic                       desc_fetch_mem_rsp_ready;
  logic [DATA_WIDTH-1:0]      desc_fetch_mem_rsp_data;
  logic                       desc_fetch_mem_rsp_last;
  logic [1:0]                 desc_fetch_mem_rsp_resp;
  logic                       fetched_desc_valid;
  logic                       fetched_desc_ready;
  descriptor_t                fetched_desc;
  logic                       desc_fetch_error;

  logic                       decoded_cmd_valid;
  logic                       decoded_cmd_ready;
  dma_cmd_t                   decoded_cmd;
  logic                       desc_decode_error;

  logic                       sched_read_cmd_valid;
  logic                       sched_read_cmd_ready;
  dma_cmd_t                   sched_read_cmd;
  logic                       sched_write_cmd_valid;
  logic                       sched_write_cmd_ready;
  dma_cmd_t                   sched_write_cmd;

  // Read engine, FIFO, and write engine scaffolding.
  logic                       rd_data_valid;
  logic                       rd_data_ready;
  logic [DATA_WIDTH-1:0]      rd_data;
  logic                       rd_data_last;
  logic [1:0]                 rd_data_resp;
  logic                       fifo_push_ready;
  logic                       fifo_pop_valid;
  logic [DATA_WIDTH-1:0]      fifo_pop_data;
  logic                       fifo_full;
  logic                       fifo_empty;
  logic                       wr_data_ready;
  logic                       wr_done_valid;
  logic                       wr_done_ready;
  logic [1:0]                 wr_done_resp;

  // Outstanding tracking placeholder signals.
  logic                       rd_alloc_valid;
  logic                       rd_alloc_ready;
  outstanding_entry_t         rd_alloc_entry;
  logic                       wr_alloc_valid;
  logic                       wr_alloc_ready;
  outstanding_entry_t         wr_alloc_entry;
  logic                       ot_alloc_ready;
  logic                       ot_lookup_valid;
  logic [ID_WIDTH-1:0]        ot_lookup_id;
  logic                       ot_lookup_hit;
  outstanding_entry_t         ot_lookup_entry;
  logic                       ot_retire_valid;
  logic [ID_WIDTH-1:0]        ot_retire_id;
  logic                       ot_full;
  logic                       ot_empty;

  // Completion and interrupt placeholder signals.
  logic                       completion_valid;
  logic                       completion_ready;
  completion_t                completion_entry;
  logic                       completion_cmd_valid;
  logic                       completion_cmd_ready;
  dma_cmd_t                   completion_cmd;
  logic                       completion_rsp_valid;
  logic                       completion_rsp_ready;
  logic [1:0]                 completion_rsp_resp;
  logic                       completion_head_advance;
  logic [2:0]                 irq_status;

  // TODO: Replace these tie-offs with real scheduling and arbitration once the
  // descriptor ring flow and writeback path are implemented.
  assign desc_fetch_req_valid     = 1'b0;
  assign desc_fetch_req_addr      = cfg_desc_base_addr;
  assign desc_fetch_mem_cmd_ready = 1'b0;
  assign desc_fetch_mem_rsp_valid = 1'b0;
  assign desc_fetch_mem_rsp_data  = '0;
  assign desc_fetch_mem_rsp_last  = 1'b0;
  assign desc_fetch_mem_rsp_resp  = '0;
  assign wr_done_ready            = 1'b0;
  assign ot_lookup_valid          = 1'b0;
  assign ot_lookup_id             = '0;
  assign ot_retire_valid          = 1'b0;
  assign ot_retire_id             = '0;
  assign completion_valid         = 1'b0;
  assign completion_entry         = '0;
  assign completion_cmd_ready     = 1'b0;
  assign completion_rsp_valid     = 1'b0;
  assign completion_rsp_resp      = '0;
  assign rd_alloc_ready           = ot_alloc_ready;
  assign wr_alloc_ready           = ot_alloc_ready;

  axi_lite_slave #(
    .ADDR_WIDTH (AXIL_ADDR_WIDTH),
    .DATA_WIDTH (AXIL_DATA_WIDTH)
  ) u_axi_lite_slave (
    .clk            (cfg_clk),
    .rst_n          (cfg_rst_n),
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awready (s_axil_awready),
    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awprot  (s_axil_awprot),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wready  (s_axil_wready),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wstrb   (s_axil_wstrb),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bready  (s_axil_bready),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_arready (s_axil_arready),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arprot  (s_axil_arprot),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rready  (s_axil_rready),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .reg_req_valid  (reg_req_valid),
    .reg_req_ready  (reg_req_ready),
    .reg_req_write  (reg_req_write),
    .reg_req_addr   (reg_req_addr),
    .reg_req_wdata  (reg_req_wdata),
    .reg_req_wstrb  (reg_req_wstrb),
    .reg_rsp_valid  (reg_rsp_valid),
    .reg_rsp_ready  (reg_rsp_ready),
    .reg_rsp_rdata  (reg_rsp_rdata),
    .reg_rsp_resp   (reg_rsp_resp)
  );

  dma_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .REG_ADDR_WIDTH (AXIL_ADDR_WIDTH),
    .REG_DATA_WIDTH (AXIL_DATA_WIDTH)
  ) u_dma_regs (
    .clk              (cfg_clk),
    .rst_n            (cfg_rst_n),
    .reg_req_valid    (reg_req_valid),
    .reg_req_ready    (reg_req_ready),
    .reg_req_write    (reg_req_write),
    .reg_req_addr     (reg_req_addr),
    .reg_req_wdata    (reg_req_wdata),
    .reg_req_wstrb    (reg_req_wstrb),
    .reg_rsp_valid    (reg_rsp_valid),
    .reg_rsp_ready    (reg_rsp_ready),
    .reg_rsp_rdata    (reg_rsp_rdata),
    .reg_rsp_resp     (reg_rsp_resp),
    .dma_busy_i       (1'b0),
    .dma_error_i      (1'b0),
    .dma_enable_o     (cfg_dma_enable),
    .irq_enable_o     (cfg_irq_enable),
    .desc_base_addr_o (cfg_desc_base_addr),
    .desc_head_o      (cfg_desc_head),
    .desc_tail_o      (cfg_desc_tail),
    .desc_ring_size_o (cfg_desc_ring_size),
    .comp_base_addr_o (cfg_comp_base_addr),
    .comp_head_o      (cfg_comp_head),
    .comp_tail_o      (cfg_comp_tail),
    .comp_ring_size_o (cfg_comp_ring_size),
    .max_burst_len_o  (cfg_max_burst_len)
  );

  descriptor_fetch #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH)
  ) u_descriptor_fetch (
    .clk            (dma_clk),
    .rst_n          (dma_rst_n),
    .fetch_req_valid(desc_fetch_req_valid),
    .fetch_req_ready(desc_fetch_req_ready),
    .fetch_req_addr (desc_fetch_req_addr),
    .read_cmd_valid (desc_fetch_mem_cmd_valid),
    .read_cmd_ready (desc_fetch_mem_cmd_ready),
    .read_cmd       (desc_fetch_mem_cmd),
    .read_rsp_valid (desc_fetch_mem_rsp_valid),
    .read_rsp_ready (desc_fetch_mem_rsp_ready),
    .read_rsp_data  (desc_fetch_mem_rsp_data),
    .read_rsp_last  (desc_fetch_mem_rsp_last),
    .read_rsp_resp  (desc_fetch_mem_rsp_resp),
    .desc_valid     (fetched_desc_valid),
    .desc_ready     (fetched_desc_ready),
    .desc_out       (fetched_desc),
    .desc_error     (desc_fetch_error)
  );

  descriptor_decode u_descriptor_decode (
    .clk          (dma_clk),
    .rst_n        (dma_rst_n),
    .desc_in_valid(fetched_desc_valid),
    .desc_in_ready(fetched_desc_ready),
    .desc_in      (fetched_desc),
    .cmd_out_valid(decoded_cmd_valid),
    .cmd_out_ready(decoded_cmd_ready),
    .cmd_out      (decoded_cmd),
    .decode_error (desc_decode_error)
  );

  descriptor_scheduler u_descriptor_scheduler (
    .clk            (dma_clk),
    .rst_n          (dma_rst_n),
    .cmd_in_valid   (decoded_cmd_valid),
    .cmd_in_ready   (decoded_cmd_ready),
    .cmd_in         (decoded_cmd),
    .read_cmd_valid (sched_read_cmd_valid),
    .read_cmd_ready (sched_read_cmd_ready),
    .read_cmd       (sched_read_cmd),
    .write_cmd_valid(sched_write_cmd_valid),
    .write_cmd_ready(sched_write_cmd_ready),
    .write_cmd      (sched_write_cmd)
  );

  axi_read_engine #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .ID_WIDTH      (ID_WIDTH),
    .MAX_BURST_LEN (MAX_BURST_LEN)
  ) u_axi_read_engine (
    .clk          (dma_clk),
    .rst_n        (dma_rst_n),
    .cmd_valid    (sched_read_cmd_valid),
    .cmd_ready    (sched_read_cmd_ready),
    .cmd          (sched_read_cmd),
    .data_valid   (rd_data_valid),
    .data_ready   (rd_data_ready),
    .data_out     (rd_data),
    .data_last    (rd_data_last),
    .data_resp    (rd_data_resp),
    .alloc_valid  (rd_alloc_valid),
    .alloc_ready  (rd_alloc_ready),
    .alloc_entry  (rd_alloc_entry),
    .m_axi_arid   (m_axi_arid),
    .m_axi_araddr (m_axi_araddr),
    .m_axi_arlen  (m_axi_arlen),
    .m_axi_arsize (m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid    (m_axi_rid),
    .m_axi_rdata  (m_axi_rdata),
    .m_axi_rresp  (m_axi_rresp),
    .m_axi_rlast  (m_axi_rlast),
    .m_axi_rvalid (m_axi_rvalid),
    .m_axi_rready (m_axi_rready)
  );

  data_fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .DEPTH      (FIFO_DEPTH)
  ) u_data_fifo (
    .clk       (dma_clk),
    .rst_n     (dma_rst_n),
    .push_valid(rd_data_valid),
    .push_ready(rd_data_ready),
    .push_data (rd_data),
    .pop_valid (fifo_pop_valid),
    .pop_ready (wr_data_ready),
    .pop_data  (fifo_pop_data),
    .full      (fifo_full),
    .empty     (fifo_empty)
  );

  axi_write_engine #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .ID_WIDTH      (ID_WIDTH),
    .MAX_BURST_LEN (MAX_BURST_LEN)
  ) u_axi_write_engine (
    .clk           (dma_clk),
    .rst_n         (dma_rst_n),
    .cmd_valid     (sched_write_cmd_valid),
    .cmd_ready     (sched_write_cmd_ready),
    .cmd           (sched_write_cmd),
    .data_valid    (fifo_pop_valid),
    .data_ready    (wr_data_ready),
    .data_in       (fifo_pop_data),
    .data_last     (1'b0),
    .write_done_valid(wr_done_valid),
    .write_done_ready(wr_done_ready),
    .write_resp    (wr_done_resp),
    .alloc_valid   (wr_alloc_valid),
    .alloc_ready   (wr_alloc_ready),
    .alloc_entry   (wr_alloc_entry),
    .m_axi_awid    (m_axi_awid),
    .m_axi_awaddr  (m_axi_awaddr),
    .m_axi_awlen   (m_axi_awlen),
    .m_axi_awsize  (m_axi_awsize),
    .m_axi_awburst (m_axi_awburst),
    .m_axi_awvalid (m_axi_awvalid),
    .m_axi_awready (m_axi_awready),
    .m_axi_wdata   (m_axi_wdata),
    .m_axi_wstrb   (m_axi_wstrb),
    .m_axi_wlast   (m_axi_wlast),
    .m_axi_wvalid  (m_axi_wvalid),
    .m_axi_wready  (m_axi_wready),
    .m_axi_bid     (m_axi_bid),
    .m_axi_bresp   (m_axi_bresp),
    .m_axi_bvalid  (m_axi_bvalid),
    .m_axi_bready  (m_axi_bready)
  );

  outstanding_table #(
    .ID_WIDTH (ID_WIDTH),
    .DEPTH    (OUTSTANDING_DEPTH)
  ) u_outstanding_table (
    .clk         (dma_clk),
    .rst_n       (dma_rst_n),
    .alloc_valid (rd_alloc_valid | wr_alloc_valid),
    .alloc_ready (ot_alloc_ready),
    .alloc_entry (rd_alloc_valid ? rd_alloc_entry : wr_alloc_entry),
    .lookup_valid(ot_lookup_valid),
    .lookup_id   (ot_lookup_id),
    .lookup_hit  (ot_lookup_hit),
    .lookup_entry(ot_lookup_entry),
    .retire_valid(ot_retire_valid),
    .retire_id   (ot_retire_id),
    .full        (ot_full),
    .empty       (ot_empty)
  );

  completion_writer #(
    .ADDR_WIDTH (ADDR_WIDTH)
  ) u_completion_writer (
    .clk              (dma_clk),
    .rst_n            (dma_rst_n),
    .comp_valid       (completion_valid),
    .comp_ready       (completion_ready),
    .comp_in          (completion_entry),
    .write_cmd_valid  (completion_cmd_valid),
    .write_cmd_ready  (completion_cmd_ready),
    .write_cmd        (completion_cmd),
    .write_rsp_valid  (completion_rsp_valid),
    .write_rsp_ready  (completion_rsp_ready),
    .write_rsp_resp   (completion_rsp_resp),
    .comp_head_advance(completion_head_advance)
  );

  interrupt_controller u_interrupt_controller (
    .clk             (cfg_clk),
    .rst_n           (cfg_rst_n),
    .irq_enable      (cfg_irq_enable),
    .completion_event(completion_head_advance),
    .error_event     (desc_fetch_error | desc_decode_error),
    .queue_event     (1'b0),
    .clear_irq_status(1'b0),
    .irq             (irq),
    .irq_status      (irq_status)
  );

endmodule
