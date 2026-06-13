`timescale 1ns/1ps

module dma_top #(
  parameter int AXIL_ADDR_WIDTH = 32,
  parameter int AXIL_DATA_WIDTH = 32,
  parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH        = dma_pkg::ID_WIDTH,
  parameter int MAX_BURST_BEATS = dma_pkg::MAX_BURST_LEN,
  parameter int OUTSTANDING_DEPTH = dma_pkg::OUTSTANDING_DEPTH
) (
  input  logic                           cfg_clk,
  input  logic                           cfg_rst_n,
  input  logic                           dma_clk,
  input  logic                           dma_rst_n,

  input  logic [AXIL_ADDR_WIDTH-1:0]     s_axil_awaddr,
  input  logic [2:0]                     s_axil_awprot,
  input  logic                           s_axil_awvalid,
  output logic                           s_axil_awready,
  input  logic [AXIL_DATA_WIDTH-1:0]     s_axil_wdata,
  input  logic [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb,
  input  logic                           s_axil_wvalid,
  output logic                           s_axil_wready,
  output logic [1:0]                     s_axil_bresp,
  output logic                           s_axil_bvalid,
  input  logic                           s_axil_bready,
  input  logic [AXIL_ADDR_WIDTH-1:0]     s_axil_araddr,
  input  logic [2:0]                     s_axil_arprot,
  input  logic                           s_axil_arvalid,
  output logic                           s_axil_arready,
  output logic [AXIL_DATA_WIDTH-1:0]     s_axil_rdata,
  output logic [1:0]                     s_axil_rresp,
  output logic                           s_axil_rvalid,
  input  logic                           s_axil_rready,

  output logic [ID_WIDTH-1:0]            m_axi_awid,
  output logic [ADDR_WIDTH-1:0]          m_axi_awaddr,
  output logic [7:0]                     m_axi_awlen,
  output logic [2:0]                     m_axi_awsize,
  output logic [1:0]                     m_axi_awburst,
  output logic                           m_axi_awvalid,
  input  logic                           m_axi_awready,
  output logic [DATA_WIDTH-1:0]          m_axi_wdata,
  output logic [(DATA_WIDTH/8)-1:0]      m_axi_wstrb,
  output logic                           m_axi_wlast,
  output logic                           m_axi_wvalid,
  input  logic                           m_axi_wready,
  input  logic [ID_WIDTH-1:0]            m_axi_bid,
  input  logic [1:0]                     m_axi_bresp,
  input  logic                           m_axi_bvalid,
  output logic                           m_axi_bready,

  output logic [ID_WIDTH-1:0]            m_axi_arid,
  output logic [ADDR_WIDTH-1:0]          m_axi_araddr,
  output logic [7:0]                     m_axi_arlen,
  output logic [2:0]                     m_axi_arsize,
  output logic [1:0]                     m_axi_arburst,
  output logic                           m_axi_arvalid,
  input  logic                           m_axi_arready,
  input  logic [ID_WIDTH-1:0]            m_axi_rid,
  input  logic [DATA_WIDTH-1:0]          m_axi_rdata,
  input  logic [1:0]                     m_axi_rresp,
  input  logic                           m_axi_rlast,
  input  logic                           m_axi_rvalid,
  output logic                           m_axi_rready,

  output logic                           irq
);

  localparam int CONTROL_CDC_WIDTH =
      (3 * ADDR_WIDTH) + 32 + 32 + 1;
  localparam int STATUS_CDC_WIDTH =
      (2 * ADDR_WIDTH) + (5 * 32) + 2;

  logic                      cfg_start_pulse;
  logic                      cfg_soft_reset_pulse;
  logic                      cfg_error_clear_pulse;
  logic [ADDR_WIDTH-1:0]     cfg_src_addr;
  logic [ADDR_WIDTH-1:0]     cfg_dst_addr;
  logic [31:0]               cfg_len_bytes;
  logic [ADDR_WIDTH-1:0]     cfg_desc_base;
  logic [31:0]               cfg_desc_count;
  logic                      cfg_desc_mode_enable;
  logic [3:0]                cfg_irq_enable;

  logic                      cfg_dma_busy;
  logic                      cfg_dma_desc_active;
  logic [31:0]               cfg_desc_index;
  logic [31:0]               cfg_error_cause;
  logic [31:0]               cfg_bytes_remaining;
  logic [ADDR_WIDTH-1:0]     cfg_active_src_addr;
  logic [ADDR_WIDTH-1:0]     cfg_active_dst_addr;
  logic [31:0]               cfg_completed_desc_count;
  logic [31:0]               cfg_completed_byte_count_lo;
  logic                      cfg_dma_done_pulse;
  logic                      cfg_dma_single_done_pulse;
  logic                      cfg_dma_desc_done_pulse;
  logic                      cfg_dma_desc_list_done_pulse;
  logic                      cfg_dma_error_pulse;

  logic [CONTROL_CDC_WIDTH-1:0] cfg_control_bus;
  logic [CONTROL_CDC_WIDTH-1:0] cfg_control_snapshot;
  logic [CONTROL_CDC_WIDTH-1:0] dma_control_bus;
  logic                         cfg_control_ready;
  logic                         cfg_control_valid;
  logic                         dma_start_pulse;
  logic                         dma_soft_reset_pulse;
  logic                         dma_error_clear_pulse;
  logic [ADDR_WIDTH-1:0]        dma_src_addr;
  logic [ADDR_WIDTH-1:0]        dma_dst_addr;
  logic [31:0]                  dma_len_bytes;
  logic [ADDR_WIDTH-1:0]        dma_desc_base;
  logic [31:0]                  dma_desc_count;
  logic                         dma_desc_mode_enable;

  logic                         dma_busy;
  logic                         dma_done_pulse;
  logic                         dma_single_done_pulse;
  logic                         dma_desc_done_pulse;
  logic                         dma_desc_list_done_pulse;
  logic                         dma_error_pulse;
  logic                         dma_desc_active;
  logic [31:0]                  dma_desc_index;
  logic [31:0]                  dma_error_cause;
  logic [31:0]                  dma_bytes_remaining;
  logic [ADDR_WIDTH-1:0]        dma_active_src_addr;
  logic [ADDR_WIDTH-1:0]        dma_active_dst_addr;
  logic [31:0]                  dma_completed_desc_count;
  logic [31:0]                  dma_completed_byte_count_lo;
  logic [STATUS_CDC_WIDTH-1:0]  dma_status_bus;
  logic [STATUS_CDC_WIDTH-1:0]  cfg_status_bus;
  logic                         dma_status_ready;
  logic                         cfg_status_valid_pulse;

  assign cfg_control_bus = {
    cfg_src_addr,
    cfg_dst_addr,
    cfg_desc_base,
    cfg_len_bytes,
    cfg_desc_count,
    cfg_desc_mode_enable
  };

  always_ff @(posedge cfg_clk or negedge cfg_rst_n) begin
    if (!cfg_rst_n) begin
      cfg_control_valid    <= 1'b0;
      cfg_control_snapshot <= '0;
    end else begin
      if (cfg_control_valid && cfg_control_ready) begin
        cfg_control_valid <= 1'b0;
      end

      if (cfg_start_pulse && (!cfg_control_valid || cfg_control_ready)) begin
        cfg_control_snapshot <= cfg_control_bus;
        cfg_control_valid    <= 1'b1;
      end
    end
  end

  assign {
    dma_src_addr,
    dma_dst_addr,
    dma_desc_base,
    dma_len_bytes,
    dma_desc_count,
    dma_desc_mode_enable
  } = dma_control_bus;

  assign dma_status_bus = {
    dma_active_src_addr,
    dma_active_dst_addr,
    dma_desc_index,
    dma_error_cause,
    dma_bytes_remaining,
    dma_completed_desc_count,
    dma_completed_byte_count_lo,
    dma_busy,
    dma_desc_active
  };

  assign {
    cfg_active_src_addr,
    cfg_active_dst_addr,
    cfg_desc_index,
    cfg_error_cause,
    cfg_bytes_remaining,
    cfg_completed_desc_count,
    cfg_completed_byte_count_lo,
    cfg_dma_busy,
    cfg_dma_desc_active
  } = cfg_status_bus;

  axi_lite_regs #(
    .REG_ADDR_WIDTH (AXIL_ADDR_WIDTH),
    .REG_DATA_WIDTH (AXIL_DATA_WIDTH),
    .ADDR_WIDTH     (ADDR_WIDTH)
  ) u_axi_lite_regs (
    .clk                     (cfg_clk),
    .rst_n                   (cfg_rst_n),
    .s_axil_awaddr           (s_axil_awaddr),
    .s_axil_awprot           (s_axil_awprot),
    .s_axil_awvalid          (s_axil_awvalid),
    .s_axil_awready          (s_axil_awready),
    .s_axil_wdata            (s_axil_wdata),
    .s_axil_wstrb            (s_axil_wstrb),
    .s_axil_wvalid           (s_axil_wvalid),
    .s_axil_wready           (s_axil_wready),
    .s_axil_bresp            (s_axil_bresp),
    .s_axil_bvalid           (s_axil_bvalid),
    .s_axil_bready           (s_axil_bready),
    .s_axil_araddr           (s_axil_araddr),
    .s_axil_arprot           (s_axil_arprot),
    .s_axil_arvalid          (s_axil_arvalid),
    .s_axil_arready          (s_axil_arready),
    .s_axil_rdata            (s_axil_rdata),
    .s_axil_rresp            (s_axil_rresp),
    .s_axil_rvalid           (s_axil_rvalid),
    .s_axil_rready           (s_axil_rready),
    .busy_i                  (cfg_dma_busy),
    .done_set_i              (cfg_dma_done_pulse),
    .single_done_set_i       (cfg_dma_single_done_pulse),
    .desc_done_set_i         (cfg_dma_desc_done_pulse),
    .desc_list_done_set_i    (cfg_dma_desc_list_done_pulse),
    .error_set_i             (cfg_dma_error_pulse),
    .desc_active_i           (cfg_dma_desc_active),
    .desc_index_i            (cfg_desc_index),
    .error_cause_i           (cfg_error_cause),
    .bytes_remaining_i       (cfg_bytes_remaining),
    .active_src_addr_i       (cfg_active_src_addr),
    .active_dst_addr_i       (cfg_active_dst_addr),
    .completed_desc_count_i  (cfg_completed_desc_count),
    .completed_byte_count_lo_i (cfg_completed_byte_count_lo),
    .start_pulse_o           (cfg_start_pulse),
    .soft_reset_pulse_o      (cfg_soft_reset_pulse),
    .error_clear_pulse_o     (cfg_error_clear_pulse),
    .src_addr_o              (cfg_src_addr),
    .dst_addr_o              (cfg_dst_addr),
    .len_bytes_o             (cfg_len_bytes),
    .desc_base_o             (cfg_desc_base),
    .desc_count_o            (cfg_desc_count),
    .desc_mode_enable_o      (cfg_desc_mode_enable),
    .irq_enable_o            (cfg_irq_enable),
    .irq_o                   (irq)
  );

  cdc_bus_handshake #(
    .WIDTH (CONTROL_CDC_WIDTH)
  ) u_control_cdc (
    .src_clk         (cfg_clk),
    .src_rst_n       (cfg_rst_n),
    .src_valid       (cfg_control_valid),
    .src_ready       (cfg_control_ready),
    .src_data        (cfg_control_snapshot),
    .dst_clk         (dma_clk),
    .dst_rst_n       (dma_rst_n),
    .dst_valid_pulse (dma_start_pulse),
    .dst_data        (dma_control_bus)
  );

  cdc_pulse_sync u_soft_reset_cdc (
    .src_clk    (cfg_clk),
    .src_rst_n  (cfg_rst_n),
    .src_pulse  (cfg_soft_reset_pulse),
    .dst_clk    (dma_clk),
    .dst_rst_n  (dma_rst_n),
    .dst_pulse  (dma_soft_reset_pulse)
  );

  cdc_pulse_sync u_error_clear_cdc (
    .src_clk    (cfg_clk),
    .src_rst_n  (cfg_rst_n),
    .src_pulse  (cfg_error_clear_pulse),
    .dst_clk    (dma_clk),
    .dst_rst_n  (dma_rst_n),
    .dst_pulse  (dma_error_clear_pulse)
  );

  dma_core #(
    .ADDR_WIDTH        (ADDR_WIDTH),
    .DATA_WIDTH        (DATA_WIDTH),
    .ID_WIDTH          (ID_WIDTH),
    .MAX_BURST_BEATS   (MAX_BURST_BEATS),
    .OUTSTANDING_DEPTH (OUTSTANDING_DEPTH)
  ) u_dma_core (
    .clk                       (dma_clk),
    .rst_n                     (dma_rst_n),
    .start_i                   (dma_start_pulse),
    .soft_reset_i              (dma_soft_reset_pulse),
    .error_clear_i             (dma_error_clear_pulse),
    .src_addr_i                (dma_src_addr),
    .dst_addr_i                (dma_dst_addr),
    .len_bytes_i               (dma_len_bytes),
    .desc_base_i               (dma_desc_base),
    .desc_count_i              (dma_desc_count),
    .desc_mode_i               (dma_desc_mode_enable),
    .busy_o                    (dma_busy),
    .done_pulse_o              (dma_done_pulse),
    .single_done_pulse_o       (dma_single_done_pulse),
    .desc_done_pulse_o         (dma_desc_done_pulse),
    .desc_list_done_pulse_o    (dma_desc_list_done_pulse),
    .error_pulse_o             (dma_error_pulse),
    .desc_active_o             (dma_desc_active),
    .desc_index_o              (dma_desc_index),
    .error_cause_o             (dma_error_cause),
    .bytes_remaining_o         (dma_bytes_remaining),
    .active_src_addr_o         (dma_active_src_addr),
    .active_dst_addr_o         (dma_active_dst_addr),
    .completed_desc_count_o    (dma_completed_desc_count),
    .completed_byte_count_lo_o (dma_completed_byte_count_lo),
    .m_axi_awid                (m_axi_awid),
    .m_axi_awaddr              (m_axi_awaddr),
    .m_axi_awlen               (m_axi_awlen),
    .m_axi_awsize              (m_axi_awsize),
    .m_axi_awburst             (m_axi_awburst),
    .m_axi_awvalid             (m_axi_awvalid),
    .m_axi_awready             (m_axi_awready),
    .m_axi_wdata               (m_axi_wdata),
    .m_axi_wstrb               (m_axi_wstrb),
    .m_axi_wlast               (m_axi_wlast),
    .m_axi_wvalid              (m_axi_wvalid),
    .m_axi_wready              (m_axi_wready),
    .m_axi_bid                 (m_axi_bid),
    .m_axi_bresp               (m_axi_bresp),
    .m_axi_bvalid              (m_axi_bvalid),
    .m_axi_bready              (m_axi_bready),
    .m_axi_arid                (m_axi_arid),
    .m_axi_araddr              (m_axi_araddr),
    .m_axi_arlen               (m_axi_arlen),
    .m_axi_arsize              (m_axi_arsize),
    .m_axi_arburst             (m_axi_arburst),
    .m_axi_arvalid             (m_axi_arvalid),
    .m_axi_arready             (m_axi_arready),
    .m_axi_rid                 (m_axi_rid),
    .m_axi_rdata               (m_axi_rdata),
    .m_axi_rresp               (m_axi_rresp),
    .m_axi_rlast               (m_axi_rlast),
    .m_axi_rvalid              (m_axi_rvalid),
    .m_axi_rready              (m_axi_rready)
  );

  cdc_bus_handshake #(
    .WIDTH (STATUS_CDC_WIDTH)
  ) u_status_cdc (
    .src_clk         (dma_clk),
    .src_rst_n       (dma_rst_n),
    .src_valid       (1'b1),
    .src_ready       (dma_status_ready),
    .src_data        (dma_status_bus),
    .dst_clk         (cfg_clk),
    .dst_rst_n       (cfg_rst_n),
    .dst_valid_pulse (cfg_status_valid_pulse),
    .dst_data        (cfg_status_bus)
  );

  cdc_pulse_sync u_done_cdc (
    .src_clk    (dma_clk),
    .src_rst_n  (dma_rst_n),
    .src_pulse  (dma_done_pulse),
    .dst_clk    (cfg_clk),
    .dst_rst_n  (cfg_rst_n),
    .dst_pulse  (cfg_dma_done_pulse)
  );

  cdc_pulse_sync u_single_done_cdc (
    .src_clk    (dma_clk),
    .src_rst_n  (dma_rst_n),
    .src_pulse  (dma_single_done_pulse),
    .dst_clk    (cfg_clk),
    .dst_rst_n  (cfg_rst_n),
    .dst_pulse  (cfg_dma_single_done_pulse)
  );

  cdc_pulse_sync u_desc_done_cdc (
    .src_clk    (dma_clk),
    .src_rst_n  (dma_rst_n),
    .src_pulse  (dma_desc_done_pulse),
    .dst_clk    (cfg_clk),
    .dst_rst_n  (cfg_rst_n),
    .dst_pulse  (cfg_dma_desc_done_pulse)
  );

  cdc_pulse_sync u_desc_list_done_cdc (
    .src_clk    (dma_clk),
    .src_rst_n  (dma_rst_n),
    .src_pulse  (dma_desc_list_done_pulse),
    .dst_clk    (cfg_clk),
    .dst_rst_n  (cfg_rst_n),
    .dst_pulse  (cfg_dma_desc_list_done_pulse)
  );

  cdc_pulse_sync u_error_cdc (
    .src_clk    (dma_clk),
    .src_rst_n  (dma_rst_n),
    .src_pulse  (dma_error_pulse),
    .dst_clk    (cfg_clk),
    .dst_rst_n  (cfg_rst_n),
    .dst_pulse  (cfg_dma_error_pulse)
  );

endmodule
