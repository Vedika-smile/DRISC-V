module imm_gen(
    input  wire [31:0] inst,
    input  wire [2:0]  immSel,
    output reg  [31:0] imm_out
);

    always @(*) begin
        case (immSel)

            // I-type: ADDI, LW, JALR, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            3'b001: begin
                imm_out = { {20{inst[31]}}, inst[31:20] };
            end

            // S-type: SW, SH, SB
            3'b010: begin
                imm_out = { {20{inst[31]}}, inst[31:25], inst[11:7] };
            end

            // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
            3'b011: begin
                imm_out = { {19{inst[31]}}, inst[31], inst[7],
                            inst[30:25], inst[11:8], 1'b0 };
            end

            // U-type: LUI, AUIPC
            // Upper 20 bits go to imm[31:12], lower 12 bits are zero
            3'b100: begin
                imm_out = { inst[31:12], 12'b0 };
            end

            // J-type: JAL
            // Most scrambled encoding 
            3'b101: begin
                imm_out = { {11{inst[31]}}, inst[31], inst[19:12],
                            inst[20], inst[30:21], 1'b0 };
            end

            // Safe default
            default: begin
                imm_out = 32'h00000000;
            end

        endcase
    end

endmodule