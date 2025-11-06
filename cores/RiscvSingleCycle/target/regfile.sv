// Register File for RV32E (16 registers)
// Dual-read port, single-write port synchronous register file
module RiscvSingleCycle_regfile (
    input var logic clk,
    input var logic rst,

    // Read ports
    input  var logic [4-1:0]  rs1_addr,
    input  var logic [4-1:0]  rs2_addr,
    output var logic [32-1:0] rs1_data,
    output var logic [32-1:0] rs2_data,

    // Write port
    input var logic [4-1:0]  rd_addr,
    input var logic [32-1:0] rd_data,
    input var logic          we 
);
    // 16 registers for RV32E (x0-x15)
    logic [32-1:0] regs [0:16-1];

    // x0 is hardwired to zero
    always_comb rs1_data = ((rs1_addr == 0) ? ( 32'h0 ) : ( regs[rs1_addr] ));
    always_comb rs2_data = ((rs2_addr == 0) ? ( 32'h0 ) : ( regs[rs2_addr] ));

    // Synchronous write
    always_ff @ (posedge clk, negedge rst) begin
        if (!rst) begin
            for (int unsigned i = 0; i < 16; i++) begin
                regs[i] <= 0;
            end
        end else begin
            // Write to register if enabled and not x0
            if (we && rd_addr != 0) begin
                regs[rd_addr] <= rd_data;
            end
            // Always force x0 to zero
            regs[0] <= 0;
        end
    end
endmodule
//# sourceMappingURL=regfile.sv.map
