`timescale 1ns/1ps

package dma_pkg;

  // Current integration defaults. The top-level path is a conservative
  // burst-capable AXI DMA with linear descriptor processing, bounded
  // outstanding tracking, and explicit top-level CDC.
  parameter int ADDR_WIDTH        = 64;
  parameter int DATA_WIDTH        = 32;
  parameter int ID_WIDTH          = 4;
  parameter int STRB_WIDTH        = DATA_WIDTH / 8;

  localparam logic [31:0] VERSION_VALUE = 32'h0008_0005;

  localparam logic [31:0] REG_CTRL        = 32'h0000_0000;
  localparam logic [31:0] REG_STATUS      = 32'h0000_0004;
  localparam logic [31:0] REG_SRC_ADDR_LO = 32'h0000_0008;
  localparam logic [31:0] REG_SRC_ADDR_HI = 32'h0000_000c;
  localparam logic [31:0] REG_DST_ADDR_LO = 32'h0000_0010;
  localparam logic [31:0] REG_DST_ADDR_HI = 32'h0000_0014;
  localparam logic [31:0] REG_LEN_BYTES   = 32'h0000_0018;
  localparam logic [31:0] REG_IRQ_ENABLE  = 32'h0000_001c;
  localparam logic [31:0] REG_IRQ_STATUS  = 32'h0000_0020;
  localparam logic [31:0] REG_VERSION     = 32'h0000_0024;
  localparam logic [31:0] REG_DESC_BASE_LO = 32'h0000_0028;
  localparam logic [31:0] REG_DESC_BASE_HI = 32'h0000_002c;
  localparam logic [31:0] REG_DESC_COUNT   = 32'h0000_0030;
  localparam logic [31:0] REG_MODE         = 32'h0000_0034;
  localparam logic [31:0] REG_DESC_INDEX   = 32'h0000_0038;
  localparam logic [31:0] REG_ERROR_CAUSE  = 32'h0000_003c;
  localparam logic [31:0] REG_BYTES_REMAINING       = 32'h0000_0040;
  localparam logic [31:0] REG_ACTIVE_SRC_LO         = 32'h0000_0044;
  localparam logic [31:0] REG_ACTIVE_DST_LO         = 32'h0000_0048;
  localparam logic [31:0] REG_COMPLETED_DESC_COUNT  = 32'h0000_004c;
  localparam logic [31:0] REG_COMPLETED_BYTE_COUNT_LO = 32'h0000_0050;

  localparam logic [31:0] ERROR_CAUSE_NONE                 = 32'h0000_0000;
  localparam logic [31:0] ERROR_CAUSE_ZERO_LEN             = 32'h0000_0001;
  localparam logic [31:0] ERROR_CAUSE_SRC_UNALIGNED        = 32'h0000_0002;
  localparam logic [31:0] ERROR_CAUSE_DST_UNALIGNED        = 32'h0000_0003;
  localparam logic [31:0] ERROR_CAUSE_LEN_UNALIGNED        = 32'h0000_0004;
  localparam logic [31:0] ERROR_CAUSE_DESC_BASE_UNALIGNED  = 32'h0000_0005;
  localparam logic [31:0] ERROR_CAUSE_DESC_COUNT_ZERO      = 32'h0000_0006;
  localparam logic [31:0] ERROR_CAUSE_DESC_INVALID         = 32'h0000_0007;
  localparam logic [31:0] ERROR_CAUSE_AXI_READ             = 32'h0000_0008;
  localparam logic [31:0] ERROR_CAUSE_AXI_WRITE            = 32'h0000_0009;
  localparam logic [31:0] ERROR_CAUSE_DESC_BUS_UNSUPPORTED = 32'h0000_000a;
  localparam logic [31:0] ERROR_CAUSE_DESC_WRITEBACK       = 32'h0000_000b;
  localparam logic [31:0] ERROR_CAUSE_OUTSTANDING_TABLE    = 32'h0000_000c;
  localparam logic [31:0] ERROR_CAUSE_DESC_MODE_UNSUPPORTED = 32'h0000_000d;
  localparam logic [31:0] ERROR_CAUSE_TILE_ROW_BYTES_ZERO   = 32'h0000_000e;
  localparam logic [31:0] ERROR_CAUSE_TILE_ROW_COUNT_ZERO   = 32'h0000_000f;
  localparam logic [31:0] ERROR_CAUSE_TILE_SRC_STRIDE       = 32'h0000_0010;
  localparam logic [31:0] ERROR_CAUSE_TILE_DST_STRIDE       = 32'h0000_0011;

  parameter int DESC_WORDS        = 8;
  parameter int DESC_BYTES        = 32;
  parameter int TILE_DESC_WORDS   = 16;
  parameter int TILE_DESC_BYTES   = 64;
  parameter int COMP_WORDS        = 8;
  parameter int COMP_BYTES        = 32;
  parameter int FIFO_DEPTH        = 16;
  parameter int OUTSTANDING_DEPTH = 4;
  parameter int MAX_BURST_LEN     = 16;

  localparam logic [3:0] DESC_MODE_LINEAR = 4'd0;
  localparam logic [3:0] DESC_MODE_2D     = 4'd1;

  typedef enum logic [1:0] {
    DESC_STATUS_IDLE,
    DESC_STATUS_FETCHED,
    DESC_STATUS_ACTIVE,
    DESC_STATUS_DONE
  } descriptor_status_e;

  typedef enum logic [1:0] {
    COMP_STATUS_OKAY,
    COMP_STATUS_AXI_READ_ERR,
    COMP_STATUS_AXI_WRITE_ERR,
    COMP_STATUS_INTERNAL_ERR
  } completion_status_e;

  typedef enum logic [1:0] {
    TXN_TYPE_DESC_FETCH,
    TXN_TYPE_SOURCE_READ,
    TXN_TYPE_DEST_WRITE,
    TXN_TYPE_COMP_WRITE
  } transaction_type_e;

  localparam int DESC_RESERVED_W =
      (DESC_BYTES * 8) - ((2 * ADDR_WIDTH) + 32 + 16 + 8 + 2);
  localparam int COMP_RESERVED_W =
      (COMP_BYTES * 8) - (16 + 32 + 8 + 2);

  typedef struct packed {
    logic [ADDR_WIDTH-1:0] src_addr;
    logic [ADDR_WIDTH-1:0] dst_addr;
    logic [31:0]           len_bytes;
    logic [15:0]           desc_id;
    logic [7:0]            flags;
    descriptor_status_e    status;
    logic [DESC_RESERVED_W-1:0] reserved;
  } descriptor_t;

  typedef struct packed {
    logic [15:0]           desc_id;
    logic [31:0]           bytes_transferred;
    logic [7:0]            error_code;
    completion_status_e    status;
    logic [COMP_RESERVED_W-1:0] reserved;
  } completion_t;

  typedef struct packed {
    transaction_type_e     txn_type;
    logic [15:0]           desc_id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [31:0]           bytes_total;
    logic [15:0]           beats_total;
    logic [7:0]            burst_len;
    logic [7:0]            user;
  } dma_cmd_t;

  typedef struct packed {
    logic                  valid;
    logic [ID_WIDTH-1:0]   axi_id;
    transaction_type_e     txn_type;
    logic [15:0]           desc_id;
    logic [15:0]           expected_beats;
    logic [15:0]           completed_beats;
    logic [1:0]            resp;
    logic                  error_seen;
  } outstanding_entry_t;

endpackage
