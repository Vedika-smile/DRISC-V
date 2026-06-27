module fcau_tb;
    reg clk, reset, isFcau_id;
    reg [2:0] fcau_op;
    reg [1:0] mode;
    reg signed [31:0] rs1, rs2;
    wire signed [31:0] fcau_result;

    fcau UUT(
        .clk(clk), .reset(reset), .isFcau_id(isFcau_id),
        .fcau_op(fcau_op), .mode(mode),
        .rs1(rs1), .rs2(rs2), .fcau_result(fcau_result)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; reset = 1; isFcau_id = 0;
        fcau_op = 3'b000;
        rs1 = 0; rs2 = 0; mode = 0;

        @(negedge clk); reset = 0;   // deassert reset cleanly on a negedge

        // STEP 1: START — 2.0 * 5.0
        @(negedge clk);
        isFcau_id = 1; mode = 2'b00;
        rs1 = 32'sd131072; rs2 = 32'sd327680;
       // @(posedge clk);   // let this posedge commit
        #5;               // tiny delay to let combinational settle post-edge
        $display("After START: fcau_result=%0d (expect 655360)", fcau_result);

        // STEP 2: ACC — 3.0 * 6.0
        @(negedge clk);
        mode = 2'b01;
        rs1 = 32'sd196608; rs2 = 32'sd393216;
        //@(posedge clk);
        #5;
        $display("After ACC: fcau_result=%0d (expect 1835008)", fcau_result);

        // STEP 3: ACC_END — 4.0 * 7.0
        @(negedge clk);
        mode = 2'b10;
        rs1 = 32'sd262144; rs2 = 32'sd458752;
        //@(posedge clk);
        #5;
        $display("After ACC_END: fcau_result=%0d (expect 3670016)", fcau_result);

        $finish;
    end
endmodule