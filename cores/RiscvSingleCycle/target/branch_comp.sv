// Branch Comparator for RISC-V branch instructions
// Compares two values based on branch condition
module RiscvSingleCycle_branch_comp (
    input  var logic [32-1:0] a           ,
    input  var logic [32-1:0] b           ,
    input  var logic [3-1:0]  funct3      ,
    output var logic          branch_taken
);
    // Branch funct3 codes
    localparam logic [3-1:0] BEQ  = 3'b000; // Branch if equal
    localparam logic [3-1:0] BNE  = 3'b001; // Branch if not equal
    localparam logic [3-1:0] BLT  = 3'b100; // Branch if less than (signed)
    localparam logic [3-1:0] BGE  = 3'b101; // Branch if greater or equal (signed)
    localparam logic [3-1:0] BLTU = 3'b110; // Branch if less than (unsigned)
    localparam logic [3-1:0] BGEU = 3'b111; // Branch if greater or equal (unsigned)

    logic                 taken   ;
    logic signed [32-1:0] a_signed;
    logic signed [32-1:0] b_signed;

    always_comb a_signed = a;
    always_comb b_signed = b;

    always_comb begin
        case (funct3) inside
            BEQ: begin
                taken = a == b;
            end
            BNE: begin
                taken = a != b;
            end
            BLT: begin
                taken = a_signed < b_signed;
            end
            BGE: begin
                taken = a_signed >= b_signed;
            end
            BLTU: begin
                taken = a < b;
            end
            BGEU: begin
                taken = a >= b;
            end
            default: begin
                taken = 0;
            end
        endcase
    end

    always_comb branch_taken = taken;
endmodule
//# sourceMappingURL=branch_comp.sv.map
