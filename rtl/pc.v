module pc(
    input  wire 		clk,         // Clock signal
    input  wire 		reset,       // System reset (sets PC back to 0)
    input  wire 		branch,      // Branch signal from Control Unit
    input  wire 		zero,        // Zero flag from ALU (asserted if rs1 == rs2)
    input  wire [31:0] 	imm_ext,     // Sign-extended branch immediate from imm_gen
    output reg  [31:0] 	curr_pc      // Current instruction address sent to Instruction Memory
);

    wire [31:0] pc_plus_4;
    wire [31:0] pc_branch;
    wire [31:0] next_pc;
    wire        branch_taken;

    // 1. Calculate standard next address sequential step (+4 bytes)
    assign pc_plus_4 = curr_pc + 32'd4;

    // 2. Calculate branch target address 
    assign pc_branch = curr_pc + imm_ext;

    // 3. Condition check: Is it a branch instruction AND did the comparison match?
    assign branch_taken = branch & zero;

    // 4. Multiplexer to select the true next address
    assign next_pc = (branch_taken) ? pc_branch : pc_plus_4;

    // 5. Sequential block to update the PC register on the clock edge
    always @(posedge clk) begin
        if (reset) begin
            curr_pc <= 32'h00000000; // Reset vector (starts program at address 0)
        end else begin
            curr_pc <= next_pc;      // Update to new address
        end
    end
    // fututre implementation for JAL , other branch instruction 


endmodule