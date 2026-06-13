`timescale 1ns/1ps

module axi_lite_regs #(
  parameter int REG_ADDR_WIDTH = 32,
  parameter int REG_DATA_WIDTH = 32,
  parameter int ADDR_WIDTH     = dma_pkg::ADDR_WIDTH
) (
  input  logic                            clk,
  input  logic                            rst_n,

  input  logic [REG_ADDR_WIDTH-1:0]       s_axil_awaddr,
  input  logic [2:0]                      s_axil_awprot,
  input  logic                            s_axil_awvalid,
  output logic                            s_axil_awready,
  input  logic [REG_DATA_WIDTH-1:0]       s_axil_wdata,
  input  logic [(REG_DATA_WIDTH/8)-1:0]   s_axil_wstrb,
  input  logic                            s_axil_wvalid,
  output logic                            s_axil_wready,
  output logic [1:0]                      s_axil_bresp,
  output logic                            s_axil_bvalid,
  input  logic                            s_axil_bready,
  input  logic [REG_ADDR_WIDTH-1:0]       s_axil_araddr,
  input  logic [2:0]                      s_axil_arprot,
  input  logic                            s_axil_arvalid,
  output logic                            s_axil_arready,
  output logic [REG_DATA_WIDTH-1:0]       s_axil_rdata,
  output logic [1:0]                      s_axil_rresp,
  output logic                            s_axil_rvalid,
  input  logic                            s_axil_rready,

  input  logic                            busy_i,
  input  logic                            done_set_i,
  input  logic                            single_done_set_i,
  input  logic                            desc_done_set_i,
  input  logic                            desc_list_done_set_i,
  input  logic                            error_set_i,
  input  logic                            desc_active_i,
  input  logic [31:0]                     desc_index_i,
  input  logic [31:0]                     error_cause_i,
  input  logic [31:0]                     bytes_remaining_i,
  input  logic [ADDR_WIDTH-1:0]           active_src_addr_i,
  input  logic [ADDR_WIDTH-1:0]           active_dst_addr_i,
  input  logic [31:0]                     completed_desc_count_i,
  input  logic [31:0]                     completed_byte_count_lo_i,

  output logic                            start_pulse_o,
  output logic                            soft_reset_pulse_o,
  output logic                            error_clear_pulse_o,
  output logic [ADDR_WIDTH-1:0]           src_addr_o,
  output logic [ADDR_WIDTH-1:0]           dst_addr_o,
  output logic [31:0]                     len_bytes_o,
  output logic [ADDR_WIDTH-1:0]           desc_base_o,
  output logic [31:0]                     desc_count_o,
  output logic                            desc_mode_enable_o,
  output logic [3:0]                      irq_enable_o,
  output logic                            irq_o
);

  import dma_pkg::*;

  localparam int STRB_WIDTH = REG_DATA_WIDTH / 8;

  localparam logic [REG_ADDR_WIDTH-1:0] CTRL        = REG_CTRL;
  localparam logic [REG_ADDR_WIDTH-1:0] STATUS      = REG_STATUS;
  localparam logic [REG_ADDR_WIDTH-1:0] SRC_ADDR_LO = REG_SRC_ADDR_LO;
  localparam logic [REG_ADDR_WIDTH-1:0] SRC_ADDR_HI = REG_SRC_ADDR_HI;
  localparam logic [REG_ADDR_WIDTH-1:0] DST_ADDR_LO = REG_DST_ADDR_LO;
  localparam logic [REG_ADDR_WIDTH-1:0] DST_ADDR_HI = REG_DST_ADDR_HI;
  localparam logic [REG_ADDR_WIDTH-1:0] LEN_BYTES   = REG_LEN_BYTES;
  localparam logic [REG_ADDR_WIDTH-1:0] IRQ_ENABLE  = REG_IRQ_ENABLE;
  localparam logic [REG_ADDR_WIDTH-1:0] IRQ_STATUS  = REG_IRQ_STATUS;
  localparam logic [REG_ADDR_WIDTH-1:0] VERSION     = REG_VERSION;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_BASE_LO = REG_DESC_BASE_LO;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_BASE_HI = REG_DESC_BASE_HI;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_COUNT   = REG_DESC_COUNT;
  localparam logic [REG_ADDR_WIDTH-1:0] MODE         = REG_MODE;
  localparam logic [REG_ADDR_WIDTH-1:0] DESC_INDEX   = REG_DESC_INDEX;
  localparam logic [REG_ADDR_WIDTH-1:0] ERROR_CAUSE  = REG_ERROR_CAUSE;
  localparam logic [REG_ADDR_WIDTH-1:0] BYTES_REMAINING = REG_BYTES_REMAINING;
  localparam logic [REG_ADDR_WIDTH-1:0] ACTIVE_SRC_LO = REG_ACTIVE_SRC_LO;
  localparam logic [REG_ADDR_WIDTH-1:0] ACTIVE_DST_LO = REG_ACTIVE_DST_LO;
  localparam logic [REG_ADDR_WIDTH-1:0] COMPLETED_DESC_COUNT = REG_COMPLETED_DESC_COUNT;
  localparam logic [REG_ADDR_WIDTH-1:0] COMPLETED_BYTE_COUNT_LO = REG_COMPLETED_BYTE_COUNT_LO;

  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

  logic                         aw_valid_q;
  logic [REG_ADDR_WIDTH-1:0]    awaddr_q;
  logic                         w_valid_q;
  logic [REG_DATA_WIDTH-1:0]    wdata_q;
  logic [STRB_WIDTH-1:0]        wstrb_q;
  logic                         bvalid_q;
  logic [1:0]                   bresp_q;
  logic                         rvalid_q;
  logic [REG_DATA_WIDTH-1:0]    rdata_q;
  logic [1:0]                   rresp_q;

  logic [31:0]                  src_addr_lo_q;
  logic [31:0]                  src_addr_hi_q;
  logic [31:0]                  dst_addr_lo_q;
  logic [31:0]                  dst_addr_hi_q;
  logic [31:0]                  len_bytes_q;
  logic [31:0]                  desc_base_lo_q;
  logic [31:0]                  desc_base_hi_q;
  logic [31:0]                  desc_count_q;
  logic                         desc_mode_enable_q;
  logic [3:0]                   irq_enable_q;
  logic [3:0]                   irq_status_q;
  logic                         done_q;
  logic                         error_q;
  logic                         start_pulse_q;
  logic                         soft_reset_pulse_q;
  logic                         error_clear_pulse_q;

  logic                         write_fire;
  logic [REG_DATA_WIDTH-1:0]    read_data_mux;
  logic [1:0]                   read_resp_mux;
  logic [1:0]                   write_resp_mux;

  logic [31:0]                  src_addr_lo_d;
  logic [31:0]                  src_addr_hi_d;
  logic [31:0]                  dst_addr_lo_d;
  logic [31:0]                  dst_addr_hi_d;
  logic [31:0]                  len_bytes_d;
  logic [31:0]                  desc_base_lo_d;
  logic [31:0]                  desc_base_hi_d;
  logic [31:0]                  desc_count_d;
  logic                         desc_mode_enable_d;
  logic [3:0]                   irq_enable_d;
  logic [3:0]                   irq_status_d;
  logic                         done_d;
  logic                         error_d;
  logic                         error_clear_d;
  logic [REG_DATA_WIDTH-1:0]    irq_enable_wdata;
  logic [REG_DATA_WIDTH-1:0]    mode_wdata;

  function automatic logic [REG_DATA_WIDTH-1:0] apply_wstrb(
    input logic [REG_DATA_WIDTH-1:0] old_value,
    input logic [REG_DATA_WIDTH-1:0] new_value,
    input logic [STRB_WIDTH-1:0]     strb
  );
    apply_wstrb = old_value;
    for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
      if (strb[byte_idx]) begin
        apply_wstrb[(byte_idx * 8) +: 8] = new_value[(byte_idx * 8) +: 8];
      end
    end
  endfunction

  assign s_axil_awready = !aw_valid_q && !bvalid_q;
  assign s_axil_wready  = !w_valid_q && !bvalid_q;
  assign s_axil_bvalid  = bvalid_q;
  assign s_axil_bresp   = bresp_q;
  assign s_axil_arready = !rvalid_q;
  assign s_axil_rvalid  = rvalid_q;
  assign s_axil_rdata   = rdata_q;
  assign s_axil_rresp   = rresp_q;

  assign start_pulse_o      = start_pulse_q;
  assign soft_reset_pulse_o = soft_reset_pulse_q;
  assign error_clear_pulse_o = error_clear_pulse_q;
  assign src_addr_o         = {src_addr_hi_q, src_addr_lo_q};
  assign dst_addr_o         = {dst_addr_hi_q, dst_addr_lo_q};
  assign len_bytes_o        = len_bytes_q;
  assign desc_base_o        = {desc_base_hi_q, desc_base_lo_q};
  assign desc_count_o       = desc_count_q;
  assign desc_mode_enable_o = desc_mode_enable_q;
  assign irq_enable_o       = irq_enable_q;
  assign irq_o              = |(irq_status_q & irq_enable_q);

  assign write_fire = aw_valid_q && w_valid_q && !bvalid_q;

  always_comb begin
    read_data_mux = '0;
    read_resp_mux = AXI_RESP_OKAY;

    case (s_axil_araddr)
      CTRL: begin
        read_data_mux = '0;
      end
      STATUS: begin
        read_data_mux = {{(REG_DATA_WIDTH-4){1'b0}},
                         desc_active_i,
                         error_q,
                         done_q,
                         busy_i};
      end
      SRC_ADDR_LO: begin
        read_data_mux = src_addr_lo_q;
      end
      SRC_ADDR_HI: begin
        read_data_mux = src_addr_hi_q;
      end
      DST_ADDR_LO: begin
        read_data_mux = dst_addr_lo_q;
      end
      DST_ADDR_HI: begin
        read_data_mux = dst_addr_hi_q;
      end
      LEN_BYTES: begin
        read_data_mux = len_bytes_q;
      end
      IRQ_ENABLE: begin
        read_data_mux = {{(REG_DATA_WIDTH-4){1'b0}}, irq_enable_q};
      end
      IRQ_STATUS: begin
        read_data_mux = {{(REG_DATA_WIDTH-4){1'b0}}, irq_status_q};
      end
      VERSION: begin
        read_data_mux = VERSION_VALUE;
      end
      DESC_BASE_LO: begin
        read_data_mux = desc_base_lo_q;
      end
      DESC_BASE_HI: begin
        read_data_mux = desc_base_hi_q;
      end
      DESC_COUNT: begin
        read_data_mux = desc_count_q;
      end
      MODE: begin
        read_data_mux = {{(REG_DATA_WIDTH-1){1'b0}}, desc_mode_enable_q};
      end
      DESC_INDEX: begin
        read_data_mux = desc_index_i;
      end
      ERROR_CAUSE: begin
        read_data_mux = error_cause_i;
      end
      BYTES_REMAINING: begin
        read_data_mux = bytes_remaining_i;
      end
      ACTIVE_SRC_LO: begin
        read_data_mux = active_src_addr_i[31:0];
      end
      ACTIVE_DST_LO: begin
        read_data_mux = active_dst_addr_i[31:0];
      end
      COMPLETED_DESC_COUNT: begin
        read_data_mux = completed_desc_count_i;
      end
      COMPLETED_BYTE_COUNT_LO: begin
        read_data_mux = completed_byte_count_lo_i;
      end
      default: begin
        read_resp_mux = AXI_RESP_SLVERR;
      end
    endcase
  end

  always_comb begin
    src_addr_lo_d = src_addr_lo_q;
    src_addr_hi_d = src_addr_hi_q;
    dst_addr_lo_d = dst_addr_lo_q;
    dst_addr_hi_d = dst_addr_hi_q;
    len_bytes_d   = len_bytes_q;
    desc_base_lo_d = desc_base_lo_q;
    desc_base_hi_d = desc_base_hi_q;
    desc_count_d   = desc_count_q;
    desc_mode_enable_d = desc_mode_enable_q;
    irq_enable_d  = irq_enable_q;
    irq_status_d  = irq_status_q;
    done_d        = done_q;
    error_d       = error_q;
    error_clear_d = 1'b0;
    irq_enable_wdata = apply_wstrb({{(REG_DATA_WIDTH-4){1'b0}}, irq_enable_q},
                                   wdata_q,
                                   wstrb_q);
    mode_wdata = apply_wstrb({{(REG_DATA_WIDTH-1){1'b0}}, desc_mode_enable_q},
                             wdata_q,
                             wstrb_q);
    write_resp_mux = AXI_RESP_OKAY;

    if (write_fire) begin
      case (awaddr_q)
        CTRL: begin
          // CTRL bits are write-one pulse fields handled in the sequential
          // block. The register itself reads as zero.
        end
        STATUS: begin
          if (wstrb_q[0] && wdata_q[1]) begin
            done_d = 1'b0;
          end
          if (wstrb_q[0] && wdata_q[2]) begin
            error_d = 1'b0;
            error_clear_d = 1'b1;
          end
        end
        SRC_ADDR_LO: begin
          src_addr_lo_d = apply_wstrb(src_addr_lo_q, wdata_q, wstrb_q);
        end
        SRC_ADDR_HI: begin
          src_addr_hi_d = apply_wstrb(src_addr_hi_q, wdata_q, wstrb_q);
        end
        DST_ADDR_LO: begin
          dst_addr_lo_d = apply_wstrb(dst_addr_lo_q, wdata_q, wstrb_q);
        end
        DST_ADDR_HI: begin
          dst_addr_hi_d = apply_wstrb(dst_addr_hi_q, wdata_q, wstrb_q);
        end
        LEN_BYTES: begin
          len_bytes_d = apply_wstrb(len_bytes_q, wdata_q, wstrb_q);
        end
        IRQ_ENABLE: begin
          irq_enable_d = irq_enable_wdata[3:0];
        end
        IRQ_STATUS: begin
          if (wstrb_q[0] && wdata_q[0]) begin
            irq_status_d[0] = 1'b0;
          end
          if (wstrb_q[0] && wdata_q[1]) begin
            irq_status_d[1] = 1'b0;
          end
          if (wstrb_q[0] && wdata_q[2]) begin
            irq_status_d[2] = 1'b0;
          end
          if (wstrb_q[0] && wdata_q[3]) begin
            irq_status_d[3] = 1'b0;
          end
        end
        VERSION: begin
          // Read-only constant. Writes are accepted and ignored.
        end
        DESC_BASE_LO: begin
          desc_base_lo_d = apply_wstrb(desc_base_lo_q, wdata_q, wstrb_q);
        end
        DESC_BASE_HI: begin
          desc_base_hi_d = apply_wstrb(desc_base_hi_q, wdata_q, wstrb_q);
        end
        DESC_COUNT: begin
          desc_count_d = apply_wstrb(desc_count_q, wdata_q, wstrb_q);
        end
        MODE: begin
          desc_mode_enable_d = mode_wdata[0];
        end
        DESC_INDEX: begin
          // Read-only debug register. Writes are accepted and ignored.
        end
        ERROR_CAUSE: begin
          if (|wstrb_q && |wdata_q) begin
            error_clear_d = 1'b1;
          end
        end
        BYTES_REMAINING,
        ACTIVE_SRC_LO,
        ACTIVE_DST_LO,
        COMPLETED_DESC_COUNT,
        COMPLETED_BYTE_COUNT_LO: begin
          // Read-only observability registers. Writes are accepted and ignored.
        end
        default: begin
          write_resp_mux = AXI_RESP_SLVERR;
        end
      endcase
    end

    if (done_set_i) begin
      done_d = 1'b1;
    end

    if (single_done_set_i) begin
      irq_status_d[0] = 1'b1;
    end

    if (error_set_i) begin
      error_d = 1'b1;
      irq_status_d[1] = 1'b1;
    end

    if (desc_done_set_i) begin
      irq_status_d[2] = 1'b1;
    end

    if (desc_list_done_set_i) begin
      irq_status_d[3] = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_valid_q         <= 1'b0;
      awaddr_q           <= '0;
      w_valid_q          <= 1'b0;
      wdata_q            <= '0;
      wstrb_q            <= '0;
      bvalid_q           <= 1'b0;
      bresp_q            <= AXI_RESP_OKAY;
      rvalid_q           <= 1'b0;
      rdata_q            <= '0;
      rresp_q            <= AXI_RESP_OKAY;
      src_addr_lo_q      <= '0;
      src_addr_hi_q      <= '0;
      dst_addr_lo_q      <= '0;
      dst_addr_hi_q      <= '0;
      len_bytes_q        <= '0;
      desc_base_lo_q     <= '0;
      desc_base_hi_q     <= '0;
      desc_count_q       <= '0;
      desc_mode_enable_q <= 1'b0;
      irq_enable_q       <= '0;
      irq_status_q       <= '0;
      done_q             <= 1'b0;
      error_q            <= 1'b0;
      start_pulse_q      <= 1'b0;
      soft_reset_pulse_q <= 1'b0;
      error_clear_pulse_q <= 1'b0;
    end else begin
      start_pulse_q      <= 1'b0;
      soft_reset_pulse_q <= 1'b0;
      error_clear_pulse_q <= error_clear_d;
      src_addr_lo_q      <= src_addr_lo_d;
      src_addr_hi_q      <= src_addr_hi_d;
      dst_addr_lo_q      <= dst_addr_lo_d;
      dst_addr_hi_q      <= dst_addr_hi_d;
      len_bytes_q        <= len_bytes_d;
      desc_base_lo_q     <= desc_base_lo_d;
      desc_base_hi_q     <= desc_base_hi_d;
      desc_count_q       <= desc_count_d;
      desc_mode_enable_q <= desc_mode_enable_d;
      irq_enable_q       <= irq_enable_d;
      irq_status_q       <= irq_status_d;
      done_q             <= done_d;
      error_q            <= error_d;

      if (s_axil_awvalid && s_axil_awready) begin
        aw_valid_q <= 1'b1;
        awaddr_q   <= s_axil_awaddr;
      end

      if (s_axil_wvalid && s_axil_wready) begin
        w_valid_q <= 1'b1;
        wdata_q   <= s_axil_wdata;
        wstrb_q   <= s_axil_wstrb;
      end

      if (write_fire) begin
        aw_valid_q <= 1'b0;
        w_valid_q  <= 1'b0;
        bvalid_q   <= 1'b1;
        bresp_q    <= write_resp_mux;

        if ((awaddr_q == CTRL) && wstrb_q[0] && (write_resp_mux == AXI_RESP_OKAY)) begin
          start_pulse_q      <= wdata_q[0];
          soft_reset_pulse_q <= wdata_q[1];
        end
      end else if (s_axil_bready) begin
        bvalid_q <= 1'b0;
      end

      if (s_axil_arvalid && s_axil_arready) begin
        rvalid_q <= 1'b1;
        rdata_q  <= read_data_mux;
        rresp_q  <= read_resp_mux;
      end else if (s_axil_rready) begin
        rvalid_q <= 1'b0;
      end
    end
  end

endmodule
