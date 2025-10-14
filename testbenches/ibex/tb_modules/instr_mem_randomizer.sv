// Copyright 2025
// Randomized Instruction Memory Model for Ibex Test-Bench
//
// This module provides a memory interface that:
// 1. Phase 1 (cycles 0 to FLUSH_CYCLES-1): Returns NOP instructions to flush the pipeline
// 2. Phase 2 (cycles FLUSH_CYCLES+): Returns constrained-random instructions
//
// The randomization respects constraints defined in the instr_constraints class,
// which is generated from the DSL file and compiled separately.

module instr_mem_randomizer #(
  parameter int unsigned FLUSH_CYCLES = 100,  // Number of NOP cycles before randomization
  parameter bit          VERBOSE      = 1'b0  // Print randomized instructions
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // Instruction memory interface (connects to Ibex's instr_* ports)
  input  logic        instr_req_i,
  output logic        instr_gnt_o,
  output logic        instr_rvalid_o,
  input  logic [31:0] instr_addr_i,
  output logic [31:0] instr_rdata_o,
  output logic        instr_err_o,

  // Control signals
  output logic        phase2_active_o,  // Indicates we're in random phase
  output int unsigned cycle_count_o     // Current cycle count
);

  // NOP instruction: ADDI x0, x0, 0
  localparam logic [31:0] NOP_INSTR = 32'h00000013;

  // Cycle counter
  int unsigned cycle_count;

  // Phase tracking
  logic phase1_active;  // Reset/flush phase (NOPs)
  logic phase2_active;  // Random instruction phase

  // Randomization
  instr_constraints instr_rand;

  // Request tracking
  logic        req_pending;
  logic [31:0] pending_addr;

  // ============================================================================
  // Cycle Counter and Phase Control
  // ============================================================================

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
    end
  end

  assign phase1_active = (cycle_count < FLUSH_CYCLES);
  assign phase2_active = (cycle_count >= FLUSH_CYCLES);

  assign phase2_active_o = phase2_active;
  assign cycle_count_o = cycle_count;

  // ============================================================================
  // Instruction Memory Response Logic
  // ============================================================================

  // Grant requests immediately (no wait states for simplicity)
  assign instr_gnt_o = instr_req_i;

  // Track pending requests (1-cycle latency for rvalid)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_pending  <= 1'b0;
      pending_addr <= 32'h0;
    end else begin
      req_pending  <= instr_req_i && instr_gnt_o;
      pending_addr <= instr_addr_i;
    end
  end

  assign instr_rvalid_o = req_pending;
  assign instr_err_o    = 1'b0;  // No errors in this simple model

  // ============================================================================
  // Instruction Generation
  // ============================================================================

  // Randomized instruction word
  logic [31:0] random_instr;
  logic        randomize_success;

  // Initialize constraint object
  initial begin
    instr_rand = new();
  end

  // Generate random instruction when needed
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      random_instr <= NOP_INSTR;
    end else if (instr_req_i && instr_gnt_o && phase2_active) begin
      // Randomize for next cycle's rvalid
      randomize_success = instr_rand.randomize();

      if (!randomize_success) begin
        $error("[INSTR_MEM] Failed to randomize instruction at cycle %0d", cycle_count);
        random_instr <= NOP_INSTR;  // Fallback to NOP
      end else begin
        random_instr <= instr_rand.instr_word;

        if (VERBOSE) begin
          $display("[INSTR_MEM] Cycle %0d: addr=0x%08h instr=0x%08h",
                   cycle_count, pending_addr, instr_rand.instr_word);
        end
      end
    end
  end

  // Output instruction based on phase
  always_comb begin
    if (!req_pending) begin
      instr_rdata_o = NOP_INSTR;
    end else if (phase1_active) begin
      // Phase 1: Always return NOP
      instr_rdata_o = NOP_INSTR;
    end else begin
      // Phase 2: Return randomized instruction
      instr_rdata_o = random_instr;
    end
  end

  // ============================================================================
  // Simulation Messages
  // ============================================================================

  // Report phase transitions
  always @(posedge clk_i) begin
    if (cycle_count == 0 && rst_ni) begin
      $display("[INSTR_MEM] ========================================");
      $display("[INSTR_MEM] Randomized Instruction Memory Starting");
      $display("[INSTR_MEM] ========================================");
      $display("[INSTR_MEM] Phase 1 (Reset/Flush): Cycles 0-%0d (NOPs)", FLUSH_CYCLES-1);
      $display("[INSTR_MEM] Phase 2 (Random): Cycles %0d+", FLUSH_CYCLES);
    end

    if (cycle_count == FLUSH_CYCLES) begin
      $display("[INSTR_MEM] ========================================");
      $display("[INSTR_MEM] Entering Phase 2: Randomized Instructions");
      $display("[INSTR_MEM] ========================================");
    end
  end

endmodule
