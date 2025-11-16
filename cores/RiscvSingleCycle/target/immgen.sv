// Immediate Generator for RISC-V instruction formats
// Extracts and sign-extends immediates from instructions
module RiscvSingleCycle_immgen (
    input  var logic [32-1:0] instruction,
    input  var logic [3-1:0]  imm_sel    ,
    output var logic [32-1:0] imm    
);
    // Immediate format selection
    localparam logic [3-1:0] IMM_I = 3'b000; // I-type
    localparam logic [3-1:0] IMM_S = 3'b001; // S-type
    localparam logic [3-1:0] IMM_B = 3'b010; // B-type
    localparam logic [3-1:0] IMM_U = 3'b011; // U-type
    localparam logic [3-1:0] IMM_J = 3'b100; // J-type

    logic [32-1:0] imm_i;
    logic [32-1:0] imm_s;
    logic [32-1:0] imm_b;
    logic [32-1:0] imm_u;
    logic [32-1:0] imm_j;

    // I-type: imm[11:0] = instruction[31:20]
    always_comb imm_i = {{20{instruction[31]}}, instruction[31:20]};

    // S-type: imm[11:0] = {instruction[31:25], instruction[11:7]}
    always_comb imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

    // B-type: imm[12:0] = {instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0}
    always_comb imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};

    // U-type: imm[31:0] = {instruction[31:12], 12'b0}
    always_comb imm_u = {instruction[31:12], 12'h0};

    // J-type: imm[20:0] = {instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0}
    always_comb imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // Select immediate based on format
    always_comb imm = ((imm_sel == IMM_I) ? (
        imm_i
    ) : (imm_sel == IMM_S) ? (
        imm_s
    ) : (imm_sel == IMM_B) ? (
        imm_b
    ) : (imm_sel == IMM_U) ? (
        imm_u
    ) : (imm_sel == IMM_J) ? (
        imm_j
    ) : (
        32'h0
    ));
endmodule
