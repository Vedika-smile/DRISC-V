module control_unit(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg regWrite,
    output reg memWrite,
    output reg memRead,
    output reg aluSrc,
    output reg branch,
    output reg memToReg,
    output reg [2:0] immSel,
    output reg [3:0] aluControl
);

    always @(*) begin

        // Safe defaults — prevents latches
        regWrite   = 0;
        memWrite   = 0;
        memRead    = 0;
        aluSrc     = 0;
        branch     = 0;
        memToReg   = 0;
        immSel     = 3'b000;
        aluControl = 4'b0000;

        case(opcode)

            // R-Type: ADD, SUB
            7'b0110011: begin
                regWrite = 1;
                aluSrc   = 0;
                case({funct7, funct3})
                    10'b0000000_000: aluControl = 4'b0000; // ADD
                    10'b0100000_000: aluControl = 4'b0001; // SUB
                    10'b0000000_111: aluControl = 4'b0010; // AND
                    10'b0000000_110: aluControl = 4'b0011; // OR
                    10'b0000000_100: aluControl = 4'b0100; // XOR
                    10'b0000000_001: aluControl = 4'b0101; // SLL
                    10'b0000000_101: aluControl = 4'b0110; // SRL
                    10'b0100000_101: aluControl = 4'b0111; // SRA
                    10'b0000000_010: aluControl = 4'b1010; // SLT
                    10'b0000000_011: aluControl = 4'b1001; // SLTU
                    default:         aluControl = 4'b0000;
                endcase
            end

            // I-Type: ADDI
            7'b0010011: begin
                regWrite   = 1;
                aluSrc     = 1;
                immSel     = 3'b001;
                aluControl = 4'b0000; // ADD (rs1 + imm)
            end

            // Load: LW
            7'b0000011: begin
                regWrite   = 1;
                memRead    = 1;
                memToReg   = 1;
                aluSrc     = 1;
                immSel     = 3'b001; // I-type immediate
                aluControl = 4'b0000; // ADD (base + offset)
            end

            // Store: SW
            7'b0100011: begin
                memWrite   = 1;
                aluSrc     = 1;
                immSel     = 3'b010; // S-type immediate
                aluControl = 4'b0000; // ADD (base + offset)
            end

            // Branch: BEQ
            7'b1100011: begin
                branch     = 1;
                aluSrc     = 0;
                immSel     = 3'b011; // B-type immediate
                aluControl = 4'b0001; // SUB (check zero flag)
            end

            default: begin
                // All signals already set to 0 above
            end

        endcase
    end

endmodule