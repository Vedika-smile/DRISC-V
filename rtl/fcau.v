module fcau(
    input wire clk,
    input wire reset,
    input wire isFcau_id,          // This instruction is an FCAU op
    input wire [2:0] fcau_op,
    input wire [1:0] mode,          // 00=START, 01=ACC (MAX), 10=ACC_END (MIN)
    input wire signed [31:0] rs1,
    input wire signed [31:0] rs2,
    output wire signed [31:0] fcau_result 
);
    localparam VDOT   = 3'b000;
    localparam PIDACC = 3'b001;
    localparam FUSE   = 3'b010;
    localparam THRESH = 3'b011;

    localparam MODE_START   = 2'b00;
    localparam MODE_ACC     = 2'b01; // Maps to THRES_MAX when THRESH is active
    localparam MODE_ACC_END = 2'b10; // Maps to THRES_MIN when THRESH is active

    // Shared multiplier, Q16.16 fixed-point
    wire signed [63:0] raw_product = rs1 * rs2;
    wire signed [31:0] product_scaled = raw_product[47:16];

    // Internal accumulator — shared by VDOT and PIDACC
    reg signed [31:0] acc;

    wire signed [31:0] acc_next = (mode == MODE_START)   ? product_scaled 
                                : (mode == MODE_ACC)     ? acc + product_scaled 
                                : (mode == MODE_ACC_END) ? acc + product_scaled 
                                : acc;

    // Sequential state update for tracking accumulators
    always @(posedge clk or posedge reset) begin
        if(reset)
            acc <= 32'h00000000;
        else if (isFcau_id && (fcau_op == VDOT || fcau_op == PIDACC))
            acc <= acc_next;
    end

    // THRESH logic block
    reg signed [31:0] thresh_result;
    always @(*) begin
        case (mode)
            MODE_ACC:     thresh_result = (rs1 > rs2) ? rs2 : rs1; // THRES_MAX
            MODE_ACC_END: thresh_result = (rs1 < rs2) ? rs2 : rs1; // THRES_MIN
            default:      thresh_result = rs1;
        endcase
    end

    // Final result MUX — Selects output based on instruction opcode
    // Note: VDOT and PIDACC read directly from the combinational wire 'acc_next'
    // to satisfy your single-cycle, non-delayed writeback requirement.
    assign fcau_result = (fcau_op == VDOT)   ? acc_next :
                         (fcau_op == PIDACC) ? acc_next :
                         (fcau_op == THRESH) ? thresh_result :
                                               32'sd0;

endmodule