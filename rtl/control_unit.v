module control_unit(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        regWrite,
    output reg        memWrite,
    output reg        memRead,
    output reg        aluSrc, // for input b in alu if =1 then b=imm or b=rdout2
    output reg        branch,
    output reg        memToReg,
    output reg        jump,
    output reg [2:0]  immSel,
    output reg [3:0]  aluControl,
    output reg        pcSrc,  // 1 = ALU input A is PC (for JAL, AUIPC)
    output reg        isLui,
    output reg        isFcau,  ///instead writing combinational logic directly in  top 
    output reg [2:0]  fcau_op,
    output reg [1:0]  mode,
    output reg    isEvent
);

    always @(*) begin
        // Reset defaults at the start of every evaluation to avoid latches
        regWrite   = 0;
        memWrite   = 0;
        memRead    = 0;
        aluSrc     = 0; 
        branch     = 0;
        memToReg   = 0;
        jump       = 0;
        immSel     = 3'b000;
        aluControl = 4'b0000;
        pcSrc      = 0;
        isLui=0;
        isFcau =0;
        fcau_op = 3'b000;
        mode = 2'b00;
        isEvent=0;

        case(opcode)

            // R-type
            7'b0110011: begin
                regWrite = 1;
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

            // I-type ALU
            7'b0010011: begin
                regWrite = 1;
                aluSrc   = 1;
                immSel   = 3'b001;
                case(funct3)
                    3'b000: aluControl = 4'b0000; // ADDI
                    3'b111: aluControl = 4'b0010; // ANDI
                    3'b110: aluControl = 4'b0011; // ORI
                    3'b100: aluControl = 4'b0100; // XORI
                    3'b010: aluControl = 4'b1010; // SLTI
                    3'b011: aluControl = 4'b1001; // SLTIU
                    3'b001: aluControl = 4'b0101; // SLLI
                    3'b101: aluControl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI / SRLI
                    default: aluControl = 4'b0000;
                endcase
            end

            // LW
            7'b0000011: begin
                regWrite   = 1;
                memRead    = 1;
                memToReg   = 1; // Routes Memory output instead of ALU to rd
                aluSrc     = 1;
                immSel     = 3'b001; // I-Type standard extension
                aluControl = 4'b0000; // Base address computation (rs1 + imm)
            end

            // SW
            7'b0100011: begin
                memWrite   = 1;
                aluSrc     = 1;
                immSel     = 3'b010; // S-Type immediate extension
                aluControl = 4'b0000; // Store address computation (rs1 + imm)
            end

            // Branch
            7'b1100011: begin
                branch = 1;
                immSel = 3'b011; // B-Type branch extension
                case(funct3)
                    3'b000: aluControl = 4'b0001; // BEQ (Evaluates SUB comparison)
                    3'b001: aluControl = 4'b0001; // BNE
                    3'b100: aluControl = 4'b1010; // BLT
                    3'b101: aluControl = 4'b1010; // BGE
                    3'b110: aluControl = 4'b1001; // BLTU
                    3'b111: aluControl = 4'b1001; // BGEU
                    default: aluControl = 4'b0001;
                endcase
            end

            // LUI
            7'b0110111: begin 
                regWrite   = 1'b1;
                aluSrc     = 1'b1;   // Bring immediate into ALU input B
                memToReg   = 1'b0;   // Ensure register writeback pulls from ALU, not memory
                immSel     = 3'b100; // U-Type extension mask
                aluControl = 4'b0011; // Set to OR mode (effectively passes Operand B directly if Input A is 0)
                isLui =1;
            end

            // AUIPC
            7'b0010111: begin
                regWrite   = 1;
                aluSrc     = 1;      // Input B = immediate
                pcSrc      = 1;      // Input A = Current Program Counter (PC)
                immSel     = 3'b100; // U-Type extension mask
                aluControl = 4'b0000; // Add immediate + PC
            end

            // JAL
            7'b1101111: begin
                regWrite   = 1;
                jump       = 1;      // Assert jump logic in main datapath
                immSel     = 3'b101; // J-Type jump extension mask
                aluSrc     = 1;      // Link calculation requires immediate add
                pcSrc      = 1;      // Base calculation needs PC
                aluControl = 4'b0000; // Target = PC + immediate
            end

            // JALR
            7'b1100111: begin
                regWrite   = 1;
                jump       = 1;
                aluSrc     = 1;      // Input B = immediate
                pcSrc      = 0;      // Input A = Reg rs1 (Base target address)
                immSel     = 3'b001; // I-Type immediate extension
                aluControl = 4'b0000; // Target = rs1 + immediate
            end

            7'b0001011: begin   // D-ISA custom-0 opcode
                isFcau = 1;
                fcau_op = funct3;  

                case (funct3)
                    3'b000, 3'b001: begin   // VDOT or PIDACC — use accumulation modes
                        case (funct7[1:0])
                            2'b00: begin mode = 2'b00; regWrite = 0; end  // START
                            2'b01: begin mode = 2'b01; regWrite = 0; end  // ACC
                            2'b10: begin mode = 2'b10; regWrite = 1; end  // ACC_END
                            default: begin mode = 2'b00; regWrite = 0; isEvent = 0; end
                        endcase
                    end
                    3'b011: begin
                        case(funct7[1:0])
                            2'b01: begin mode = 2'b01; regWrite =1; end //max_thresh
                            2'b10: begin mode=2'b10; regWrite = 1; end //min_thresh
                            default: begin
                                regWrite=0; 
                                mode=2'b00;
                                isEvent=0;
                            end 
                        endcase
                    end
                    3'b010: begin   // FUSE
                        case (funct7[1:0])
                            2'b00: begin mode = 2'b00; regWrite =0; end
                            2'b01, 2'b10: begin mode= 2'b01; regWrite =1; end
                            default : begin
                               mode=2'b00;
                               regWrite =0; 
                               isEvent = 0;
                            end
                        endcase
                    end
                    3'b100: regWrite=1;   //SATADD
                    3'b101: begin        //VMAG 
                        case (funct7[1:0])
                            2'b00: begin mode = 2'b00; regWrite =0; end
                            2'b01: begin mode= 2'b01; regWrite =0; end
                            2'b10: begin mode=2'b10; regWrite=0; end
                            2'b11: begin mode=2'b11; regWrite=1; end
                            default : begin
                               mode=2'b00;
                               regWrite =0; 
                               isEvent = 0;
                            end
                        endcase
                    end
                    3'b110: begin  // VNORM
                        case (funct7[1:0])
                            2'b00: begin mode = 2'b00; regWrite = 0; isEvent = 0; end // MODE_START: load reciprocal from |v|, no writeback
                            2'b01: begin mode = 2'b01; regWrite = 1; isEvent = 0; end // vx_norm
                            2'b10: begin mode = 2'b10; regWrite = 1; isEvent = 0; end // vy_norm
                            2'b11: begin mode = 2'b11; regWrite = 1; isEvent = 0; end // vz_norm (MODE_VN_END)
                        endcase
                    end
                    3'b111: isEvent =1;   //EVENT
                    default: begin
                        mode = 2'b00;
                        regWrite = 0;
                        isEvent = 0;
                    end
                endcase
            end

            default: begin
                // Left empty intentionally to catch fallback states safely via start defaults
            end

        endcase
    end

endmodule