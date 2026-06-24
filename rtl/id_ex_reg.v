module id_ex_reg(
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,
    input  wire        flush,

    input  wire [31:0] pc_in,
    input  wire [31:0] pc_plus4_in,

    input  wire [31:0] rdout1_in,
    input  wire [31:0] rdout2_in,

    input  wire [31:0] imm_ext_in,

    input  wire [4:0]  rs1_in,
    input  wire [4:0]  rs2_in,
    input  wire [4:0]  rd_in,

    input  wire        regWrite_in,
    input  wire        memWrite_in,
    input  wire        memRead_in,
    input  wire        aluSrc_in,
    input  wire        branch_in,
    input  wire        memToReg_in,
    input  wire        jump_in,
    input  wire        pcSrc_in,
    input  wire [2:0]  funct3_in,
    input  wire [3:0]  aluControl_in,

    output reg  [31:0] pc_out,
    output reg  [31:0] pc_plus4_out,

    output reg  [31:0] rdout1_out,
    output reg  [31:0] rdout2_out,

    output reg  [31:0] imm_ext_out,

    output reg  [4:0]  rs1_out,
    output reg  [4:0]  rs2_out,
    output reg  [4:0]  rd_out,

    output reg         regWrite_out,
    output reg         memWrite_out,
    output reg         memRead_out,
    output reg         aluSrc_out,
    output reg         branch_out,
    output reg         memToReg_out,
    output reg         jump_out,
    output reg         pcSrc_out,
    output reg  [2:0]  funct3_out,
    output reg  [3:0]  aluControl_out
);

always @(posedge clk) begin
    if (reset) begin
        pc_out         <= 32'h00000000;
        pc_plus4_out   <= 32'h00000000;
        rdout1_out     <= 32'h00000000;
        rdout2_out     <= 32'h00000000;
        imm_ext_out    <= 32'h00000000;
        rs1_out        <= 5'b00000;
        rs2_out        <= 5'b00000;
        rd_out         <= 5'b00000;
        regWrite_out   <= 1'b0;
        memWrite_out   <= 1'b0;
        memRead_out    <= 1'b0;
        aluSrc_out     <= 1'b0;
        branch_out     <= 1'b0;
        memToReg_out   <= 1'b0;
        jump_out       <= 1'b0;
        pcSrc_out      <= 1'b0;
        funct3_out     <= 3'b000;
        aluControl_out <= 4'b0000;
    end

    // flush AND stall both insert a bubble into EX —
    // the only difference is WHY they happen, not WHAT they do here
    else if (flush) begin
        pc_out         <= pc_in;        // pass through, doesn't matter, no side effect
        pc_plus4_out   <= pc_plus4_in;
        rdout1_out     <= 32'h00000000;
        rdout2_out     <= 32'h00000000;
        imm_ext_out    <= 32'h00000000;
        rs1_out        <= 5'b00000;
        rs2_out        <= 5'b00000;
        rd_out         <= 5'b00000;
        regWrite_out   <= 1'b0;   // ← critical: bubble must not write
        memWrite_out   <= 1'b0;   // ← critical: bubble must not write memory
        memRead_out    <= 1'b0;
        aluSrc_out     <= 1'b0;
        branch_out     <= 1'b0;   // ← critical: bubble must not branch
        memToReg_out   <= 1'b0;
        jump_out       <= 1'b0;   // ← critical: bubble must not jump
        pcSrc_out      <= 1'b0;
        funct3_out     <= 3'b000;
        aluControl_out <= 4'b0000;
    end
    else if (stall) begin
        // A stall inserts a bubble ahead, but does NOT reset data addresses.
        // We clear control flags so the bubble doesn't write to memory/registers,
        // but we keep passing the PC/Register IDs for the forwarding unit to look at!
        pc_out         <= pc_in;
        pc_plus4_out   <= pc_plus4_in;
        rdout1_out     <= 32'h00000000;
        rdout2_out     <= 32'h00000000;
        imm_ext_out    <= 32'h00000000;
        rs1_out        <= rs1_in;  // CRITICAL: Keep register IDs intact for Hazard matching
        rs2_out        <= rs2_in;  // CRITICAL
        rd_out         <= rd_in;   // CRITICAL
        regWrite_out   <= 1'b0;    // Turn into NOP control-wise
        memWrite_out   <= 1'b0;
        memRead_out    <= 1'b0;
        aluSrc_out     <= 1'b0;
        branch_out     <= 1'b0;
        memToReg_out   <= 1'b0;
        jump_out       <= 1'b0;
        pcSrc_out      <= 1'b0;
        funct3_out     <= 3'b000;
        aluControl_out <= 4'b0000;
    end

    else begin
        pc_out         <= pc_in;
        pc_plus4_out   <= pc_plus4_in;
        rdout1_out     <= rdout1_in;
        rdout2_out     <= rdout2_in;
        imm_ext_out    <= imm_ext_in;
        rs1_out        <= rs1_in;
        rs2_out        <= rs2_in;
        rd_out         <= rd_in;
        regWrite_out   <= regWrite_in;
        memWrite_out   <= memWrite_in;
        memRead_out    <= memRead_in;
        aluSrc_out     <= aluSrc_in;
        branch_out     <= branch_in;
        memToReg_out   <= memToReg_in;
        jump_out       <= jump_in;
        pcSrc_out      <= pcSrc_in;
        funct3_out     <= funct3_in;
        aluControl_out <= aluControl_in;
    end
end

endmodule