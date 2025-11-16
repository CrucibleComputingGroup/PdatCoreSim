// ALU for RV32E
// Supports all integer arithmetic and logic operations
// Supports conditional generation for RISSP-style additive approach
module RiscvSingleCycle_alu #(
    parameter bit ENABLE_ADDER   = 1, // Enable adder (ADD/SUB/SLT/SLTU)
    parameter bit ENABLE_SHIFTER = 1 // Enable barrel shifter (SLL/SRL/SRA)
) (
    input  var logic [4-1:0]  op    ,
    input  var logic [32-1:0] a     ,
    input  var logic [32-1:0] b     ,
    output var logic [32-1:0] result,
    output var logic          zero  
);
    // ALU operation codes
    localparam logic [4-1:0] OP_ADD  = 4'b0000;
    localparam logic [4-1:0] OP_SUB  = 4'b0001;
    localparam logic [4-1:0] OP_SLL  = 4'b0010;
    localparam logic [4-1:0] OP_SLT  = 4'b0011;
    localparam logic [4-1:0] OP_SLTU = 4'b0100;
    localparam logic [4-1:0] OP_XOR  = 4'b0101;
    localparam logic [4-1:0] OP_SRL  = 4'b0110;
    localparam logic [4-1:0] OP_SRA  = 4'b0111;
    localparam logic [4-1:0] OP_OR   = 4'b1000;
    localparam logic [4-1:0] OP_AND  = 4'b1001;

    logic        [32-1:0] alu_result    ;
    logic        [32-1:0] adder_result  ;
    logic        [32-1:0] shifter_result;
    logic signed [32-1:0] a_signed      ;
    logic signed [32-1:0] b_signed      ;

    always_comb a_signed = a;
    always_comb b_signed = b;

    // Conditional generate for adder
    if (ENABLE_ADDER) begin :adder_gen
        logic signed [33-1:0] sub_result; // 33-bit for overflow detection

        always_comb begin
            adder_result = 32'h0;
            sub_result   = 33'h0;

            case (op) inside
                OP_ADD: begin
                    adder_result = a + b;
                end
                OP_SUB: begin
                    adder_result = a - b;
                end
                OP_SLT: begin
                    // Set if less than (signed) - use subtraction
                    sub_result   = {a_signed[31], a_signed} - {b_signed[31], b_signed};
                    adder_result = ((sub_result[32]) ? ( 32'h1 ) : ( 32'h0 ));
                end
                OP_SLTU: begin
                    // Set if less than (unsigned) - use subtraction
                    adder_result = (((a < b)) ? ( 32'h1 ) : ( 32'h0 ));
                end
                default: begin
                    adder_result = 32'h0;
                end
            endcase
        end
    end else begin :adder_gen
        always_comb adder_result = 32'h0;
    end

    // Conditional generate for shifter
    if (ENABLE_SHIFTER) begin :shifter_gen
        always_comb begin
            shifter_result = 32'h0;
            case (op) inside
                OP_SLL: begin
                    shifter_result = a << b[4:0];
                end
                OP_SRL: begin
                    shifter_result = a >> b[4:0];
                end
                OP_SRA: begin
                    shifter_result = a_signed >>> b[4:0];
                end
                default: begin
                    shifter_result = 32'h0;
                end
            endcase
        end
    end else begin :shifter_gen
        always_comb shifter_result = 32'h0;
    end

    // Combine results
    always_comb begin
        case (op) inside
            OP_ADD, OP_SUB, OP_SLT, OP_SLTU: begin
                alu_result = adder_result;
            end
            OP_SLL, OP_SRL, OP_SRA: begin
                alu_result = shifter_result;
            end
            OP_XOR: begin
                alu_result = a ^ b;
            end
            OP_OR: begin
                alu_result = a | b;
            end
            OP_AND: begin
                alu_result = a & b;
            end
            default: begin
                alu_result = 32'h0;
            end
        endcase
    end

    always_comb result = alu_result;
    always_comb zero   = alu_result == 0;
endmodule
