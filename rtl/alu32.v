module alu32(
	input  wire [31:0]	a,          // Operand A (from rs1)
	input  wire [31:0]	b,          // Operand B (from rs2 or Immediate)
	input  wire [3:0]	ALUControl, // Control signals from Control Unit
	output reg  [31:0]	result,     // Final calculation output
	output wire         zero        // High if result is exactly 0 (for branches)
);

	// Signed variants of inputs for proper signed comparisons and arithmetic
	wire signed [31:0]	a_signed, b_signed;

	assign a_signed = a;
	assign b_signed = b;

	// The Zero flag is critical for conditional branch execution
	assign zero = (result == 32'h00000000) ? 1'b1 : 1'b0;

	always @(*) begin
		case (ALUControl)
			4'b0000: result = a + b;                                    // ADD / LW / SW / AUIPC
			4'b0001: result = a - b;                                    // SUB
			4'b0010: result = a & b;                                    // AND / ANDI
			4'b0011: result = a | b;                                    // OR / ORI
			4'b0100: result = a ^ b;                                    // XOR / XORI
			4'b0101: result = a << b[4:0];                              // SLL / SLLI (Shift Left Logical)
			4'b0110: result = a >> b[4:0];                              // SRL / SRLI (Shift Right Logical)
			4'b0111: result = $signed(a) >>> b[4:0];                            // SRA / SRAI (Shift Right Arithmetic)
			//4'b1000: result = (a == b) ? 32'h1 : 32'h0;                 // BEQ / BNE helper
			4'b1001: result = (a < b) ? 32'h1 : 32'h0;                  // SLTU / SLTIU (Less Than Unsigned)
			4'b1010: result = (a_signed < b_signed) ? 32'h1 : 32'h0;    // SLT / SLTI (Less Than Signed)
			//4'b1011: result = (a >= b) ? 32'h1 : 32'h0;                 // BGEU / BLTU helper
			//4'b1100: result = (a_signed >= b_signed) ? 32'h1 : 32'h0;   // BGE / BLT helper
			4'b1101: result = (a_signed + b_signed) & 32'hFFFFFFFE;     // JALR address alignment
			default: result = 32'h00000000;                            // Default safe state
		endcase
	end

endmodule