`timescale 1ns/1ps

module dma_core #(
  parameter int ADDR_WIDTH      = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH      = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH        = dma_pkg::ID_WIDTH,
  parameter int MAX_BURST_BEATS = dma_pkg::MAX_BURST_LEN,
  parameter int OUTSTANDING_DEPTH = dma_pkg::OUTSTANDING_DEPTH
) (
  input  logic                        clk,
  input  logic                        rst_n,

  input  logic                        start_i,
  input  logic                        soft_reset_i,
  input  logic                        error_clear_i,
  input  logic [ADDR_WIDTH-1:0]       src_addr_i,
  input  logic [ADDR_WIDTH-1:0]       dst_addr_i,
  input  logic [31:0]                 len_bytes_i,
  input  logic [ADDR_WIDTH-1:0]       desc_base_i,
  input  logic [31:0]                 desc_count_i,
  input  logic                        desc_mode_i,

  output logic                        busy_o,
  output logic                        done_pulse_o,
  output logic                        single_done_pulse_o,
  output logic                        desc_done_pulse_o,
  output logic                        desc_list_done_pulse_o,
  output logic                        error_pulse_o,
  output logic                        desc_active_o,
  output logic [31:0]                 desc_index_o,
  output logic [31:0]                 error_cause_o,
  output logic [31:0]                 bytes_remaining_o,
  output logic [ADDR_WIDTH-1:0]       active_src_addr_o,
  output logic [ADDR_WIDTH-1:0]       active_dst_addr_o,
  output logic [31:0]                 completed_desc_count_o,
  output logic [31:0]                 completed_byte_count_lo_o,

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
  output logic                        m_axi_rready
);

  import dma_pkg::*;

  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam logic [31:0] DATA_BYTES_32 = DATA_BYTES;
  localparam logic [31:0] DATA_ALIGN_MASK_32 = DATA_BYTES - 1;
  localparam int DESC_WORD_COUNT = dma_pkg::DESC_WORDS;
  localparam int DESC_EXT_WORD_COUNT = dma_pkg::DESC_WORDS;
  localparam int DESC_STATUS_OFFSET = 24;
  localparam int DESC_EXT_OFFSET = dma_pkg::DESC_BYTES;
  localparam logic [15:0] DESC_WORDS_16 = dma_pkg::DESC_WORDS;
  localparam logic [15:0] DESC_LAST_BEAT = dma_pkg::DESC_WORDS - 1;
  localparam logic [7:0] DESC_ARLEN = dma_pkg::DESC_WORDS - 1;

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_XFER_PREP,
    ST_XFER_AR,
    ST_XFER_R,
    ST_XFER_AW,
    ST_XFER_W,
    ST_XFER_B,
    ST_DESC_FETCH_AR,
    ST_DESC_FETCH_R,
    ST_DESC_CHECK,
    ST_DESC_EXT_AR,
    ST_DESC_EXT_R,
    ST_TILE_CHECK,
    ST_DESC_STATUS_AW,
    ST_DESC_STATUS_W,
    ST_DESC_STATUS_B
  } state_e;

  state_e                state_q;
  logic [ADDR_WIDTH-1:0] src_addr_q;
  logic [ADDR_WIDTH-1:0] dst_addr_q;
  logic [31:0]           remaining_bytes_q;
  logic [15:0]           burst_beats_q;
  logic [31:0]           burst_bytes_q;
  logic [15:0]           read_beat_q;
  logic [15:0]           write_beat_q;
  logic                  read_error_seen_q;
  logic [DATA_WIDTH-1:0] burst_buffer_q [0:MAX_BURST_BEATS-1];

  logic                  desc_mode_active_q;
  logic [ADDR_WIDTH-1:0] desc_addr_q;
  logic [31:0]           desc_count_q;
  logic [31:0]           desc_index_q;
  logic                  desc_stop_after_q;
  logic                  desc_status_error_q;
  logic [31:0]           desc_status_word_q;
  logic [31:0]           desc_words_q [0:DESC_WORD_COUNT-1];
  logic [31:0]           desc_ext_words_q [0:DESC_EXT_WORD_COUNT-1];
  logic                  tile_mode_active_q;
  logic [31:0]           tile_row_bytes_q;
  logic [31:0]           tile_num_rows_q;
  logic [31:0]           tile_current_row_q;
  logic [31:0]           tile_src_stride_q;
  logic [31:0]           tile_dst_stride_q;
  logic [ADDR_WIDTH-1:0] tile_row_src_addr_q;
  logic [ADDR_WIDTH-1:0] tile_row_dst_addr_q;

  logic [31:0]           error_cause_q;
  logic [31:0]           completed_desc_count_q;
  logic [31:0]           completed_byte_count_q;
  logic                  done_pulse_q;
  logic                  single_done_pulse_q;
  logic                  desc_done_pulse_q;
  logic                  desc_list_done_pulse_q;
  logic                  error_pulse_q;

  logic [15:0]           next_burst_beats;
  logic [31:0]           next_burst_bytes;
  logic                  xfer_read_last;
  logic                  desc_read_last;
  logic                  write_last;
  logic                  xfer_read_error;
  logic                  desc_read_error;
  logic [31:0]           single_start_cause;
  logic [31:0]           desc_start_cause;
  logic [31:0]           desc_base_check_cause;
  logic [31:0]           desc_tile_check_cause;
  logic [ADDR_WIDTH-1:0] desc_src_addr;
  logic [ADDR_WIDTH-1:0] desc_dst_addr;
  logic [31:0]           desc_len_bytes;
  logic [31:0]           desc_control;
  logic [3:0]            desc_control_mode;
  logic [31:0]           tile_num_rows;
  logic [31:0]           tile_src_stride;
  logic [31:0]           tile_dst_stride;
  logic [1:0]            read_alloc_txn_type;
  logic [1:0]            write_alloc_txn_type;
  logic [1:0]            read_lookup_txn_type;
  logic [1:0]            write_lookup_txn_type;
  logic [15:0]           read_lookup_desc_id;
  logic [15:0]           write_lookup_desc_id;
  logic [15:0]           read_lookup_expected_beats;
  logic [15:0]           write_lookup_expected_beats;
  logic [15:0]           read_expected_beats;
  logic [15:0]           write_expected_beats;
  logic                  read_alloc_valid;
  logic                  read_alloc_ready;
  logic                  read_alloc_error;
  logic                  read_lookup_hit;
  logic                  read_retire_valid;
  logic                  read_retire_error;
  logic                  read_table_full;
  logic                  read_table_empty;
  logic                  write_alloc_valid;
  logic                  write_alloc_ready;
  logic                  write_alloc_error;
  logic                  write_lookup_hit;
  logic                  write_retire_valid;
  logic                  write_retire_error;
  logic                  write_table_full;
  logic                  write_table_empty;
  logic                  ar_fire;
  logic                  aw_fire;
  logic                  read_final_fire;
  logic                  b_fire;

  function automatic logic [2:0] axi_size(input int bytes);
    case (bytes)
      1:       axi_size = 3'd0;
      2:       axi_size = 3'd1;
      4:       axi_size = 3'd2;
      8:       axi_size = 3'd3;
      16:      axi_size = 3'd4;
      32:      axi_size = 3'd5;
      64:      axi_size = 3'd6;
      default: axi_size = 3'd0;
    endcase
  endfunction

  function automatic logic [STRB_WIDTH-1:0] descriptor_status_strobe();
    descriptor_status_strobe = '0;
    for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
      if (byte_idx < 4) begin
        descriptor_status_strobe[byte_idx] = 1'b1;
      end
    end
  endfunction

  function automatic logic [15:0] beats_to_4kb(
    input logic [ADDR_WIDTH-1:0] addr
  );
    logic [12:0] bytes_to_boundary;
    begin
      bytes_to_boundary = 13'd4096 - {1'b0, addr[11:0]};
      beats_to_4kb = bytes_to_boundary / DATA_BYTES;
      if (beats_to_4kb == 16'd0) begin
        beats_to_4kb = 16'd1;
      end
    end
  endfunction

  function automatic logic [15:0] calc_burst_beats(
    input logic [ADDR_WIDTH-1:0] src_addr,
    input logic [ADDR_WIDTH-1:0] dst_addr,
    input logic [31:0]           remaining_bytes
  );
    logic [31:0] remaining_beats;
    logic [15:0] limited_beats;
    logic [15:0] src_boundary_beats;
    logic [15:0] dst_boundary_beats;
    begin
      remaining_beats = remaining_bytes / DATA_BYTES;
      limited_beats = MAX_BURST_BEATS;
      if (limited_beats == 16'd0) begin
        limited_beats = 16'd1;
      end
      if (limited_beats > 16'd256) begin
        limited_beats = 16'd256;
      end
      if (remaining_beats < limited_beats) begin
        limited_beats = remaining_beats[15:0];
      end

      src_boundary_beats = beats_to_4kb(src_addr);
      dst_boundary_beats = beats_to_4kb(dst_addr);
      if (src_boundary_beats < limited_beats) begin
        limited_beats = src_boundary_beats;
      end
      if (dst_boundary_beats < limited_beats) begin
        limited_beats = dst_boundary_beats;
      end

      if (limited_beats == 16'd0) begin
        calc_burst_beats = 16'd1;
      end else begin
        calc_burst_beats = limited_beats;
      end
    end
  endfunction

  function automatic logic [31:0] transfer_error_cause(
    input logic [ADDR_WIDTH-1:0] src_addr,
    input logic [ADDR_WIDTH-1:0] dst_addr,
    input logic [31:0]           len_bytes
  );
    logic [ADDR_WIDTH-1:0] align_mask;
    begin
      align_mask = ADDR_WIDTH'(DATA_BYTES - 1);
      if (len_bytes == 32'd0) begin
        transfer_error_cause = ERROR_CAUSE_ZERO_LEN;
      end else if ((src_addr & align_mask) != '0) begin
        transfer_error_cause = ERROR_CAUSE_SRC_UNALIGNED;
      end else if ((dst_addr & align_mask) != '0) begin
        transfer_error_cause = ERROR_CAUSE_DST_UNALIGNED;
      end else if ((len_bytes & DATA_ALIGN_MASK_32) != 32'd0) begin
        transfer_error_cause = ERROR_CAUSE_LEN_UNALIGNED;
      end else begin
        transfer_error_cause = ERROR_CAUSE_NONE;
      end
    end
  endfunction

  function automatic logic [31:0] descriptor_start_error_cause(
    input logic [ADDR_WIDTH-1:0] desc_base,
    input logic [31:0]           desc_count
  );
    logic [ADDR_WIDTH-1:0] desc_align_mask;
    begin
      desc_align_mask = ADDR_WIDTH'(dma_pkg::DESC_BYTES - 1);
      if (desc_count == 32'd0) begin
        descriptor_start_error_cause = ERROR_CAUSE_DESC_COUNT_ZERO;
      end else if ((desc_base & desc_align_mask) != '0) begin
        descriptor_start_error_cause = ERROR_CAUSE_DESC_BASE_UNALIGNED;
      end else if (DATA_BYTES != 4) begin
        descriptor_start_error_cause = ERROR_CAUSE_DESC_BUS_UNSUPPORTED;
      end else begin
        descriptor_start_error_cause = ERROR_CAUSE_NONE;
      end
    end
  endfunction

  function automatic logic [31:0] tile_error_cause(
    input logic [ADDR_WIDTH-1:0] src_addr,
    input logic [ADDR_WIDTH-1:0] dst_addr,
    input logic [31:0]           row_bytes,
    input logic [31:0]           num_rows,
    input logic [31:0]           src_stride,
    input logic [31:0]           dst_stride
  );
    begin
      if (row_bytes == 32'd0) begin
        tile_error_cause = ERROR_CAUSE_TILE_ROW_BYTES_ZERO;
      end else if (num_rows == 32'd0) begin
        tile_error_cause = ERROR_CAUSE_TILE_ROW_COUNT_ZERO;
      end else if (transfer_error_cause(src_addr, dst_addr, row_bytes) != ERROR_CAUSE_NONE) begin
        tile_error_cause = transfer_error_cause(src_addr, dst_addr, row_bytes);
      end else if (((src_stride & DATA_ALIGN_MASK_32) != 32'd0) ||
                   (src_stride < row_bytes)) begin
        tile_error_cause = ERROR_CAUSE_TILE_SRC_STRIDE;
      end else if (((dst_stride & DATA_ALIGN_MASK_32) != 32'd0) ||
                   (dst_stride < row_bytes)) begin
        tile_error_cause = ERROR_CAUSE_TILE_DST_STRIDE;
      end else begin
        tile_error_cause = ERROR_CAUSE_NONE;
      end
    end
  endfunction

  function automatic logic [31:0] descriptor_status_word(
    input logic        is_error,
    input logic [31:0] cause
  );
    begin
      descriptor_status_word = 32'd0;
      descriptor_status_word[0] = !is_error;
      descriptor_status_word[1] = is_error;
      descriptor_status_word[15:8] = cause[7:0];
    end
  endfunction

  function automatic logic [31:0] axi_data_to_word(
    input logic [DATA_WIDTH-1:0] data
  );
    begin
      axi_data_to_word = 32'd0;
      for (int bit_idx = 0; bit_idx < DATA_WIDTH; bit_idx++) begin
        if (bit_idx < 32) begin
          axi_data_to_word[bit_idx] = data[bit_idx];
        end
      end
    end
  endfunction

  assign next_burst_beats = calc_burst_beats(src_addr_q,
                                             dst_addr_q,
                                             remaining_bytes_q);
  assign next_burst_bytes = {16'd0, next_burst_beats} * DATA_BYTES_32;

  assign xfer_read_last = (read_beat_q == (burst_beats_q - 16'd1));
  assign desc_read_last = (read_beat_q == DESC_LAST_BEAT);
  assign write_last = (write_beat_q == (burst_beats_q - 16'd1));
  assign xfer_read_error =
      (m_axi_rresp != 2'b00) || (m_axi_rlast != xfer_read_last);
  assign desc_read_error =
      (m_axi_rresp != 2'b00) || (m_axi_rlast != desc_read_last);

  assign single_start_cause = transfer_error_cause(src_addr_i,
                                                   dst_addr_i,
                                                   len_bytes_i);
  assign desc_start_cause = descriptor_start_error_cause(desc_base_i,
                                                         desc_count_i);

  assign desc_src_addr = ADDR_WIDTH'({desc_words_q[1], desc_words_q[0]});
  assign desc_dst_addr = ADDR_WIDTH'({desc_words_q[3], desc_words_q[2]});
  assign desc_len_bytes = desc_words_q[4];
  assign desc_control = desc_words_q[5];
  assign desc_control_mode = desc_control[7:4];
  assign tile_num_rows = desc_ext_words_q[0];
  assign tile_src_stride = desc_ext_words_q[1];
  assign tile_dst_stride = desc_ext_words_q[2];
  assign desc_base_check_cause =
      !desc_control[0] ? ERROR_CAUSE_DESC_INVALID :
      ((desc_control_mode != DESC_MODE_LINEAR) &&
       (desc_control_mode != DESC_MODE_2D)) ? ERROR_CAUSE_DESC_MODE_UNSUPPORTED :
      (desc_control_mode == DESC_MODE_LINEAR) ?
          transfer_error_cause(desc_src_addr, desc_dst_addr, desc_len_bytes) :
          ERROR_CAUSE_NONE;
  assign desc_tile_check_cause =
      tile_error_cause(desc_src_addr,
                       desc_dst_addr,
                       desc_len_bytes,
                       tile_num_rows,
                       tile_src_stride,
                       tile_dst_stride);

  assign ar_fire = m_axi_arvalid && m_axi_arready;
  assign aw_fire = m_axi_awvalid && m_axi_awready;
  assign read_final_fire = m_axi_rvalid && m_axi_rready &&
                           (((state_q == ST_XFER_R) &&
                             (m_axi_rlast || xfer_read_last)) ||
                            (((state_q == ST_DESC_FETCH_R) ||
                              (state_q == ST_DESC_EXT_R)) &&
                             (m_axi_rlast || desc_read_last)));
  assign b_fire = m_axi_bvalid && m_axi_bready;

  always_comb begin
    read_alloc_txn_type = ((state_q == ST_DESC_FETCH_AR) ||
                           (state_q == ST_DESC_EXT_AR)) ?
                          TXN_TYPE_DESC_FETCH : TXN_TYPE_SOURCE_READ;
    read_expected_beats = ((state_q == ST_DESC_FETCH_AR) ||
                           (state_q == ST_DESC_EXT_AR)) ?
                          DESC_WORDS_16 : burst_beats_q;

    write_alloc_txn_type = (state_q == ST_DESC_STATUS_AW) ?
                           TXN_TYPE_COMP_WRITE : TXN_TYPE_DEST_WRITE;
    write_expected_beats = (state_q == ST_DESC_STATUS_AW) ?
                           16'd1 : burst_beats_q;
  end

  assign read_alloc_valid = ar_fire;
  assign read_retire_valid = read_final_fire;
  assign write_alloc_valid = aw_fire;
  assign write_retire_valid = b_fire;

  outstanding_table #(
    .ID_WIDTH (ID_WIDTH),
    .DEPTH    (OUTSTANDING_DEPTH)
  ) u_read_outstanding_table (
    .clk           (clk),
    .rst_n         (rst_n),
    .clear_i       (soft_reset_i),
    .alloc_valid   (read_alloc_valid),
    .alloc_ready   (read_alloc_ready),
    .alloc_axi_id   ({ID_WIDTH{1'b0}}),
    .alloc_txn_type (read_alloc_txn_type),
    .alloc_desc_id  (desc_index_q[15:0]),
    .alloc_expected_beats (read_expected_beats),
    .alloc_error   (read_alloc_error),
    .lookup_valid  (m_axi_rvalid && m_axi_rready),
    .lookup_id     (m_axi_rid),
    .lookup_hit    (read_lookup_hit),
    .lookup_txn_type (read_lookup_txn_type),
    .lookup_desc_id  (read_lookup_desc_id),
    .lookup_expected_beats (read_lookup_expected_beats),
    .retire_valid  (read_retire_valid),
    .retire_id     (m_axi_rid),
    .retire_error  (read_retire_error),
    .full          (read_table_full),
    .empty         (read_table_empty)
  );

  outstanding_table #(
    .ID_WIDTH (ID_WIDTH),
    .DEPTH    (OUTSTANDING_DEPTH)
  ) u_write_outstanding_table (
    .clk           (clk),
    .rst_n         (rst_n),
    .clear_i       (soft_reset_i),
    .alloc_valid   (write_alloc_valid),
    .alloc_ready   (write_alloc_ready),
    .alloc_axi_id   ({ID_WIDTH{1'b0}}),
    .alloc_txn_type (write_alloc_txn_type),
    .alloc_desc_id  (desc_index_q[15:0]),
    .alloc_expected_beats (write_expected_beats),
    .alloc_error   (write_alloc_error),
    .lookup_valid  (m_axi_bvalid && m_axi_bready),
    .lookup_id     (m_axi_bid),
    .lookup_hit    (write_lookup_hit),
    .lookup_txn_type (write_lookup_txn_type),
    .lookup_desc_id  (write_lookup_desc_id),
    .lookup_expected_beats (write_lookup_expected_beats),
    .retire_valid  (write_retire_valid),
    .retire_id     (m_axi_bid),
    .retire_error  (write_retire_error),
    .full          (write_table_full),
    .empty         (write_table_empty)
  );

  assign busy_o        = (state_q != ST_IDLE);
  assign done_pulse_o  = done_pulse_q;
  assign single_done_pulse_o = single_done_pulse_q;
  assign desc_done_pulse_o = desc_done_pulse_q;
  assign desc_list_done_pulse_o = desc_list_done_pulse_q;
  assign error_pulse_o = error_pulse_q;
  assign desc_active_o = desc_mode_active_q && (state_q != ST_IDLE);
  assign desc_index_o  = desc_index_q;
  assign error_cause_o = error_cause_q;
  assign bytes_remaining_o = remaining_bytes_q;
  assign active_src_addr_o = src_addr_q;
  assign active_dst_addr_o = dst_addr_q;
  assign completed_desc_count_o = completed_desc_count_q;
  assign completed_byte_count_lo_o = completed_byte_count_q;

  assign m_axi_arid    = '0;
  assign m_axi_araddr  = (state_q == ST_DESC_FETCH_AR) ? desc_addr_q :
                         (state_q == ST_DESC_EXT_AR) ?
                         (desc_addr_q + ADDR_WIDTH'(DESC_EXT_OFFSET)) :
                         src_addr_q;
  assign m_axi_arlen   = ((state_q == ST_DESC_FETCH_AR) ||
                          (state_q == ST_DESC_EXT_AR)) ?
                         DESC_ARLEN : (burst_beats_q[7:0] - 8'd1);
  assign m_axi_arsize  = axi_size(DATA_BYTES);
  assign m_axi_arburst = 2'b01;
  assign m_axi_arvalid = ((state_q == ST_XFER_AR) ||
                          (state_q == ST_DESC_FETCH_AR) ||
                          (state_q == ST_DESC_EXT_AR)) &&
                         read_alloc_ready;
  assign m_axi_rready  = (state_q == ST_XFER_R) ||
                         (state_q == ST_DESC_FETCH_R) ||
                         (state_q == ST_DESC_EXT_R);

  assign m_axi_awid    = '0;
  assign m_axi_awaddr  = (state_q == ST_DESC_STATUS_AW) ?
                         (desc_addr_q + ADDR_WIDTH'(DESC_STATUS_OFFSET)) :
                         dst_addr_q;
  assign m_axi_awlen   = (state_q == ST_DESC_STATUS_AW) ?
                         8'd0 : (burst_beats_q[7:0] - 8'd1);
  assign m_axi_awsize  = axi_size(DATA_BYTES);
  assign m_axi_awburst = 2'b01;
  assign m_axi_awvalid = ((state_q == ST_XFER_AW) ||
                          (state_q == ST_DESC_STATUS_AW)) &&
                         write_alloc_ready;
  assign m_axi_wdata   = (state_q == ST_DESC_STATUS_W) ?
                         DATA_WIDTH'(desc_status_word_q) :
                         burst_buffer_q[write_beat_q];
  assign m_axi_wstrb   = (state_q == ST_DESC_STATUS_W) ?
                         descriptor_status_strobe() : '1;
  assign m_axi_wlast   = (state_q == ST_DESC_STATUS_W) ? 1'b1 : write_last;
  assign m_axi_wvalid  = (state_q == ST_XFER_W) ||
                         (state_q == ST_DESC_STATUS_W);
  assign m_axi_bready  = (state_q == ST_XFER_B) ||
                         (state_q == ST_DESC_STATUS_B);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q             <= ST_IDLE;
      src_addr_q          <= '0;
      dst_addr_q          <= '0;
      remaining_bytes_q   <= '0;
      burst_beats_q       <= '0;
      burst_bytes_q       <= '0;
      read_beat_q         <= '0;
      write_beat_q        <= '0;
      read_error_seen_q   <= 1'b0;
      desc_mode_active_q  <= 1'b0;
      desc_addr_q         <= '0;
      desc_count_q        <= '0;
      desc_index_q        <= '0;
      desc_stop_after_q   <= 1'b0;
      desc_status_error_q <= 1'b0;
      desc_status_word_q  <= '0;
      tile_mode_active_q  <= 1'b0;
      tile_row_bytes_q    <= '0;
      tile_num_rows_q     <= '0;
      tile_current_row_q  <= '0;
      tile_src_stride_q   <= '0;
      tile_dst_stride_q   <= '0;
      tile_row_src_addr_q <= '0;
      tile_row_dst_addr_q <= '0;
      error_cause_q       <= ERROR_CAUSE_NONE;
      completed_desc_count_q <= '0;
      completed_byte_count_q <= '0;
      done_pulse_q        <= 1'b0;
      single_done_pulse_q <= 1'b0;
      desc_done_pulse_q   <= 1'b0;
      desc_list_done_pulse_q <= 1'b0;
      error_pulse_q       <= 1'b0;
      for (int buf_idx = 0; buf_idx < MAX_BURST_BEATS; buf_idx++) begin
        burst_buffer_q[buf_idx] <= '0;
      end
      for (int desc_idx = 0; desc_idx < DESC_WORD_COUNT; desc_idx++) begin
        desc_words_q[desc_idx] <= '0;
      end
      for (int ext_idx = 0; ext_idx < DESC_EXT_WORD_COUNT; ext_idx++) begin
        desc_ext_words_q[ext_idx] <= '0;
      end
    end else begin
      done_pulse_q  <= 1'b0;
      single_done_pulse_q <= 1'b0;
      desc_done_pulse_q <= 1'b0;
      desc_list_done_pulse_q <= 1'b0;
      error_pulse_q <= 1'b0;

      if (soft_reset_i) begin
        state_q             <= ST_IDLE;
        src_addr_q          <= '0;
        dst_addr_q          <= '0;
        remaining_bytes_q   <= '0;
        burst_beats_q       <= '0;
        burst_bytes_q       <= '0;
        read_beat_q         <= '0;
        write_beat_q        <= '0;
        read_error_seen_q   <= 1'b0;
        desc_mode_active_q  <= 1'b0;
        desc_addr_q         <= '0;
        desc_count_q        <= '0;
        desc_index_q        <= '0;
        desc_stop_after_q   <= 1'b0;
        desc_status_error_q <= 1'b0;
        desc_status_word_q  <= '0;
        tile_mode_active_q  <= 1'b0;
        tile_row_bytes_q    <= '0;
        tile_num_rows_q     <= '0;
        tile_current_row_q  <= '0;
        tile_src_stride_q   <= '0;
        tile_dst_stride_q   <= '0;
        tile_row_src_addr_q <= '0;
        tile_row_dst_addr_q <= '0;
        error_cause_q       <= ERROR_CAUSE_NONE;
        completed_desc_count_q <= '0;
        completed_byte_count_q <= '0;
        for (int desc_idx = 0; desc_idx < DESC_WORD_COUNT; desc_idx++) begin
          desc_words_q[desc_idx] <= '0;
        end
        for (int ext_idx = 0; ext_idx < DESC_EXT_WORD_COUNT; ext_idx++) begin
          desc_ext_words_q[ext_idx] <= '0;
        end
      end else begin
        if (error_clear_i) begin
          error_cause_q <= ERROR_CAUSE_NONE;
        end

        case (state_q)
          ST_IDLE: begin
            if (start_i) begin
              error_cause_q       <= ERROR_CAUSE_NONE;
              desc_index_q        <= '0;
              desc_status_error_q <= 1'b0;
              desc_stop_after_q   <= 1'b0;
              tile_mode_active_q  <= 1'b0;
              tile_current_row_q  <= '0;
              completed_desc_count_q <= '0;
              completed_byte_count_q <= '0;

              if (desc_mode_i) begin
                if (desc_start_cause != ERROR_CAUSE_NONE) begin
                  error_cause_q  <= desc_start_cause;
                  error_pulse_q  <= 1'b1;
                end else begin
                  desc_mode_active_q <= 1'b1;
                  desc_addr_q        <= desc_base_i;
                  desc_count_q       <= desc_count_i;
                  read_beat_q        <= '0;
                  read_error_seen_q  <= 1'b0;
                  state_q            <= ST_DESC_FETCH_AR;
                end
              end else begin
                desc_mode_active_q <= 1'b0;
                if (single_start_cause != ERROR_CAUSE_NONE) begin
                  error_cause_q <= single_start_cause;
                  error_pulse_q <= 1'b1;
                end else begin
                  src_addr_q        <= src_addr_i;
                  dst_addr_q        <= dst_addr_i;
                  remaining_bytes_q <= len_bytes_i;
                  state_q           <= ST_XFER_PREP;
                end
              end
            end
          end

          ST_XFER_PREP: begin
            burst_beats_q     <= next_burst_beats;
            burst_bytes_q     <= next_burst_bytes;
            read_beat_q       <= '0;
            write_beat_q      <= '0;
            read_error_seen_q <= 1'b0;
            state_q           <= ST_XFER_AR;
          end

          ST_XFER_AR: begin
            if (ar_fire) begin
              read_beat_q       <= '0;
              read_error_seen_q <= 1'b0;
              state_q           <= ST_XFER_R;
            end
          end

          ST_XFER_R: begin
            if (m_axi_rvalid) begin
              if (!read_lookup_hit) begin
                error_cause_q       <= ERROR_CAUSE_OUTSTANDING_TABLE;
                remaining_bytes_q   <= '0;
                desc_status_word_q  <= descriptor_status_word(1'b1,
                                                               ERROR_CAUSE_OUTSTANDING_TABLE);
                desc_status_error_q <= desc_mode_active_q;
                if (desc_mode_active_q) begin
                  state_q <= ST_DESC_STATUS_AW;
                end else begin
                  error_pulse_q <= 1'b1;
                  state_q       <= ST_IDLE;
                end
              end else begin
                burst_buffer_q[read_beat_q] <= m_axi_rdata;

                if (m_axi_rlast || xfer_read_last) begin
                  if (read_retire_error || read_error_seen_q || xfer_read_error) begin
                    error_cause_q       <= read_retire_error ?
                                           ERROR_CAUSE_OUTSTANDING_TABLE :
                                           ERROR_CAUSE_AXI_READ;
                    remaining_bytes_q   <= '0;
                    desc_status_word_q  <= descriptor_status_word(
                        1'b1,
                        read_retire_error ? ERROR_CAUSE_OUTSTANDING_TABLE :
                                            ERROR_CAUSE_AXI_READ);
                    desc_status_error_q <= desc_mode_active_q;
                    if (desc_mode_active_q) begin
                      state_q <= ST_DESC_STATUS_AW;
                    end else begin
                      error_pulse_q <= 1'b1;
                      state_q       <= ST_IDLE;
                    end
                  end else begin
                    write_beat_q <= '0;
                    state_q      <= ST_XFER_AW;
                  end
                end else begin
                  if (m_axi_rresp != 2'b00) begin
                    read_error_seen_q <= 1'b1;
                  end
                  read_beat_q <= read_beat_q + 16'd1;
                end
              end
            end
          end

          ST_XFER_AW: begin
            if (aw_fire) begin
              write_beat_q <= '0;
              state_q      <= ST_XFER_W;
            end
          end

          ST_XFER_W: begin
            if (m_axi_wready) begin
              if (write_last) begin
                state_q <= ST_XFER_B;
              end else begin
                write_beat_q <= write_beat_q + 16'd1;
              end
            end
          end

          ST_XFER_B: begin
            if (m_axi_bvalid) begin
              if (!write_lookup_hit || write_retire_error) begin
                error_cause_q       <= ERROR_CAUSE_OUTSTANDING_TABLE;
                remaining_bytes_q   <= '0;
                desc_status_word_q  <= descriptor_status_word(1'b1,
                                                               ERROR_CAUSE_OUTSTANDING_TABLE);
                desc_status_error_q <= desc_mode_active_q;
                if (desc_mode_active_q) begin
                  state_q <= ST_DESC_STATUS_AW;
                end else begin
                  error_pulse_q <= 1'b1;
                  state_q       <= ST_IDLE;
                end
              end else if (m_axi_bresp != 2'b00) begin
                error_cause_q       <= ERROR_CAUSE_AXI_WRITE;
                remaining_bytes_q   <= '0;
                desc_status_word_q  <= descriptor_status_word(1'b1,
                                                               ERROR_CAUSE_AXI_WRITE);
                desc_status_error_q <= desc_mode_active_q;
                if (desc_mode_active_q) begin
                  state_q <= ST_DESC_STATUS_AW;
                end else begin
                  error_pulse_q <= 1'b1;
                  state_q       <= ST_IDLE;
                end
              end else if (remaining_bytes_q == burst_bytes_q) begin
                remaining_bytes_q <= '0;
                completed_byte_count_q <= completed_byte_count_q + burst_bytes_q;
                if (desc_mode_active_q) begin
                  if (tile_mode_active_q &&
                      ((tile_current_row_q + 32'd1) < tile_num_rows_q)) begin
                    tile_current_row_q <= tile_current_row_q + 32'd1;
                    tile_row_src_addr_q <= tile_row_src_addr_q +
                                           ADDR_WIDTH'(tile_src_stride_q);
                    tile_row_dst_addr_q <= tile_row_dst_addr_q +
                                           ADDR_WIDTH'(tile_dst_stride_q);
                    src_addr_q <= tile_row_src_addr_q +
                                  ADDR_WIDTH'(tile_src_stride_q);
                    dst_addr_q <= tile_row_dst_addr_q +
                                  ADDR_WIDTH'(tile_dst_stride_q);
                    remaining_bytes_q <= tile_row_bytes_q;
                    state_q <= ST_XFER_PREP;
                  end else begin
                    desc_status_word_q  <= descriptor_status_word(1'b0,
                                                                   ERROR_CAUSE_NONE);
                    desc_status_error_q <= 1'b0;
                    state_q             <= ST_DESC_STATUS_AW;
                  end
                end else begin
                  done_pulse_q        <= 1'b1;
                  single_done_pulse_q <= 1'b1;
                  state_q             <= ST_IDLE;
                end
              end else begin
                src_addr_q        <= src_addr_q + ADDR_WIDTH'(burst_bytes_q);
                dst_addr_q        <= dst_addr_q + ADDR_WIDTH'(burst_bytes_q);
                remaining_bytes_q <= remaining_bytes_q - burst_bytes_q;
                completed_byte_count_q <= completed_byte_count_q + burst_bytes_q;
                state_q           <= ST_XFER_PREP;
              end
            end
          end

          ST_DESC_FETCH_AR: begin
            if (ar_fire) begin
              read_beat_q       <= '0;
              read_error_seen_q <= 1'b0;
              state_q           <= ST_DESC_FETCH_R;
            end
          end

          ST_DESC_FETCH_R: begin
            if (m_axi_rvalid) begin
              if (!read_lookup_hit) begin
                error_cause_q <= ERROR_CAUSE_OUTSTANDING_TABLE;
                error_pulse_q <= 1'b1;
                state_q       <= ST_IDLE;
              end else begin
                desc_words_q[read_beat_q] <= axi_data_to_word(m_axi_rdata);

                if (m_axi_rlast || desc_read_last) begin
                  if (read_retire_error || read_error_seen_q || desc_read_error) begin
                    error_cause_q <= read_retire_error ?
                                     ERROR_CAUSE_OUTSTANDING_TABLE :
                                     ERROR_CAUSE_AXI_READ;
                    error_pulse_q <= 1'b1;
                    state_q       <= ST_IDLE;
                  end else begin
                    state_q <= ST_DESC_CHECK;
                  end
                end else begin
                  if (m_axi_rresp != 2'b00) begin
                    read_error_seen_q <= 1'b1;
                  end
                  read_beat_q <= read_beat_q + 16'd1;
                end
              end
            end
          end

          ST_DESC_CHECK: begin
            if (desc_base_check_cause != ERROR_CAUSE_NONE) begin
              error_cause_q       <= desc_base_check_cause;
              desc_status_word_q  <= descriptor_status_word(1'b1,
                                                             desc_base_check_cause);
              desc_status_error_q <= 1'b1;
              state_q             <= ST_DESC_STATUS_AW;
            end else if (desc_control_mode == DESC_MODE_2D) begin
              read_beat_q       <= '0;
              read_error_seen_q <= 1'b0;
              state_q           <= ST_DESC_EXT_AR;
            end else begin
              src_addr_q          <= desc_src_addr;
              dst_addr_q          <= desc_dst_addr;
              remaining_bytes_q   <= desc_len_bytes;
              desc_stop_after_q   <= desc_control[2];
              desc_status_error_q <= 1'b0;
              tile_mode_active_q  <= 1'b0;
              state_q             <= ST_XFER_PREP;
            end
          end

          ST_DESC_EXT_AR: begin
            if (ar_fire) begin
              read_beat_q       <= '0;
              read_error_seen_q <= 1'b0;
              state_q           <= ST_DESC_EXT_R;
            end
          end

          ST_DESC_EXT_R: begin
            if (m_axi_rvalid) begin
              if (!read_lookup_hit) begin
                error_cause_q       <= ERROR_CAUSE_OUTSTANDING_TABLE;
                desc_status_word_q  <= descriptor_status_word(1'b1,
                                                               ERROR_CAUSE_OUTSTANDING_TABLE);
                desc_status_error_q <= 1'b1;
                state_q             <= ST_DESC_STATUS_AW;
              end else begin
                desc_ext_words_q[read_beat_q] <= axi_data_to_word(m_axi_rdata);

                if (m_axi_rlast || desc_read_last) begin
                  if (read_retire_error || read_error_seen_q || desc_read_error) begin
                    error_cause_q       <= read_retire_error ?
                                           ERROR_CAUSE_OUTSTANDING_TABLE :
                                           ERROR_CAUSE_AXI_READ;
                    desc_status_word_q  <= descriptor_status_word(
                        1'b1,
                        read_retire_error ? ERROR_CAUSE_OUTSTANDING_TABLE :
                                            ERROR_CAUSE_AXI_READ);
                    desc_status_error_q <= 1'b1;
                    state_q             <= ST_DESC_STATUS_AW;
                  end else begin
                    state_q <= ST_TILE_CHECK;
                  end
                end else begin
                  if (m_axi_rresp != 2'b00) begin
                    read_error_seen_q <= 1'b1;
                  end
                  read_beat_q <= read_beat_q + 16'd1;
                end
              end
            end
          end

          ST_TILE_CHECK: begin
            if (desc_tile_check_cause != ERROR_CAUSE_NONE) begin
              error_cause_q       <= desc_tile_check_cause;
              desc_status_word_q  <= descriptor_status_word(1'b1,
                                                             desc_tile_check_cause);
              desc_status_error_q <= 1'b1;
              state_q             <= ST_DESC_STATUS_AW;
            end else begin
              src_addr_q          <= desc_src_addr;
              dst_addr_q          <= desc_dst_addr;
              remaining_bytes_q   <= desc_len_bytes;
              desc_stop_after_q   <= desc_control[2];
              desc_status_error_q <= 1'b0;
              tile_mode_active_q  <= 1'b1;
              tile_row_bytes_q    <= desc_len_bytes;
              tile_num_rows_q     <= tile_num_rows;
              tile_current_row_q  <= '0;
              tile_src_stride_q   <= tile_src_stride;
              tile_dst_stride_q   <= tile_dst_stride;
              tile_row_src_addr_q <= desc_src_addr;
              tile_row_dst_addr_q <= desc_dst_addr;
              state_q             <= ST_XFER_PREP;
            end
          end

          ST_DESC_STATUS_AW: begin
            if (aw_fire) begin
              state_q <= ST_DESC_STATUS_W;
            end
          end

          ST_DESC_STATUS_W: begin
            if (m_axi_wready) begin
              state_q <= ST_DESC_STATUS_B;
            end
          end

          ST_DESC_STATUS_B: begin
            if (m_axi_bvalid) begin
              if (!write_lookup_hit || write_retire_error) begin
                error_cause_q <= ERROR_CAUSE_OUTSTANDING_TABLE;
                error_pulse_q <= 1'b1;
                desc_mode_active_q <= 1'b0;
                tile_mode_active_q <= 1'b0;
                state_q       <= ST_IDLE;
              end else if (m_axi_bresp != 2'b00) begin
                error_cause_q <= ERROR_CAUSE_DESC_WRITEBACK;
                error_pulse_q <= 1'b1;
                desc_mode_active_q <= 1'b0;
                tile_mode_active_q <= 1'b0;
                state_q       <= ST_IDLE;
              end else if (desc_status_error_q) begin
                error_pulse_q <= 1'b1;
                desc_mode_active_q <= 1'b0;
                tile_mode_active_q <= 1'b0;
                state_q       <= ST_IDLE;
              end else if (desc_stop_after_q ||
                           ((desc_index_q + 32'd1) >= desc_count_q)) begin
                completed_desc_count_q <= completed_desc_count_q + 32'd1;
                desc_done_pulse_q      <= 1'b1;
                desc_list_done_pulse_q <= 1'b1;
                done_pulse_q           <= 1'b1;
                desc_mode_active_q     <= 1'b0;
                tile_mode_active_q     <= 1'b0;
                state_q                <= ST_IDLE;
              end else begin
                completed_desc_count_q <= completed_desc_count_q + 32'd1;
                desc_done_pulse_q      <= 1'b1;
                desc_index_q           <= desc_index_q + 32'd1;
                desc_addr_q            <= desc_addr_q +
                                          (tile_mode_active_q ?
                                           ADDR_WIDTH'(dma_pkg::TILE_DESC_BYTES) :
                                           ADDR_WIDTH'(dma_pkg::DESC_BYTES));
                tile_mode_active_q     <= 1'b0;
                state_q                <= ST_DESC_FETCH_AR;
              end
            end
          end

          default: begin
            state_q <= ST_IDLE;
          end
        endcase
      end
    end
  end

endmodule
