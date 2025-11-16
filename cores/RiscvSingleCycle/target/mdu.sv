// Multiply/Divide Unit for RV32M extension
// Combinational implementation (suitable for single-cycle core)
// Supports conditional generation for RISSP-style additive approach
module RiscvSingleCycle_mdu #(
    parameter bit ENABLE_MUL = 1, // Enable multiply operations
    parameter bit ENABLE_DIV = 1 // Enable divide operations
) (
    input  var logic [3-1:0]  op    , // MDU operation selection
    input  var logic [32-1:0] a     , // Operand A (rs1)
    input  var logic [32-1:0] b     , // Operand B (rs2)
    output var logic [32-1:0] // MDU result
     result
);

    // MDU operation codes (matches funct3 encoding)
    localparam logic [3-1:0] OP_MUL    = 3'b000; // MUL: multiply low 32 bits
    localparam logic [3-1:0] OP_MULH   = 3'b001; // MULH: multiply high (signed x signed)
    localparam logic [3-1:0] OP_MULHSU = 3'b010; // MULHSU: multiply high (signed x unsigned)
    localparam logic [3-1:0] OP_MULHU  = 3'b011; // MULHU: multiply high (unsigned x unsigned)
    localparam logic [3-1:0] OP_DIV    = 3'b100; // DIV: signed divide
    localparam logic [3-1:0] OP_DIVU   = 3'b101; // DIVU: unsigned divide
    localparam logic [3-1:0] OP_REM    = 3'b110; // REM: signed remainder
    localparam logic [3-1:0] OP_REMU   = 3'b111; // REMU: unsigned remainder

    localparam logic [8-1:0] MASK_MUL    = 1; // MUL: multiply low 32 bits
    localparam logic [8-1:0] MASK_MULH   = 2; // MULH: multiply high (signed x signed)
    localparam logic [8-1:0] MASK_MULHSU = 4; // MULHSU: multiply high (signed x unsigned)
    localparam logic [8-1:0] MASK_MULHU  = 8; // MULHU: multiply high (unsigned x unsigned)
    localparam logic [8-1:0] MASK_DIV    = 16; // DIV: signed divide
    localparam logic [8-1:0] MASK_DIVU   = 32; // DIVU: unsigned divide
    localparam logic [8-1:0] MASK_REM    = 64; // REM: signed remainder
    localparam logic [8-1:0] MASK_REMU   = 128; // REMU: unsigned remainder

    logic [8-1:0] mul_one_hot;
    always_comb begin
        mul_one_hot = '0;
        case (op) inside
            OP_MUL: begin
                mul_one_hot = MASK_MUL;
            end
            OP_MULH: begin
                mul_one_hot = MASK_MULH;
            end
            OP_MULHSU: begin
                mul_one_hot = MASK_MULHSU;
            end
            OP_MULHU: begin
                mul_one_hot = MASK_MULHU;
            end
            OP_DIV: begin
                mul_one_hot = MASK_DIV;
            end
            OP_DIVU: begin
                mul_one_hot = MASK_DIVU;
            end
            OP_REM: begin
                mul_one_hot = MASK_REM;
            end
            OP_REMU: begin
                mul_one_hot = MASK_REMU;
            end
        endcase
    end

    logic [32-1:0] mdu_result;
    logic [32-1:0] mul_result;
    logic [32-1:0] div_result;

    // Conditional generate for multiplier
    if (ENABLE_MUL) begin :mul_gen
        logic [64-1:0] mul_full;
        logic [64-1:0] mula    ;
        logic [64-1:0] mulb    ;

        always_comb begin
            case (mul_one_hot) inside
                OP_MUL, OP_MULHU: begin
                    // All multiply operations: compute full 64-bit product
                    mula = {32'h0, a};
                    mulb = {32'h0, b};
                end
                OP_MULHSU: begin
                    mula = {{32{a[31]}}, a};
                    mulb = {32'h0, b};
                end
                OP_MULH: begin
                    mula = {{32{a[31]}}, a};
                    mulb = {{32{b[31]}}, b};
                end
                default: begin
                    mula = {32'h0, a};
                    mulb = {32'h0, b};
                end
            endcase
            mul_full = mula * mulb;
            case (mul_one_hot) inside
                OP_MUL: begin
                    mul_result = mul_full[31:0];
                end
                default: begin
                    mul_result = mul_full[63:32];
                end
            endcase
        end
    end else begin :mul_gen
        always_comb mul_result = 32'h0;
    end

    // Conditional generate for divider
    if (ENABLE_DIV) begin :div_gen
        logic [32-1:0] quotient ;
        logic [32-1:0] remainder;

        always_comb begin
            div_result = 32'h0;
            quotient   = 32'h0;
            remainder  = 32'h0;

            case (op) inside
                OP_DIV, OP_DIVU: begin
                    if (b == 0) begin
                        div_result = 32'hFFFFFFFF;
                    end else begin
                        quotient   = a / b;
                        div_result = quotient;
                    end
                end
                OP_REM, OP_REMU: begin
                    if (b == 0) begin
                        div_result = a;
                    end else begin
                        remainder  = a % b;
                        div_result = remainder;
                    end
                end
                default: begin
                    div_result = 32'h0;
                end
            endcase
        end
    end else begin :div_gen
        always_comb div_result = 32'h0;
    end

    // Select result based on operation
    always_comb begin
        case (op) inside
            OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU: begin
                mdu_result = mul_result;
            end
            OP_DIV, OP_DIVU, OP_REM, OP_REMU: begin
                mdu_result = div_result;
            end
            default: begin
                mdu_result = 32'h0;
            end
        endcase
    end

    always_comb result = mdu_result;
endmodule
