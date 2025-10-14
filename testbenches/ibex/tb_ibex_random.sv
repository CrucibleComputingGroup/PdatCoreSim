// Copyright 2025
// Randomized Test-Bench for Ibex Core
//
// This testbench performs two-phase simulation:
// 1. Phase 1 (Reset & Flush): Execute NOPs for FLUSH_CYCLES to reset and flush the pipeline
// 2. Phase 2 (Randomized): Execute constrained-random instructions
//
// VCD Generation:
// - ibex_reset_state.vcd: Captures state at cycle FLUSH_CYCLES (initial state for signal correspondence)
// - ibex_random_sim.vcd: Captures all ibex_core signals during Phase 2 (for equivalence analysis)

module tb_ibex_random;

  // ============================================================================
  // Parameters
  // ============================================================================

  // Simulation control
  parameter int unsigned FLUSH_CYCLES   = 100;   // Cycles for reset/flush phase
  parameter int unsigned RANDOM_CYCLES  = 1000;  // Cycles for random simulation phase
  parameter int unsigned CLK_PERIOD     = 10;    // Clock period in time units (10ns = 100MHz)

  // Ibex configuration
  parameter bit          PMPEnable      = 1'b0;
  parameter int unsigned PMPGranularity = 0;
  parameter int unsigned PMPNumRegions  = 4;
  parameter int unsigned MHPMCounterNum = 0;
  parameter bit          RV32E          = 1'b0;
  parameter bit          RV32M          = 1'b1;
  parameter bit          BranchTargetALU= 1'b0;
  parameter bit          WritebackStage = 1'b0;
  parameter bit          MemECC         = 1'b0;

  // Memory configuration
  parameter int unsigned DATA_MEM_SIZE  = 65536;      // 64KB
  parameter logic [31:0] DATA_BASE_ADDR = 32'h00010000;
  parameter logic [31:0] BOOT_ADDR      = 32'h00000080;

  // VCD files
  parameter string       VCD_STATE      = "ibex_reset_state.vcd";
  parameter string       VCD_TRACE      = "ibex_random_sim.vcd";

  // ============================================================================
  // Signals
  // ============================================================================

  // Clock and reset
  logic clk;
  logic rst_n;

  // Instruction memory interface
  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic        instr_err;

  // Data memory interface
  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;
  logic        data_err;

  // Control signals
  logic        phase2_active;
  int unsigned cycle_count;

  // ============================================================================
  // Clock Generation
  // ============================================================================

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // ============================================================================
  // Reset Generation
  // ============================================================================

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    $display("[TB] Reset released at time %0t", $time);
  end

  // ============================================================================
  // DUT: Ibex Core
  // ============================================================================

  ibex_core #(
    .PMPEnable        (PMPEnable),
    .PMPGranularity   (PMPGranularity),
    .PMPNumRegions    (PMPNumRegions),
    .MHPMCounterNum   (MHPMCounterNum),
    .RV32E            (RV32E),
    .RV32M            (RV32M ? ibex_pkg::RV32MFast : ibex_pkg::RV32MNone),
    .RV32B            (ibex_pkg::RV32BNone),
    .BranchTargetALU  (BranchTargetALU),
    .WritebackStage   (WritebackStage),
    .MemECC           (MemECC),
    .RegFileDataWidth (32)
  ) dut (
    .clk_i                (clk),
    .rst_ni               (rst_n),

    .hart_id_i            (32'h0),
    .boot_addr_i          (BOOT_ADDR),

    // Instruction memory interface
    .instr_req_o          (instr_req),
    .instr_gnt_i          (instr_gnt),
    .instr_rvalid_i       (instr_rvalid),
    .instr_addr_o         (instr_addr),
    .instr_rdata_i        (instr_rdata),
    .instr_err_i          (instr_err),

    // Data memory interface
    .data_req_o           (data_req),
    .data_gnt_i           (data_gnt),
    .data_rvalid_i        (data_rvalid),
    .data_we_o            (data_we),
    .data_be_o            (data_be),
    .data_addr_o          (data_addr),
    .data_wdata_o         (data_wdata),
    .data_rdata_i         (data_rdata),
    .data_err_i           (data_err),

    // Register file interface (external RF not used)
    .dummy_instr_id_o     (),
    .dummy_instr_wb_o     (),
    .rf_raddr_a_o         (),
    .rf_raddr_b_o         (),
    .rf_waddr_wb_o        (),
    .rf_we_wb_o           (),
    .rf_wdata_wb_ecc_o    (),
    .rf_rdata_a_ecc_i     (32'h0),
    .rf_rdata_b_ecc_i     (32'h0),

    // ICache interface (not used)
    .ic_tag_req_o         (),
    .ic_tag_write_o       (),
    .ic_tag_addr_o        (),
    .ic_tag_wdata_o       (),
    .ic_tag_rdata_i       ('{default: '0}),
    .ic_data_req_o        (),
    .ic_data_write_o      (),
    .ic_data_addr_o       (),
    .ic_data_wdata_o      (),
    .ic_data_rdata_i      ('{default: '0}),
    .ic_scr_key_valid_i   (1'b0),
    .ic_scr_key_req_o     (),

    // Interrupt inputs
    .irq_software_i       (1'b0),
    .irq_timer_i          (1'b0),
    .irq_external_i       (1'b0),
    .irq_fast_i           (15'b0),
    .irq_nm_i             (1'b0),
    .irq_pending_o        (),

    // Debug interface
    .debug_req_i          (1'b0),
    .crash_dump_o         (),
    .double_fault_seen_o  (),

    // CPU control signals
    .fetch_enable_i       (ibex_pkg::IbexMuBiOn),
    .alert_minor_o        (),
    .alert_major_internal_o (),
    .alert_major_bus_o    (),
    .core_busy_o          ()
  );

  // ============================================================================
  // Instruction Memory: Randomizer
  // ============================================================================

  instr_mem_randomizer #(
    .FLUSH_CYCLES (FLUSH_CYCLES),
    .VERBOSE      (1'b0)
  ) i_instr_mem (
    .clk_i            (clk),
    .rst_ni           (rst_n),

    .instr_req_i      (instr_req),
    .instr_gnt_o      (instr_gnt),
    .instr_rvalid_o   (instr_rvalid),
    .instr_addr_i     (instr_addr),
    .instr_rdata_o    (instr_rdata),
    .instr_err_o      (instr_err),

    .phase2_active_o  (phase2_active),
    .cycle_count_o    (cycle_count)
  );

  // ============================================================================
  // Data Memory: Simple Behavioral Model
  // ============================================================================

  simple_data_mem #(
    .MEM_SIZE_BYTES (DATA_MEM_SIZE),
    .BASE_ADDR      (DATA_BASE_ADDR)
  ) i_data_mem (
    .clk_i          (clk),
    .rst_ni         (rst_n),

    .data_req_i     (data_req),
    .data_gnt_o     (data_gnt),
    .data_rvalid_o  (data_rvalid),
    .data_we_i      (data_we),
    .data_be_i      (data_be),
    .data_addr_i    (data_addr),
    .data_wdata_i   (data_wdata),
    .data_rdata_o   (data_rdata),
    .data_err_o     (data_err)
  );

  // ============================================================================
  // VCD Control: Two-Phase Dumping
  // ============================================================================

  // Internal VCD file (will be split post-simulation)
  localparam string VCD_COMBINED = "ibex_combined.vcd";

  initial begin
    $display("[TB] ========================================");
    $display("[TB] Starting Randomized Test-Bench for Ibex");
    $display("[TB] ========================================");
    $display("[TB] Phase 1: Reset/Flush (%0d cycles)", FLUSH_CYCLES);
    $display("[TB] Phase 2: Random Simulation (%0d cycles)", RANDOM_CYCLES);
    $display("[TB]");
    $display("[TB] VCD files (created post-simulation):");
    $display("[TB]   - %s (state at cycle %0d)", VCD_STATE, FLUSH_CYCLES);
    $display("[TB]   - %s (full trace during Phase 2)", VCD_TRACE);
    $display("[TB] ========================================");

    // Start VCD dump from cycle 0
    $dumpfile(VCD_COMBINED);
    $dumpvars(0, dut);

    // Wait for flush phase to complete
    wait (cycle_count == FLUSH_CYCLES);
    @(posedge clk);
    $display("[TB] Reached cycle %0d (post-reset/flush state)", cycle_count);

    // Run for specified number of random cycles
    repeat (RANDOM_CYCLES) @(posedge clk);

    // Finish simulation
    $dumpflush;
    $display("[TB] ========================================");
    $display("[TB] Simulation Complete");
    $display("[TB] ========================================");
    $display("[TB] Total cycles: %0d", cycle_count);
    $display("[TB] Combined VCD will be split into:");
    $display("[TB]   - %s (initial state at cycle %0d)", VCD_STATE, FLUSH_CYCLES);
    $display("[TB]   - %s (random execution)", VCD_TRACE);
    $finish;
  end

  // ============================================================================
  // Timeout Watchdog
  // ============================================================================

  initial begin
    #(CLK_PERIOD * (FLUSH_CYCLES + RANDOM_CYCLES + 100));
    $error("[TB] TIMEOUT: Simulation exceeded expected duration");
    $finish;
  end

endmodule
