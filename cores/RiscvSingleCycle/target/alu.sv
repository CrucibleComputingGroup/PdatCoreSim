// ALU for RV32E
// Supports all integer arithmetic and logic operations
module RiscvSingleCycle_alu (
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

    logic        [32-1:0] alu_result;
    logic signed [32-1:0] a_signed  ;
    logic signed [32-1:0] b_signed  ;

    always_comb a_signed = a;
    always_comb b_signed = b;

    // ALU operations
    always_comb begin
        case (op) inside
            OP_ADD: begin
                alu_result = a + b;
            end
            OP_SUB: begin
                alu_result = a - b;
            end
            OP_SLL: begin
                // Shift left logical
                alu_result = a << b[4:0];
            end
            OP_SLT: begin
                // Set less than (signed)
                alu_result = ((a_signed < b_signed) ? ( 32'h1 ) : ( 32'h0 ));
            end
            OP_SLTU: begin
                // Set less than unsigned
                alu_result = ((a < b) ? ( 32'h1 ) : ( 32'h0 ));
            end
            OP_XOR: begin
                alu_result = a ^ b;
            end
            OP_SRL: begin
                // Shift right logical
                alu_result = a >> b[4:0];
            end
            OP_SRA: begin
                // Shift right arithmetic
                alu_result = a_signed >>> b[4:0];
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
//# sourceMappingURL=alu.sv.map
