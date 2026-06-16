module top ( 
    input wire clk, 
    input wire reset
    );

    wire [31:0] curr_pc; //current address of instruction 
    wire [31:0] instruction; //instruction

    wire [6:0]  opcode  = instruction[6:0];
    wire [4:0]  rd      = instruction[11:7];
    wire [2:0]  funct3  = instruction[14:12];
    wire [4:0]  rs1     = instruction[19:15];
    wire [4:0]  rs2     = instruction[24:20];
    wire [6:0]  funct7  = instruction[31:25];

    // Control unit output wires
    wire regWrite;
    wire memWrite;
    wire memRead;
    wire aluSrc;
    wire branch;
    wire memToReg;
    wire [2:0]  immSel;
    wire [3:0]  aluControl;

    // Register file wires
    wire [31:0] rdout1;   // rs1 value
    wire [31:0] rdout2;   // rs2 value

    // Immediate generator wire
    wire [31:0] imm_ext;

    // ALU wires
    wire [31:0] alu_b;     // ALU input B (rs2 or immediate)
    wire [31:0] alu_result;
    wire        zero;

    // Data memory wire
    wire [31:0] readData;

    // Writeback wire — what goes back into register file
    wire [31:0] writeBackData;

    //---------MUXES-------------
    // ALU input B mux: aluSrc=0 → rs2, aluSrc=1 → immediate
    assign alu_b = (aluSrc) ? imm_ext : rdout2;

    // Writeback mux: memToReg=0 → ALU result, memToReg=1 → memory data
    assign writeBackData = (memToReg) ? readData : alu_result;

    //module instantiation 
    pc program_counter (
        .clk(clk),
        .reset(reset),
        .branch(branch),       // From Control Unit
        .zero(zero),         // From ALU
        .imm_ext(imm_ext),      // From Immediate Generator
        .curr_pc(curr_pc) // Goes straight to instruction memory input address
    );

    //pc-> instruction address goes to instruction_memory
    inst_mem i_m (
        .addr(curr_pc),
        .instruction(instruction)
    );

    //decoder fetches opcode and gives control logic 
    control_unit CU (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .regWrite   (regWrite),
        .memWrite   (memWrite),
        .memRead    (memRead),
        .aluSrc     (aluSrc),
        .branch     (branch),
        .memToReg   (memToReg),
        .immSel     (immSel),
        .aluControl (aluControl)
    );

    //reg file reads rada from register 
    regfile r_f(
        .clk(clk),
        .reset(reset),
        .w_enb(regWrite),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .data(writeBackData), //write back data
        .rdout1(rdout1),
        .rdout2(rdout2)
    );

    //immediate generator gives constant value as per type 
    imm_gen IMMGEN (
        .inst       (instruction),
        .immSel     (immSel),
        .imm_out    (imm_ext)
    );

    //now ALU computes 
    alu32 ALU (
        .a          (rdout1),
        .b          (alu_b),
        .ALUControl (aluControl),
        .result     (alu_result),
        .zero       (zero)
    );

    // Data Memory
    data_mem DMEM (
        .clk        (clk),
        .memRead    (memRead),
        .memWrite   (memWrite),
        .addr       (alu_result),
        .writeData  (rdout2),
        .readData   (readData)
    );

endmodule 

