// Datapath for single-cycle RISC-V processor
// Supports conditional generation for RISSP-style additive approach
module RiscvSingleCycle_datapath #(
    parameter bit ENABLE_MUL      = 1, // Enable multiply operations
    parameter bit ENABLE_DIV      = 1, // Enable divide operations
    parameter bit ENABLE_ADDER    = 1, // Enable adder (ADD/SUB/SLT/SLTU)
    parameter bit ENABLE_SHIFTER  = 1, // Enable barrel shifter (SLL/SRL/SRA)
    parameter bit ENABLE_BRANCHES = 1 // Enable branch comparator
) (
    input var logic clk,
    input var logic rst,

    // Instruction memory interface
    output var logic [32-1:0] imem_addr ,
    input  var logic [32-1:0] imem_rdata,

    // Data memory interface
    output var logic [32-1:0] dmem_addr ,
    output var logic [32-1:0] dmem_wdata,
    input  var logic [32-1:0] dmem_rdata,

    // Control signals from control unit
    input var logic         branch    ,
    input var logic         jump      ,
    input var logic         mem_to_reg,
    input var logic         alu_src   ,
    input var logic [2-1:0] alu_a_src ,
    input var logic         reg_write ,
    input var logic [4-1:0] alu_op    ,
    input var logic [3-1:0] imm_sel   ,
    input var logic [3-1:0] funct3    ,
    input var logic [2-1:0] pc_src    ,
    input var logic         // Enable MDU for M-extension
     mdu_en
);
    // PC source selection
    localparam logic [2-1:0] PC_PLUS4  = 2'b00;
    localparam logic [2-1:0] PC_BRANCH = 2'b01;
    localparam logic [2-1:0] PC_JALR   = 2'b10;

    // ALU A source selection
    localparam logic [2-1:0] ALU_A_RS1  = 2'b00;
    localparam logic [2-1:0] ALU_A_PC   = 2'b01;
    localparam logic [2-1:0] ALU_A_ZERO = 2'b10;

    // Program Counter
    logic [32-1:0] pc       ;
    logic [32-1:0] pc_next  ;
    logic [32-1:0] pc_plus4 ;
    logic [32-1:0] pc_target;

    // Instruction fields
    logic [32-1:0] instruction;
    logic [4-1:0]  rs1_addr   ;
    logic [4-1:0]  rs2_addr   ;
    logic [4-1:0]  rd_addr    ;

    // Register file signals
    logic [32-1:0] rs1_data;
    logic [32-1:0] rs2_data;
    logic [32-1:0] rd_data ;

    // Immediate
    logic [32-1:0] imm;

    // ALU signals
    logic [32-1:0] alu_a     ;
    logic [32-1:0] alu_b     ;
    logic [32-1:0] alu_result;
    logic          alu_zero  ;

    // MDU signals
    logic [32-1:0] mdu_result;

    // Branch signals
    logic branch_taken;
    logic take_branch ;

    // Instruction from memory
    always_comb instruction = imem_rdata;
    always_comb imem_addr   = pc;

    // Extract instruction fields (RV32E uses 4-bit register addresses)
    always_comb rs1_addr = instruction[18:15];
    always_comb rs2_addr = instruction[23:20];
    always_comb rd_addr  = instruction[10:7];

    // Register file instantiation
    RiscvSingleCycle_regfile regfile_inst (
        .clk      (clk      ),
        .rst      (rst      ),
        .rs1_addr (rs1_addr ),
        .rs2_addr (rs2_addr ),
        .rs1_data (rs1_data ),
        .rs2_data (rs2_data ),
        .rd_addr  (rd_addr  ),
        .rd_data  (rd_data  ),
        .we       (reg_write)
    );

    // Immediate generator instantiation
    RiscvSingleCycle_immgen immgen_inst (
        .instruction (instruction),
        .imm_sel     (imm_sel    ),
        .imm         (imm        )
    );

    // ALU input selection
    always_comb begin
        case (alu_a_src) inside
            ALU_A_RS1: begin
                alu_a = rs1_data;
            end
            ALU_A_PC: begin
                alu_a = pc;
            end
            ALU_A_ZERO: begin
                alu_a = 32'h0;
            end
            default: begin
                alu_a = rs1_data;
            end
        endcase
    end
    always_comb alu_b = ((alu_src) ? ( imm ) : ( rs2_data ));

    // ALU instantiation with parameters
    RiscvSingleCycle_alu #(
        .ENABLE_ADDER   (ENABLE_ADDER  ),
        .ENABLE_SHIFTER (ENABLE_SHIFTER)
    ) alu_inst (
        .op     (alu_op    ),
        .a      (alu_a     ),
        .b      (alu_b     ),
        .result (alu_result),
        .zero   (alu_zero  )
    );

    // MDU instantiation (RV32M extension)
    RiscvSingleCycle_mdu #(
        .ENABLE_MUL (ENABLE_MUL),
        .ENABLE_DIV (ENABLE_DIV)
    ) mdu_inst (
        .op     (funct3    ), // MDU operation is encoded in funct3
        .a      (rs1_data  ), // MDU uses rs1 directly (not alu_a)
        .b      (rs2_data  ), // MDU uses rs2 directly (not alu_b)
        .result (mdu_result)
    );

    // Branch comparator instantiation
    RiscvSingleCycle_branch_comp branch_comp_inst (
        .a            (rs1_data    ),
        .b            (rs2_data    ),
        .funct3       (funct3      ),
        .branch_taken (branch_taken)
    );

    // Data memory interface
    always_comb dmem_addr  = alu_result;
    always_comb dmem_wdata = rs2_data;

    // Execution unit result selection (ALU or MDU)
    logic [32-1:0] exec_result;
    always_comb exec_result = ((mdu_en) ? ( mdu_result ) : ( alu_result ));

    // Write-back data selection
    always_comb rd_data = ((jump) ? ( pc_plus4 ) : (mem_to_reg) ? ( dmem_rdata ) : ( exec_result ));

    // PC calculation
    always_comb pc_plus4  = pc + 4;
    always_comb pc_target = pc + imm;

    // Branch decision
    always_comb take_branch = branch & branch_taken;

    // PC next value selection
    always_comb begin
        case (pc_src) inside
            PC_PLUS4: begin
                pc_next = ((take_branch) ? ( pc_target ) : ( pc_plus4 ));
            end
            PC_BRANCH: begin
                // JAL
                pc_next = pc_target;
            end
            PC_JALR: begin
                // JALR: (rs1 + imm) & ~1
                pc_next = alu_result & 32'hFFFFFFFE;
            end
            default: begin
                pc_next = pc_plus4;
            end
        endcase
    end

    // PC register
    always_ff @ (posedge clk, negedge rst) begin
        if (!rst) begin
            pc <= 0;
        end else begin
            pc <= pc_next;
        end
    end
endmodule
