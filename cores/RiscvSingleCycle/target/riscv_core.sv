// Top-level single-cycle RISC-V core (RV32E)
// Harvard architecture with separate instruction and data memory interfaces
// Supports conditional generation for RISSP-style additive approach
module RiscvSingleCycle_riscv_core #(
    parameter bit ENABLE_MUL      = 1, // Enable multiply operations (M extension)
    parameter bit ENABLE_DIV      = 1, // Enable divide operations (M extension)
    parameter bit ENABLE_ADDER    = 1, // Enable adder (ADD/SUB/SLT/SLTU)
    parameter bit ENABLE_SHIFTER  = 1, // Enable barrel shifter (SLL/SRL/SRA)
    parameter bit ENABLE_BRANCHES = 1 // Enable branch comparator
) (
    input var logic clk  ,
    input var logic rst_n, // Active-low reset (configured via Veryl.toml)

    // Instruction memory interface (read-only)
    output var logic [32-1:0] imem_addr ,
    input  var logic [32-1:0] imem_rdata,

    // Data memory interface (read/write)
    output var logic [32-1:0] dmem_addr ,
    output var logic [32-1:0] dmem_wdata,
    input  var logic [32-1:0] dmem_rdata,
    output var logic          dmem_we   ,
    output var logic          dmem_re   
);
    // Control signals
    logic         branch    ;
    logic         jump      ;
    logic         mem_read  ;
    logic         mem_write ;
    logic         mem_to_reg;
    logic         alu_src   ;
    logic [2-1:0] alu_a_src ;
    logic         reg_write ;
    logic [4-1:0] alu_op    ;
    logic [3-1:0] imm_sel   ;
    logic [3-1:0] funct3    ;
    logic [2-1:0] pc_src    ;
    logic         mdu_en    ; // MDU enable signal (bugfix - was missing)

    // Instruction from memory
    logic [32-1:0] instruction;
    always_comb instruction = imem_rdata;

    // Control unit instantiation with parameters
    RiscvSingleCycle_control #(
        .ENABLE_MUL      (ENABLE_MUL     ),
        .ENABLE_DIV      (ENABLE_DIV     ),
        .ENABLE_ADDER    (ENABLE_ADDER   ),
        .ENABLE_SHIFTER  (ENABLE_SHIFTER ),
        .ENABLE_BRANCHES (ENABLE_BRANCHES)
    ) control_inst (
        .rst_n       (rst_n      ),
        .instruction (instruction),
        .branch      (branch     ),
        .jump        (jump       ),
        .mem_read    (mem_read   ),
        .mem_write   (mem_write  ),
        .mem_to_reg  (mem_to_reg ),
        .alu_src     (alu_src    ),
        .alu_a_src   (alu_a_src  ),
        .reg_write   (reg_write  ),
        .alu_op      (alu_op     ),
        .imm_sel     (imm_sel    ),
        .mdu_en      (mdu_en     ), // Bugfix: now connected
        .funct3      (funct3     ),
        .pc_src      (pc_src     )
    );

    // Datapath instantiation with parameters
    RiscvSingleCycle_datapath #(
        .ENABLE_MUL      (ENABLE_MUL     ),
        .ENABLE_DIV      (ENABLE_DIV     ),
        .ENABLE_ADDER    (ENABLE_ADDER   ),
        .ENABLE_SHIFTER  (ENABLE_SHIFTER ),
        .ENABLE_BRANCHES (ENABLE_BRANCHES)
    ) datapath_inst (
        .clk        (clk       ),
        .rst        (rst_n     ),
        .imem_addr  (imem_addr ),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr ),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .branch     (branch    ),
        .jump       (jump      ),
        .mem_to_reg (mem_to_reg),
        .alu_src    (alu_src   ),
        .alu_a_src  (alu_a_src ),
        .reg_write  (reg_write ),
        .alu_op     (alu_op    ),
        .imm_sel    (imm_sel   ),
        .funct3     (funct3    ),
        .pc_src     (pc_src    ),
        .mdu_en     (mdu_en     // Bugfix: now connected
        )    );

    // Memory control signals
    always_comb dmem_we = mem_write;
    always_comb dmem_re = mem_read;
endmodule
