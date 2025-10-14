// Copyright 2025
// Simple Data Memory Model for Ibex Test-Bench
//
// This module provides a simple behavioral data memory with:
// - Configurable size
// - Single-cycle response (no wait states)
// - Support for byte, halfword, and word accesses
// - Initialized with zeros

module simple_data_mem #(
  parameter int unsigned MEM_SIZE_BYTES = 65536,  // 64KB default
  parameter int unsigned BASE_ADDR      = 32'h00010000
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Data memory interface (connects to Ibex's data_* ports)
  input  logic        data_req_i,
  output logic        data_gnt_o,
  output logic        data_rvalid_o,
  input  logic        data_we_i,
  input  logic [3:0]  data_be_i,
  input  logic [31:0] data_addr_i,
  input  logic [31:0] data_wdata_i,
  output logic [31:0] data_rdata_o,
  output logic        data_err_o
);

  // Memory array (byte-addressed)
  logic [7:0] mem [MEM_SIZE_BYTES];

  // Request tracking for rvalid
  logic req_pending;
  logic [31:0] pending_addr;
  logic        pending_we;

  // ============================================================================
  // Request Handling
  // ============================================================================

  // Grant all requests immediately
  assign data_gnt_o = data_req_i;

  // Track pending requests (1-cycle latency)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_pending  <= 1'b0;
      pending_addr <= 32'h0;
      pending_we   <= 1'b0;
    end else begin
      req_pending  <= data_req_i && data_gnt_o;
      pending_addr <= data_addr_i;
      pending_we   <= data_we_i;
    end
  end

  assign data_rvalid_o = req_pending && !pending_we;

  // ============================================================================
  // Address Translation
  // ============================================================================

  function automatic logic [31:0] translate_addr(input logic [31:0] addr);
    // Remove base address to get memory array index
    return addr - BASE_ADDR;
  endfunction

  function automatic logic is_valid_addr(input logic [31:0] addr);
    logic [31:0] offset;
    offset = addr - BASE_ADDR;
    return (offset < MEM_SIZE_BYTES);
  endfunction

  // ============================================================================
  // Write Logic & Initialization
  // ============================================================================

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Initialize memory on reset
      for (int i = 0; i < MEM_SIZE_BYTES; i++) begin
        mem[i] <= 8'h00;
      end
    end else if (data_req_i && data_gnt_o && data_we_i) begin
      if (is_valid_addr(data_addr_i)) begin
        logic [31:0] offset;
        offset = translate_addr(data_addr_i);

        // Write bytes based on byte enable
        if (data_be_i[0]) mem[offset + 0] <= data_wdata_i[7:0];
        if (data_be_i[1]) mem[offset + 1] <= data_wdata_i[15:8];
        if (data_be_i[2]) mem[offset + 2] <= data_wdata_i[23:16];
        if (data_be_i[3]) mem[offset + 3] <= data_wdata_i[31:24];
      end else begin
        $warning("[DATA_MEM] Write to invalid address 0x%08h", data_addr_i);
      end
    end
  end

  // ============================================================================
  // Read Logic
  // ============================================================================

  always_comb begin
    data_rdata_o = 32'h0;
    data_err_o   = 1'b0;

    if (req_pending && !pending_we) begin
      if (is_valid_addr(pending_addr)) begin
        logic [31:0] offset;
        offset = translate_addr(pending_addr);

        // Read word (byte order: little endian)
        data_rdata_o = {mem[offset + 3], mem[offset + 2],
                        mem[offset + 1], mem[offset + 0]};
      end else begin
        data_err_o = 1'b1;
      end
    end
  end

  // ============================================================================
  // Simulation Messages
  // ============================================================================

  initial begin
    $display("[DATA_MEM] Initialized %0d bytes at base address 0x%08h",
             MEM_SIZE_BYTES, BASE_ADDR);
  end

endmodule
