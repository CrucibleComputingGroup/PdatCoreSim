// Formal verification properties for RV32E single-cycle processor
// Each RV32E instruction is verified for correct behavior

module riscv_properties (
    input logic clk,
    input logic rst,

    // Instruction memory interface
    input logic [31:0] imem_addr,
    input logic [31:0] imem_rdata,

    // Data memory interface
    input logic [31:0] dmem_addr,
    input logic [31:0] dmem_wdata,
    input logic [31:0] dmem_rdata,
    input logic dmem_we,
    input logic dmem_re
);

    // Access internal datapath state
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic [31:0] regs [16];

    assign pc = datapath_inst.pc;
    assign pc_next = datapath_inst.pc_next;
    assign regs = datapath_inst.regfile_inst.regs;

    // Instruction decode
    wire [6:0] opcode = imem_rdata[6:0];
    wire [3:0] rd = imem_rdata[10:7];   // RV32E uses lower 4 bits of rd field
    wire [2:0] funct3 = imem_rdata[14:12];
    wire [3:0] rs1 = imem_rdata[18:15];  // RV32E uses lower 4 bits of rs1 field
    wire [3:0] rs2 = imem_rdata[23:20];  // RV32E uses lower 4 bits of rs2 field
    wire [6:0] funct7 = imem_rdata[31:25];

    // Immediate values
    wire signed [31:0] imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
    wire signed [31:0] imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
    wire signed [31:0] imm_b = {{19{imem_rdata[31]}}, imem_rdata[31], imem_rdata[7], imem_rdata[30:25], imem_rdata[11:8], 1'b0};
    wire [31:0] imm_u = {imem_rdata[31:12], 12'h0};
    wire signed [31:0] imm_j = {{11{imem_rdata[31]}}, imem_rdata[31], imem_rdata[19:12], imem_rdata[20], imem_rdata[30:21], 1'b0};

    // Register values (handle x0 = 0)
    wire [31:0] rs1_val = (rs1 == 0) ? 32'h0 : regs[rs1];
    wire [31:0] rs2_val = (rs2 == 0) ? 32'h0 : regs[rs2];

    // Opcodes
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_REG    = 7'b0110011;

    //=================================================================
    // LUI - Load Upper Immediate
    //=================================================================
    property lui_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_LUI) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == $past(imm_u))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_lui: assert property (lui_correct);

    //=================================================================
    // AUIPC - Add Upper Immediate to PC
    //=================================================================
    property auipc_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_AUIPC) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(pc) + $past(imm_u)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_auipc: assert property (auipc_correct);

    //=================================================================
    // JAL - Jump and Link
    //=================================================================
    property jal_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_JAL) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(pc) + 4))) &&
            (pc == $past(pc) + $past(imm_j));
    endproperty
    assert_jal: assert property (jal_correct);

    //=================================================================
    // JALR - Jump and Link Register
    //=================================================================
    property jalr_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_JALR) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(pc) + 4))) &&
            (pc == (($past(rs1_val) + $past(imm_i)) & ~32'h1));
    endproperty
    assert_jalr: assert property (jalr_correct);

    //=================================================================
    // Branch Instructions
    //=================================================================

    // BEQ - Branch if Equal
    property beq_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b000) |=>
            ($past(rs1_val) == $past(rs2_val)) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_beq: assert property (beq_correct);

    // BNE - Branch if Not Equal
    property bne_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b001) |=>
            ($past(rs1_val) != $past(rs2_val)) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_bne: assert property (bne_correct);

    // BLT - Branch if Less Than (signed)
    property blt_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b100) |=>
            ($signed($past(rs1_val)) < $signed($past(rs2_val))) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_blt: assert property (blt_correct);

    // BGE - Branch if Greater or Equal (signed)
    property bge_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b101) |=>
            ($signed($past(rs1_val)) >= $signed($past(rs2_val))) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_bge: assert property (bge_correct);

    // BLTU - Branch if Less Than (unsigned)
    property bltu_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b110) |=>
            ($past(rs1_val) < $past(rs2_val)) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_bltu: assert property (bltu_correct);

    // BGEU - Branch if Greater or Equal (unsigned)
    property bgeu_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_BRANCH && funct3 == 3'b111) |=>
            ($past(rs1_val) >= $past(rs2_val)) ?
                (pc == $past(pc) + $past(imm_b)) :
                (pc == $past(pc) + 4);
    endproperty
    assert_bgeu: assert property (bgeu_correct);

    //=================================================================
    // Load Instructions
    //=================================================================
    property load_mem_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_LOAD) |->
            (dmem_re == 1'b1) &&
            (dmem_we == 1'b0) &&
            (dmem_addr == rs1_val + imm_i);
    endproperty
    assert_load_mem: assert property (load_mem_correct);

    property load_writeback_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_LOAD) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == $past(dmem_rdata))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_load_wb: assert property (load_writeback_correct);

    //=================================================================
    // Store Instructions
    //=================================================================
    property store_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_STORE) |->
            (dmem_we == 1'b1) &&
            (dmem_re == 1'b0) &&
            (dmem_addr == rs1_val + imm_s) &&
            (dmem_wdata == rs2_val);
    endproperty
    assert_store: assert property (store_correct);

    property store_no_writeback;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_STORE) |=>
            (pc == $past(pc) + 4);
    endproperty
    assert_store_pc: assert property (store_no_writeback);

    //=================================================================
    // ALU Immediate Instructions
    //=================================================================

    // ADDI
    property addi_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b000) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) + $past(imm_i)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_addi: assert property (addi_correct);

    // SLTI - Set Less Than Immediate (signed)
    property slti_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b010) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($signed($past(rs1_val)) < $signed($past(imm_i)) ? 32'h1 : 32'h0))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_slti: assert property (slti_correct);

    // SLTIU - Set Less Than Immediate Unsigned
    property sltiu_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b011) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) < $past(imm_i) ? 32'h1 : 32'h0))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_sltiu: assert property (sltiu_correct);

    // XORI
    property xori_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b100) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) ^ $past(imm_i)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_xori: assert property (xori_correct);

    // ORI
    property ori_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b110) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) | $past(imm_i)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_ori: assert property (ori_correct);

    // ANDI
    property andi_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b111) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) & $past(imm_i)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_andi: assert property (andi_correct);

    // SLLI - Shift Left Logical Immediate
    property slli_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b001) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) << $past(imm_i[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_slli: assert property (slli_correct);

    // SRLI - Shift Right Logical Immediate
    property srli_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b101 && funct7[5] == 1'b0) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) >> $past(imm_i[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_srli: assert property (srli_correct);

    // SRAI - Shift Right Arithmetic Immediate
    property srai_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_IMM && funct3 == 3'b101 && funct7[5] == 1'b1) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == $unsigned($signed($past(rs1_val)) >>> $past(imm_i[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_srai: assert property (srai_correct);

    //=================================================================
    // ALU Register Instructions
    //=================================================================

    // ADD
    property add_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b000 && funct7[5] == 1'b0) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) + $past(rs2_val)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_add: assert property (add_correct);

    // SUB
    property sub_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b000 && funct7[5] == 1'b1) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) - $past(rs2_val)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_sub: assert property (sub_correct);

    // SLL - Shift Left Logical
    property sll_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b001) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) << $past(rs2_val[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_sll: assert property (sll_correct);

    // SLT - Set Less Than (signed)
    property slt_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b010) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($signed($past(rs1_val)) < $signed($past(rs2_val)) ? 32'h1 : 32'h0))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_slt: assert property (slt_correct);

    // SLTU - Set Less Than Unsigned
    property sltu_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b011) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) < $past(rs2_val) ? 32'h1 : 32'h0))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_sltu: assert property (sltu_correct);

    // XOR
    property xor_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b100) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) ^ $past(rs2_val)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_xor: assert property (xor_correct);

    // SRL - Shift Right Logical
    property srl_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b101 && funct7[5] == 1'b0) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) >> $past(rs2_val[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_srl: assert property (srl_correct);

    // SRA - Shift Right Arithmetic
    property sra_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b101 && funct7[5] == 1'b1) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == $unsigned($signed($past(rs1_val)) >>> $past(rs2_val[4:0])))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_sra: assert property (sra_correct);

    // OR
    property or_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b110) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) | $past(rs2_val)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_or: assert property (or_correct);

    // AND
    property and_correct;
        @(posedge clk) disable iff (!rst)
        (opcode == OP_REG && funct3 == 3'b111) |=>
            (($past(rd) == 0) || (regs[$past(rd)] == ($past(rs1_val) & $past(rs2_val)))) &&
            (pc == $past(pc) + 4);
    endproperty
    assert_and: assert property (and_correct);

    //=================================================================
    // General Properties
    //=================================================================

    // x0 always reads as zero
    property x0_always_zero;
        @(posedge clk) disable iff (!rst)
        regs[0] == 32'h0;
    endproperty
    assert_x0_zero: assert property (nexttime x0_always_zero);

    // PC always points to instruction memory
    property pc_is_imem_addr;
        @(posedge clk) disable iff (!rst)
        imem_addr == pc;
    endproperty
    assert_pc_imem: assert property (pc_is_imem_addr);

endmodule

// Bind properties to the top-level core
bind RiscvSingleCycle_riscv_core riscv_properties props (
    .clk(clk),
    .rst(rst),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .dmem_rdata(dmem_rdata),
    .dmem_we(dmem_we),
    .dmem_re(dmem_re)
);
