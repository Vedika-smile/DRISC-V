module top_pipeline(
    input wire clk,
    input wire reset,
    output wire event_out
);

    //================================================================
    // IF STAGE — live signals
    //================================================================
    wire [31:0] curr_pc;
    wire [31:0] instruction;
    wire [31:0] pc_id, pc_plus4_id, rdout1_id, rdout2_id, imm_ext_id;
    wire [4:0]  rs1_id, rs2_id, rd_id;
    wire        regWrite_id, memWrite_id, memRead_id, aluSrc_id, branch_id, memToReg_id, jump_id, pcSrc_id, isLui_id, isFcau_id, isEvent_id;
    wire [2:0]  funct3_id, fcau_op_id;
    wire [3:0]  aluControl_id;
    wire [1:0] mode_id;

    pc program_counter (
        .clk        (clk),
        .reset      (reset),
        .branch     (branch_id),
        .jump       (jump_id),
        .funct3     (funct3_id),
        .zero       (zero),
        .alu_result (alu_result),
        .imm_ext    (imm_ext_id),
        .less       (alu_less),
        .pc_id      (pc_id),
        .curr_pc    (curr_pc)
    );

    inst_mem i_m (
        .addr        (curr_pc),
        .instruction (instruction)
    );

    //================================================================
    // IF/ID REGISTER OUTPUTS — these feed the ID stage
    //================================================================
    wire [31:0] pc_if;          //_if means if o/p
    wire [31:0] inst_if;

    if_id_reg if_id (
        .clk      (clk),
        .reset    (reset),
        .stall    (1'b0),     
        .flush    (flush),     
        .pc_in    (curr_pc),
        .inst     (instruction),
        .pc_out   (pc_if),
        .inst_out (inst_if)
    );

    //================================================================
    // ID STAGE — decode using inst_if (the IF/ID OUTPUT, not live wire)
    //================================================================
    wire [6:0]  opcode = inst_if[6:0];
    wire [4:0]  rd     = inst_if[11:7];
    wire [2:0]  funct3 = inst_if[14:12];
    wire [4:0]  rs1    = inst_if[19:15];
    wire [4:0]  rs2    = inst_if[24:20];
    wire [6:0]  funct7 = inst_if[31:25];

    wire regWrite, memWrite, memRead, aluSrc, branch, memToReg, jump, pcSrc, isFcau, isLui, isEvent;
    wire [2:0] immSel, fcau_op;
    wire [3:0] aluControl;
    wire [1:0] mode;

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
        .jump       (jump),
        .immSel     (immSel),
        .aluControl (aluControl),
        .pcSrc      (pcSrc),
        .isLui     (isLui),
        .isFcau    (isFcau),
        .fcau_op  (fcau_op),
        .mode     (mode),
        .isEvent (isEvent)
    );

    wire [31:0] imm_ext;
    imm_gen IMMGEN (
        .inst    (inst_if),
        .immSel  (immSel),
        .imm_out (imm_ext)
    );

    // Register file read happens HERE in ID stage, using LIVE rs1/rs2
    // (decoded from inst_if, the CURRENT instruction in ID)
    wire [31:0] rdout1, rdout2;
    wire [31:0] writeBackData_wb;   // comes from MEM/WB stage, defined later
    wire [4:0]  rd_wb;
    wire        regWrite_wb;

    regfile r_f (
        .clk    (clk),
        .reset  (reset),
        .w_enb  (regWrite_wb),       // write happens using MEM/WB stage signals
        .rs1    (rs1),               // read happens using CURRENT ID stage signals
        .rs2    (rs2),
        .rd     (rd_wb),
        .data   (writeBackData_wb),
        .rdout1 (rdout1),
        .rdout2 (rdout2)
    );

    wire [31:0] pc_plus4 = pc_if + 32'd4;   // PC+4 of instruction currently in ID

    //================================================================
    // ID/EX REGISTER OUTPUTS — these feed the EX stage
    //================================================================

    id_ex_reg id_ex (
        .clk            (clk),
        .reset          (reset),
        .stall          (1'b0),
        .flush          (flush),

        .pc_in          (pc_if),
        .pc_plus4_in    (pc_plus4),
        .rdout1_in      (rdout1),
        .rdout2_in      (rdout2),  
        .imm_ext_in     (imm_ext),
        .rs1_in         (rs1),
        .rs2_in         (rs2),
        .rd_in          (rd),       

        .regWrite_in    (regWrite),
        .memWrite_in    (memWrite),
        .memRead_in     (memRead),
        .aluSrc_in      (aluSrc),
        .branch_in      (branch),
        .memToReg_in    (memToReg),
        .jump_in        (jump),
        .pcSrc_in       (pcSrc),
        .funct3_in      (funct3),
        .aluControl_in  (aluControl),
        .isLui_in (isLui),
        .isFcau_in (isFcau),
        .fcau_op_in (fcau_op),
        .mode_in (mode),
        .isEvent_in (isEvent),

        .pc_out         (pc_id),
        .pc_plus4_out   (pc_plus4_id),
        .rdout1_out     (rdout1_id),
        .rdout2_out     (rdout2_id),
        .imm_ext_out    (imm_ext_id),
        .rs1_out        (rs1_id),
        .rs2_out        (rs2_id),
        .rd_out         (rd_id),

        .regWrite_out   (regWrite_id),
        .memWrite_out   (memWrite_id),
        .memRead_out    (memRead_id),
        .aluSrc_out     (aluSrc_id),
        .branch_out     (branch_id),
        .memToReg_out   (memToReg_id),
        .jump_out       (jump_id),
        .pcSrc_out      (pcSrc_id),
        .funct3_out     (funct3_id),
        .aluControl_out (aluControl_id),
        .isLui_out (isLui_id),
        .isFcau_out  (isFcau_id),
        .fcau_op_out  (fcau_op_id),
        .mode_out    (mode_id),
        .isEvent_out (isEvent_id)
    );

    //================================================================
    // EX STAGE — uses ONLY _id signals (the ID/EX register outputs)
    //================================================================
    wire [31:0] alu_a = pcSrc_id ? pc_id :
                        isLui_id ? 32'h00000000 :
                        forwardA  ? writeBackData_wb : rdout1_id;        //checkkkk

    wire [31:0] alu_b = aluSrc_id ? imm_ext_id :
                        forwardB  ? writeBackData_wb : rdout2_id;


    wire [31:0] alu_result;
    wire zero;

    wire branch_taken = branch_id & (
    (funct3_id == 3'b000 &  zero)        |
    (funct3_id == 3'b001 & ~zero)        |
    (funct3_id == 3'b100 &  alu_less)    |
    (funct3_id == 3'b101 & ~alu_less)    |
    (funct3_id == 3'b110 &  alu_less)    |
    (funct3_id == 3'b111 & ~alu_less)
    );
    wire flush = branch_taken | jump_id;

    alu32 ALU (
        .a          (alu_a),
        .b          (alu_b),
        .ALUControl (aluControl_id),
        .result     (alu_result),
        .zero       (zero)
    );

    wire alu_less = alu_result[0];  // connected in pc

    wire signed [31:0] fcau_result;

    fcau FCAU (
        .clk       (clk),
        .reset      (reset),
        .isFcau_id  (isFcau_id),
        .fcau_op   (fcau_op_id),
        .mode    (mode_id),
        .rs1     (alu_a),    // reuse the SAME forwarded alu_a (handles hazards automatically!)
        .rs2    (alu_b),    // reuse the SAME forwarded alu_b
        .fcau_result (fcau_result),
        .isEvent_id(isEvent_id),
        .event_out(event_out)
    );

    //================================================================
    // EX/MEM REGISTER OUTPUTS — these feed the MEM/WB stage
    //================================================================
    wire [31:0] pc_plus4_ex, alu_result_ex, write_data_ex;
    wire [4:0]  rd_ex;
    wire        regWrite_ex, memWrite_ex, memRead_ex, memToReg_ex, jump_ex;
    wire [31:0] rdout2_forwarded = forwardB ? writeBackData_wb : rdout2_id;
    wire isFcau_ex;   // carried through ex_mem_reg, same pattern as memToReg_ex
    wire signed [31:0] fcau_result_ex;   // carried through ex_mem_reg


    ex_mem_reg mem_reg (
        .clk            (clk),
        .reset          (reset),

        .pc_plus4_in    (pc_plus4_id),
        .alu_result_in  (alu_result),
        .write_data_in  (rdout2_forwarded),     // rs2 value, needed for SW
        .rd_in          (rd_id),

        .regWrite_in    (regWrite_id),
        .memWrite_in    (memWrite_id),
        .memRead_in     (memRead_id),
        .memToReg_in    (memToReg_id),
        .jump_in        (jump_id),

        .isFcau_in (isFcau_id),
        .fcau_result_in (fcau_result),

        .pc_plus4_out   (pc_plus4_ex),
        .alu_result_out (alu_result_ex),
        .write_data_out (write_data_ex),
        .rd_out         (rd_ex),

        .regWrite_out   (regWrite_ex),
        .memWrite_out   (memWrite_ex),
        .memRead_out    (memRead_ex),
        .memToReg_out   (memToReg_ex),
        .jump_out       (jump_ex),

        .isFcau_out  (isFcau_ex),
        .fcau_result_out (fcau_result_ex)
    );

    //================================================================
    // MEM/WB STAGE — uses ONLY _ex signals (the EX/MEM register outputs)
    //================================================================
    wire [31:0] readData;

    data_mem DMEM (
        .clk       (clk),
        .memRead   (memRead_ex),
        .memWrite  (memWrite_ex),
        .addr      (alu_result_ex),
        .writeData (write_data_ex),
        .readData  (readData)
    );

    // Writeback MUX — this feeds BACK into regfile (declared earlier)
    assign writeBackData_wb = jump_ex   ? pc_plus4_ex :
                                isFcau_ex ? fcau_result_ex :
                               memToReg_ex ? readData     :
                                             alu_result_ex;
    assign rd_wb       = rd_ex;
    assign regWrite_wb = regWrite_ex;

     //================================== HAZARD =============================
    wire forwardA, forwardB;

    forwarding_unit fu (
        .rs1_ex          (rs1_id),
        .rs2_ex          (rs2_id),
        .rd_exmem        (rd_ex),
        .regWrite_exmem  (regWrite_ex),
        .forwardA        (forwardA),
        .forwardB        (forwardB)   
    );

endmodule