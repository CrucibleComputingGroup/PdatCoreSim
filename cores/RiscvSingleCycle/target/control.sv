// Control Unit for single-cycle RISC-V processor
// Decodes instructions and generates control signals
// Supports conditional generation for RISSP-style additive approach
module RiscvSingleCycle_control #(
    parameter bit ENABLE_MUL      = 1, // Enable multiply operations
    parameter bit ENABLE_DIV      = 1, // Enable divide operations
    parameter bit ENABLE_ADDER    = 1, // Enable adder (ADD/SUB/SLT/SLTU)
    parameter bit ENABLE_SHIFTER  = 1, // Enable barrel shifter (SLL/SRL/SRA)
    parameter bit ENABLE_BRANCHES = 1 // Enable branch comparator
) (
    input var logic          rst_n      , // Active-low reset signal (used for formal assumptions)
    input var logic [32-1:0] instruction,

    // Control signals
    output var logic         branch    ,
    output var logic         jump      ,
    output var logic         mem_read  ,
    output var logic         mem_write ,
    output var logic         mem_to_reg,
    output var logic         alu_src   ,
    output var logic [2-1:0] alu_a_src ,
    output var logic         reg_write ,
    output var logic [4-1:0] alu_op    ,
    output var logic [3-1:0] imm_sel   ,
    output var logic         mdu_en    , // Enable MDU (for M-extension instructions)

    // Branch condition signals
    output var logic [3-1:0] funct3,
    output var logic [2-1:0] pc_src
);
    // Instruction fields
    logic [7-1:0] opcode      ;
    logic [3-1:0] funct3_field;
    logic [7-1:0] funct7      ;

    always_comb opcode       = instruction[6:0];
    always_comb funct3_field = instruction[14:12];
    always_comb funct7       = instruction[31:25];

    // Opcodes
    localparam logic [7-1:0] OP_LUI    = 7'b0110111;
    localparam logic [7-1:0] OP_AUIPC  = 7'b0010111;
    localparam logic [7-1:0] OP_JAL    = 7'b1101111;
    localparam logic [7-1:0] OP_JALR   = 7'b1100111;
    localparam logic [7-1:0] OP_BRANCH = 7'b1100011;
    localparam logic [7-1:0] OP_LOAD   = 7'b0000011;
    localparam logic [7-1:0] OP_STORE  = 7'b0100011;
    localparam logic [7-1:0] OP_IMM    = 7'b0010011;
    localparam logic [7-1:0] OP_REG    = 7'b0110011; // Includes both ALU and MDU operations

    // ALU operation codes (from alu.veryl)
    localparam logic [4-1:0] ALU_ADD  = 4'b0000;
    localparam logic [4-1:0] ALU_SUB  = 4'b0001;
    localparam logic [4-1:0] ALU_SLL  = 4'b0010;
    localparam logic [4-1:0] ALU_SLT  = 4'b0011;
    localparam logic [4-1:0] ALU_SLTU = 4'b0100;
    localparam logic [4-1:0] ALU_XOR  = 4'b0101;
    localparam logic [4-1:0] ALU_SRL  = 4'b0110;
    localparam logic [4-1:0] ALU_SRA  = 4'b0111;
    localparam logic [4-1:0] ALU_OR   = 4'b1000;
    localparam logic [4-1:0] ALU_AND  = 4'b1001;

    // Immediate selection codes (from immgen.veryl)
    localparam logic [3-1:0] IMM_I = 3'b000;
    localparam logic [3-1:0] IMM_S = 3'b001;
    localparam logic [3-1:0] IMM_B = 3'b010;
    localparam logic [3-1:0] IMM_U = 3'b011;
    localparam logic [3-1:0] IMM_J = 3'b100;

    // PC source selection
    localparam logic [2-1:0] PC_PLUS4  = 2'b00;
    localparam logic [2-1:0] PC_BRANCH = 2'b01;
    localparam logic [2-1:0] PC_JALR   = 2'b10;

    // ALU A source selection
    localparam logic [2-1:0] ALU_A_RS1  = 2'b00;
    localparam logic [2-1:0] ALU_A_PC   = 2'b01;
    localparam logic [2-1:0] ALU_A_ZERO = 2'b10;

    logic         ctrl_branch    ;
    logic         ctrl_jump      ;
    logic         ctrl_mem_read  ;
    logic         ctrl_mem_write ;
    logic         ctrl_mem_to_reg;
    logic         ctrl_alu_src   ;
    logic [2-1:0] ctrl_alu_a_src ;
    logic         ctrl_reg_write ;
    logic [4-1:0] ctrl_alu_op    ;
    logic [3-1:0] ctrl_imm_sel   ;
    logic [2-1:0] ctrl_pc_src    ;
    logic         ctrl_mdu_en    ;

    always_comb begin
        // Default values
        ctrl_branch     = 0;
        ctrl_jump       = 0;
        ctrl_mem_read   = 0;
        ctrl_mem_write  = 0;
        ctrl_mem_to_reg = 0;
        ctrl_alu_src    = 0;
        ctrl_alu_a_src  = ALU_A_RS1;
        ctrl_reg_write  = 0;
        ctrl_alu_op     = ALU_ADD;
        ctrl_imm_sel    = IMM_I;
        ctrl_pc_src     = PC_PLUS4;
        ctrl_mdu_en     = 0;

        case (opcode) inside
            OP_LUI: begin
                // LUI: Load Upper Immediate
                ctrl_reg_write = 1;
                ctrl_imm_sel   = IMM_U;
                ctrl_alu_src   = 1;
                ctrl_alu_a_src = ALU_A_ZERO; // 0 + imm_u
                ctrl_alu_op    = ALU_ADD;
            end
            OP_AUIPC: begin
                // AUIPC: Add Upper Immediate to PC
                ctrl_reg_write = 1;
                ctrl_imm_sel   = IMM_U;
                ctrl_alu_src   = 1;
                ctrl_alu_a_src = ALU_A_PC; // PC + imm_u
                ctrl_alu_op    = ALU_ADD;
            end
            OP_JAL: begin
                // JAL: Jump and Link
                ctrl_jump      = 1;
                ctrl_reg_write = 1;
                ctrl_imm_sel   = IMM_J;
                ctrl_pc_src    = PC_BRANCH;
            end
            OP_JALR: begin
                // JALR: Jump and Link Register
                ctrl_jump      = 1;
                ctrl_reg_write = 1;
                ctrl_imm_sel   = IMM_I;
                ctrl_alu_src   = 1;
                ctrl_pc_src    = PC_JALR;
            end
            OP_BRANCH: begin
                // Branch instructions
                ctrl_branch  = 1;
                ctrl_imm_sel = IMM_B;
                ctrl_alu_op  = ALU_SUB;
            end
            OP_LOAD: begin
                // Load instructions
                ctrl_mem_read   = 1;
                ctrl_mem_to_reg = 1;
                ctrl_reg_write  = 1;
                ctrl_alu_src    = 1;
                ctrl_imm_sel    = IMM_I;
                ctrl_alu_op     = ALU_ADD;
            end
            OP_STORE: begin
                // Store instructions
                ctrl_mem_write = 1;
                ctrl_alu_src   = 1;
                ctrl_imm_sel   = IMM_S;
                ctrl_alu_op    = ALU_ADD;
            end
            OP_IMM: begin
                // Immediate ALU operations
                ctrl_reg_write = 1;
                ctrl_alu_src   = 1;
                ctrl_imm_sel   = IMM_I;

                case (funct3_field) inside
                    3'b000: ctrl_alu_op = ALU_ADD; // ADDI
                    3'b010: ctrl_alu_op = ALU_SLT; // SLTI
                    3'b011: ctrl_alu_op = ALU_SLTU; // SLTIU
                    3'b100: ctrl_alu_op = ALU_XOR; // XORI
                    3'b110: ctrl_alu_op = ALU_OR; // ORI
                    3'b111: ctrl_alu_op = ALU_AND; // ANDI
                    3'b001: ctrl_alu_op = ALU_SLL; // SLLI
                    3'b101: begin
                        // SRLI or SRAI
                        if (funct7[5]) begin
                            ctrl_alu_op = ALU_SRA;
                        end else begin
                            ctrl_alu_op = ALU_SRL;
                        end
                    end
                    default: ctrl_alu_op = ALU_ADD;
                endcase
            end
            OP_REG: begin
                // Register ALU operations or MDU operations (RV32M)
                ctrl_reg_write = 1;

                // Check if this is an M-extension instruction (funct7 = 0000001)
                if (funct7 == 7'b0000001) begin
                    // M-extension instruction (MUL/DIV/REM)
                    // Only enable MDU if the corresponding functional unit is present
                    if ((ENABLE_MUL || ENABLE_DIV)) begin
                        ctrl_mdu_en = 1;
                    end else begin
                        ctrl_mdu_en = 0; // Treat as illegal instruction
                    end
                    // funct3 is passed through as MDU op code
                end else begin
                    // Standard ALU instruction
                    ctrl_mdu_en = 0;

                    case (funct3_field) inside
                        3'b000: begin
                            // ADD or SUB
                            if (funct7[5]) begin
                                ctrl_alu_op = ALU_SUB;
                            end else begin
                                ctrl_alu_op = ALU_ADD;
                            end
                        end
                        3'b001: ctrl_alu_op = ALU_SLL; // SLL
                        3'b010: ctrl_alu_op = ALU_SLT; // SLT
                        3'b011: ctrl_alu_op = ALU_SLTU; // SLTU
                        3'b100: ctrl_alu_op = ALU_XOR; // XOR
                        3'b101: begin
                            // SRL or SRA
                            if (funct7[5]) begin
                                ctrl_alu_op = ALU_SRA;
                            end else begin
                                ctrl_alu_op = ALU_SRL;
                            end
                        end
                        3'b110 : ctrl_alu_op = ALU_OR; // OR
                        3'b111 : ctrl_alu_op = ALU_AND; // AND
                        default: ctrl_alu_op = ALU_ADD;
                    endcase
                end
            end
            default: begin
                // Invalid instruction - all signals stay at default
            end
        endcase
    end

    always_comb branch     = ctrl_branch;
    always_comb jump       = ctrl_jump;
    always_comb mem_read   = ctrl_mem_read;
    always_comb mem_write  = ctrl_mem_write;
    always_comb mem_to_reg = ctrl_mem_to_reg;
    always_comb alu_src    = ctrl_alu_src;
    always_comb alu_a_src  = ctrl_alu_a_src;
    always_comb reg_write  = ctrl_reg_write;
    always_comb alu_op     = ctrl_alu_op;
    always_comb imm_sel    = ctrl_imm_sel;
    always_comb funct3     = funct3_field;
    always_comb pc_src     = ctrl_pc_src;
    always_comb mdu_en     = ctrl_mdu_en;
endmodule
