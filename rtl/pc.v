module pc(
    input  wire        clk,
    input  wire        reset,
    input  wire        branch,
    input  wire        jump,
    input  wire [2:0]  funct3,
    input  wire        zero,
    input  wire        less,        // Clean relational input map
    input  wire [31:0] alu_result,
    input  wire [31:0] imm_ext,
    input  wire [31:0] pc_id,        // ← ADDED THIS: the EX-stage instruction's own PC
    output reg  [31:0] curr_pc
);

    wire [31:0] pc_plus_4;
    wire [31:0] pc_branch;
    wire [31:0] next_pc;
    wire        branch_taken;

    // Separate next-address options
    assign pc_plus_4 = curr_pc + 32'd4;
    assign pc_branch = pc_id + imm_ext;    // ← FIXED: use pc_id, not curr_pc

    // Relational checking logic matching the reference style
    assign branch_taken = branch & (
        (funct3 == 3'b000 &  zero)  |  // BEQ
        (funct3 == 3'b001 & ~zero)  |  // BNE
        (funct3 == 3'b100 &  less)  |  // BLT
        (funct3 == 3'b101 & ~less)  |  // BGE
        (funct3 == 3'b110 &  less)  |  // BLTU
        (funct3 == 3'b111 & ~less)     // BGEU
    );

    // Dynamic multiplexer prioritization
    assign next_pc = jump         ? alu_result  :  // JAL/JALR target address computed by ALU
                     branch_taken ? pc_branch   :  // Target offset jump address
                     pc_plus_4;                    // Normal sequence walk

    always @(posedge clk) begin
        if (reset)
            curr_pc <= 32'h00000000;
        else
            curr_pc <= next_pc;
    end

endmodule