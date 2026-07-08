module fcau(
    input wire clk,
    input wire reset,
    input wire isFcau_id,          // This instruction is an FCAU op
    input wire [2:0] fcau_op,
    input wire [1:0] mode,          // 00=START, 01=ACC (MAX), 10=ACC_END (MIN)
    input wire signed [31:0] rs1,
    input wire signed [31:0] rs2,
    input wire isEvent_id,
    output wire signed [31:0] fcau_result,
    output reg event_out
);
    localparam VDOT   = 3'b000;
    localparam PIDACC = 3'b001;
    localparam FUSE   = 3'b010;
    localparam THRESH = 3'b011;
    localparam SATADD = 3'b100;
    localparam VMAG   = 3'b101;
    localparam VNORM  = 3'b110;
    localparam EVENT = 3'b111;

    localparam MODE_START   = 2'b00;
    localparam MODE_ACC     = 2'b01; // Maps to THRES_MAX when THRESH is active
    localparam MODE_ACC_END = 2'b10; // Maps to THRES_MIN when THRESH is active
    localparam MODE_FINAL =2'b11; 

    // Shared Q16.16 multiplier (VDOT / PIDACC / FUSE / VMAG)
    wire signed [63:0] raw_product = rs1 * rs2;
    wire signed [31:0] product_scaled = raw_product[47:16];

    // Internal accumulator
    reg signed [31:0] acc;

    wire signed [31:0] acc_next = (mode == MODE_START)   ? product_scaled 
                                : (mode == MODE_ACC)     ? acc + product_scaled 
                                : (mode == MODE_ACC_END) ? acc + product_scaled 
                                : acc;

    //FUSE 
    wire signed [31:0] fuse_next = (mode == MODE_START) ? rs1 :                          // load initial state
                            acc + product_scaled;   // x + K*(z-z_hat)

    // Sequential state update for tracking accumulators
    always @(posedge clk) begin
        if(reset)
            acc <= 32'h00000000;
        else if (isFcau_id) begin
            if (fcau_op==VDOT || fcau_op == PIDACC) 
                acc <= acc_next;
            else if (fcau_op == FUSE)
                acc <= fuse_next;
        end
    end

    // THRESH logic block
    reg signed [31:0] thresh_result;
    always @(*) begin
        case (mode)
            MODE_ACC:     thresh_result = (rs1 > rs2) ? rs2 : rs1; // THRES_MAX //rs2 has max threshold value
            MODE_ACC_END: thresh_result = (rs1 < rs2) ? rs2 : rs1; // THRES_MIN  //rs2 has min threshold value 
            default:      thresh_result = rs1;
        endcase
    end

    //SATADD
    // Use the full signed 32-bit range for your Q16.16 fixed-point data
    parameter signed [31:0] SAT_MAX = 32'h7FFFFFFF; 
    parameter signed [31:0] SAT_MIN = 32'h80000000; 

    wire signed [33:0] sum = {rs1[31], rs1} + {rs2[31], rs2}; // Sign-extend to 34-bit to catch overflow
    wire signed [31:0] sat_result;

    assign sat_result = (sum > SAT_MAX) ? SAT_MAX : 
                        (sum < SAT_MIN) ? SAT_MIN : 
                        (rs1 + rs2);

    //EVENT
    always @(posedge clk) begin
        if (reset) event_out <= 1'b0;
        else if (isEvent_id && (fcau_op == EVENT)) 
            event_out <= rs1[0]; // Set the LED/GPIO state based on the register
    end

    // VMAG: Alpha-Max Beta-Min (3D, drop-min version)
    // alpha = 0.96043387 → Q16.16 = 62943 = 0xF5DF
    // beta  = 0.39782473 → Q16.16 = 26072 = 0x65D8

    // localparam signed [31:0] ALPHA_Q = 32'h0000F5DF; // 62943
    // localparam signed [31:0] BETA_Q  = 32'h000065D8; // 26072
    // Optimized for UAV distribution (RMS error ~4.9%)
    localparam signed [31:0] ALPHA_Q = 32'h0000ED5B; // 0.92716858
    localparam signed [31:0] BETA_Q  = 32'h00008016; // 0.50033018

     // Absolute values of inputs
    wire signed [31:0] abs_rs1 = rs1[31] ? -rs1 : rs1;
    wire signed [31:0] abs_rs2 = rs2[31] ? -rs2 : rs2;
 
    // vmag accumulator registers: store abs(vx) and abs(vy) on MODE_START
    reg signed [31:0] vmag_a; // stores first abs component
    reg signed [31:0] vmag_b; // stores second abs component
 
    always @(posedge clk) begin
        if (reset) begin
            vmag_a <= 32'd0;
            vmag_b <= 32'd0;
        end else if (isFcau_id && fcau_op == VMAG && mode == MODE_START) begin
            vmag_a <= abs_rs1; // |vx|
            vmag_b <= abs_rs2; // |vy|
        end
    end

    wire signed [31:0] abs_vz = (mode == MODE_ACC) ? abs_rs1 : 32'd0;

    // 3-comparator sorting network on the three stored/current abs values
    // Finds max and mid; drops min.
    // a=vmag_a(|vx|), b=vmag_b(|vy|), c=abs_vz(|vz|)
    wire signed [31:0] sn_a0 = vmag_a;
    wire signed [31:0] sn_b0 = vmag_b;
    wire signed [31:0] sn_c0 = abs_vz;
 
    // Comparator 1: ensure a >= b
    wire signed [31:0] sn_a1 = (sn_a0 >= sn_b0) ? sn_a0 : sn_b0;
    wire signed [31:0] sn_b1 = (sn_a0 >= sn_b0) ? sn_b0 : sn_a0;
 
    // Comparator 2: ensure a >= c → a is now max
    wire signed [31:0] vmag_max = (sn_a1 >= sn_c0) ? sn_a1 : sn_c0;
    wire signed [31:0] sn_c1   = (sn_a1 >= sn_c0) ? sn_c0 : sn_a1;

    // Comparator 3: ensure b >= c → b is now mid
    wire signed [31:0] vmag_mid = (sn_b1 >= sn_c1) ? sn_b1 : sn_c1;
   
   // Stage 2: register sorting network output
    reg signed [31:0] vmag_max_reg;
    reg signed [31:0] vmag_mid_reg;

    always @(posedge clk) begin
        if (reset) begin
            vmag_max_reg <= 32'd0;
            vmag_mid_reg <= 32'd0;
        end else if (isFcau_id && fcau_op == VMAG && mode == MODE_ACC) begin
            vmag_max_reg <= vmag_max;
            vmag_mid_reg <= vmag_mid;
        end
    end

    // Stage 3: multiply only
    reg signed [63:0] alpha_raw;
    reg signed [63:0] beta_raw;

    always @(posedge clk) begin
        if (reset) begin
            alpha_raw <= 64'd0;
            beta_raw  <= 64'd0;
        end else if (isFcau_id && fcau_op == VMAG && mode == MODE_ACC_END) begin
            alpha_raw <= vmag_max_reg * ALPHA_Q;
            beta_raw  <= vmag_mid_reg * BETA_Q;
        end
    end


    wire signed [31:0] vmag_result = (mode==MODE_FINAL) ? alpha_raw[47:16] + beta_raw[47:16] : 32'd0;
   
    // ── VNORM: reciprocal LUT (domain: integer magnitudes 0–15, Q16.16) ──
    reg [31:0] vnorm_lut [0:15];

    initial begin
        vnorm_lut[0]  = 32'h00010000; // guard/div-by-zero -> 1.0
        vnorm_lut[1]  = 32'h00010000; // 1/1
        vnorm_lut[2]  = 32'h00008000; // 1/2
        vnorm_lut[3]  = 32'h00005555; // 1/3
        vnorm_lut[4]  = 32'h00004000; // 1/4
        vnorm_lut[5]  = 32'h00003333; // 1/5
        vnorm_lut[6]  = 32'h00002AAA; // 1/6
        vnorm_lut[7]  = 32'h00002492; // 1/7
        vnorm_lut[8]  = 32'h00002000; // 1/8
        vnorm_lut[9]  = 32'h00001C71; // 1/9
        vnorm_lut[10] = 32'h00001999; // 1/10
        vnorm_lut[11] = 32'h00001745; // 1/11
        vnorm_lut[12] = 32'h00001555; // 1/12
        vnorm_lut[13] = 32'h000013B1; // 1/13
        vnorm_lut[14] = 32'h00001249; // 1/14
        vnorm_lut[15] = 32'h00001111; // 1/15
    end

    
    // ─────────────────────────────────────────
    // Fractional reciprocal LUT: for magnitudes < 1.0
    // Indexed by frac_part[15:12] (the value's fractional 1/16-slice)
    // index k stores reciprocal of (k/16), i.e. 16/k in Q16.16
    // ─────────────────────────────────────────
    reg [31:0] vnorm_lut_frac [0:15];
    initial begin
        vnorm_lut_frac[0]  = 32'h7FFFFFFF; // magnitude < 1/16 (~0.0625): saturate, out of safe range
        vnorm_lut_frac[1]  = 32'h00100000; // 1/(1/16)  = 16.0
        vnorm_lut_frac[2]  = 32'h00080000; // 1/(2/16)  = 8.0
        vnorm_lut_frac[3]  = 32'h00055555; // 1/(3/16)  = 5.3333
        vnorm_lut_frac[4]  = 32'h00040000; // 1/(4/16)  = 4.0
        vnorm_lut_frac[5]  = 32'h00033333; // 1/(5/16)  = 3.2
        vnorm_lut_frac[6]  = 32'h0002AAAB; // 1/(6/16)  = 2.6667
        vnorm_lut_frac[7]  = 32'h00024925; // 1/(7/16)  = 2.2857
        vnorm_lut_frac[8]  = 32'h00020000; // 1/(8/16)  = 2.0
        vnorm_lut_frac[9]  = 32'h0001C71C; // 1/(9/16)  = 1.7778
        vnorm_lut_frac[10] = 32'h0001999A; // 1/(10/16) = 1.6
        vnorm_lut_frac[11] = 32'h0001745D; // 1/(11/16) = 1.4545
        vnorm_lut_frac[12] = 32'h00015555; // 1/(12/16) = 1.3333
        vnorm_lut_frac[13] = 32'h00013B14; // 1/(13/16) = 1.2308
        vnorm_lut_frac[14] = 32'h00012492; // 1/(14/16) = 1.1429
        vnorm_lut_frac[15] = 32'h00011111; // 1/(15/16) = 1.0667
    end

    wire [15:0] int_part      = rs1[31:16];
    wire [15:0] frac_part     = rs1[15:0];
    wire [16:0] frac_rounded  = frac_part + 17'h0800;
    wire [31:0] vnorm_rounded = rs1 + 32'h00008000;
    reg signed [31:0] vnorm_recip; 

    // then separately, the sequential block:
    always @(posedge clk) begin
        if (reset)
            vnorm_recip <= 32'd0;
        else if (isFcau_id && fcau_op == VNORM && mode == MODE_START) begin
            if (rs1 == 32'd0)
                vnorm_recip <= 32'h7FFFFFFF;
            else if (int_part == 16'd0)
                vnorm_recip <= vnorm_lut_frac[frac_rounded[15:12]];
            else if (rs1 > 32'h000F0000)
                vnorm_recip <= 32'h00010000;
            else
                vnorm_recip <= vnorm_lut[vnorm_rounded[19:16]];
        end
    end

    wire signed [63:0] vnorm_raw    = rs1 * vnorm_recip;   
    wire signed [31:0] vnorm_scaled = vnorm_raw[47:16];
    // Final result MUX — Selects output based on instruction opcode
    // Note: VDOT and PIDACC read directly from the combinational wire 'acc_next'
    // to satisfy single-cycle, non-delayed writeback requirement.
    assign fcau_result = (fcau_op == VDOT)   ? acc_next :
                         (fcau_op == PIDACC) ? acc_next :
                         (fcau_op == FUSE)  ?  fuse_next :
                         (fcau_op == THRESH) ? thresh_result :
                         (fcau_op == SATADD) ? sat_result :
                         (fcau_op == VMAG)   ? vmag_result :
                         (fcau_op == VNORM) ? vnorm_scaled :
                                               32'sd0;

endmodule