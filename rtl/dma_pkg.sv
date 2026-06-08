`timescale 1ns/1ps

package dma_pkg;

  // Phase 1/2 defaults. Later descriptor-based work can reuse this package,
  // but the current top-level design is a 32-bit, single-shot DMA MVP.
  parameter int ADDR_WIDTH        = 64;
  parameter int DATA_WIDTH        = 32;
  parameter int ID_WIDTH          = 4;
  parameter int STRB_WIDTH        = DATA_WIDTH / 8;

  localparam logic [31:0] VERSION_VALUE = 32'h0001_0000;

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

  parameter int DESC_WORDS        = 8;
  parameter int DESC_BYTES        = 32;
  parameter int COMP_WORDS        = 8;
  parameter int COMP_BYTES        = 32;
  parameter int FIFO_DEPTH        = 16;
  parameter int OUTSTANDING_DEPTH = 8;
  parameter int MAX_BURST_LEN     = 16;

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
