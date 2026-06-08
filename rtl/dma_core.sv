`timescale 1ns/1ps

module dma_core #(
  parameter int ADDR_WIDTH = dma_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = dma_pkg::DATA_WIDTH,
  parameter int ID_WIDTH   = dma_pkg::ID_WIDTH
) (
  input  logic                        clk,
  input  logic                        rst_n,

  input  logic                        start_i,
  input  logic                        soft_reset_i,
  input  logic [ADDR_WIDTH-1:0]       src_addr_i,
  input  logic [ADDR_WIDTH-1:0]       dst_addr_i,
  input  logic [31:0]                 len_bytes_i,

  output logic                        busy_o,
  output logic                        done_pulse_o,
  output logic                        error_pulse_o,

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

  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam logic [31:0] DATA_BYTES_32 = DATA_BYTES;
  localparam logic [31:0] DATA_ALIGN_MASK_32 = DATA_BYTES - 1;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_AR,
    ST_R,
    ST_AW,
    ST_W,
    ST_B
  } state_e;

  state_e                  state_q;
  logic [ADDR_WIDTH-1:0]   src_addr_q;
  logic [ADDR_WIDTH-1:0]   dst_addr_q;
  logic [31:0]             remaining_bytes_q;
  logic [DATA_WIDTH-1:0]   read_data_q;
  logic                    done_pulse_q;
  logic                    error_pulse_q;

  logic                    invalid_start;
  logic [ADDR_WIDTH-1:0]   align_mask;

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

  assign align_mask = ADDR_WIDTH'(DATA_BYTES - 1);

  assign invalid_start =
      (len_bytes_i == 32'd0) ||
      ((src_addr_i & align_mask) != '0) ||
      ((dst_addr_i & align_mask) != '0) ||
      ((len_bytes_i & DATA_ALIGN_MASK_32) != 32'd0);

  assign busy_o        = (state_q != ST_IDLE);
  assign done_pulse_o  = done_pulse_q;
  assign error_pulse_o = error_pulse_q;

  assign m_axi_arid    = '0;
  assign m_axi_araddr  = src_addr_q;
  assign m_axi_arlen   = 8'd0;
  assign m_axi_arsize  = axi_size(DATA_BYTES);
  assign m_axi_arburst = 2'b01;
  assign m_axi_arvalid = (state_q == ST_AR);
  assign m_axi_rready  = (state_q == ST_R);

  assign m_axi_awid    = '0;
  assign m_axi_awaddr  = dst_addr_q;
  assign m_axi_awlen   = 8'd0;
  assign m_axi_awsize  = axi_size(DATA_BYTES);
  assign m_axi_awburst = 2'b01;
  assign m_axi_awvalid = (state_q == ST_AW);
  assign m_axi_wdata   = read_data_q;
  assign m_axi_wstrb   = '1;
  assign m_axi_wlast   = 1'b1;
  assign m_axi_wvalid  = (state_q == ST_W);
  assign m_axi_bready  = (state_q == ST_B);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q           <= ST_IDLE;
      src_addr_q        <= '0;
      dst_addr_q        <= '0;
      remaining_bytes_q <= '0;
      read_data_q       <= '0;
      done_pulse_q      <= 1'b0;
      error_pulse_q     <= 1'b0;
    end else begin
      done_pulse_q  <= 1'b0;
      error_pulse_q <= 1'b0;

      if (soft_reset_i) begin
        state_q           <= ST_IDLE;
        src_addr_q        <= '0;
        dst_addr_q        <= '0;
        remaining_bytes_q <= '0;
        read_data_q       <= '0;
      end else begin
        case (state_q)
          ST_IDLE: begin
            if (start_i) begin
              if (invalid_start) begin
                error_pulse_q <= 1'b1;
              end else begin
                src_addr_q        <= src_addr_i;
                dst_addr_q        <= dst_addr_i;
                remaining_bytes_q <= len_bytes_i;
                state_q           <= ST_AR;
              end
            end
          end

          ST_AR: begin
            if (m_axi_arready) begin
              state_q <= ST_R;
            end
          end

          ST_R: begin
            if (m_axi_rvalid) begin
              if (m_axi_rresp != 2'b00) begin
                error_pulse_q     <= 1'b1;
                state_q           <= ST_IDLE;
                remaining_bytes_q <= '0;
              end else begin
                read_data_q <= m_axi_rdata;
                state_q     <= ST_AW;
              end
            end
          end

          ST_AW: begin
            if (m_axi_awready) begin
              state_q <= ST_W;
            end
          end

          ST_W: begin
            if (m_axi_wready) begin
              state_q <= ST_B;
            end
          end

          ST_B: begin
            if (m_axi_bvalid) begin
              if (m_axi_bresp != 2'b00) begin
                error_pulse_q     <= 1'b1;
                state_q           <= ST_IDLE;
                remaining_bytes_q <= '0;
              end else if (remaining_bytes_q == DATA_BYTES_32) begin
                done_pulse_q      <= 1'b1;
                state_q           <= ST_IDLE;
                remaining_bytes_q <= '0;
              end else begin
                src_addr_q        <= src_addr_q + DATA_BYTES;
                dst_addr_q        <= dst_addr_q + DATA_BYTES;
                remaining_bytes_q <= remaining_bytes_q - DATA_BYTES_32;
                state_q           <= ST_AR;
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
