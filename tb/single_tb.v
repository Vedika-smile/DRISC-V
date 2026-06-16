module single_tb;

    reg clk;
    reg reset;

    top DUT (
        .clk   (clk),
        .reset (reset)
    );

    // Clock generation — 20ns period (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        reset = 1;
        #20 reset = 0;
    end

    initial begin
        $dumpfile("sim/wave.vcd");
        $dumpvars(0, single_tb);
    end

    // Monitor — prints every time any signal changes
    initial begin
        $monitor("time=%0t | pc=%h | instr=%h | x1=%d x2=%d x3=%d x4=%d x5=%d x6=%d x7=%d x8=%d",
                  $time,
                  DUT.curr_pc,
                  DUT.instruction,
                  DUT.r_f.x[1],
                  DUT.r_f.x[2],
                  DUT.r_f.x[3],
                  DUT.r_f.x[4],
                  DUT.r_f.x[5],
                  DUT.r_f.x[6],
                  DUT.r_f.x[7],
                  DUT.r_f.x[8]);
    end
    // initial begin
    // $monitor("time=%0t | pc=%h | instr=%h | x1=%d x9=%d x10=%d x11=%d",
    //       $time,
    //       DUT.curr_pc,
    //       DUT.instruction,
    //       DUT.r_f.x[1],
    //       DUT.r_f.x[9],
    //       DUT.r_f.x[10],
    //       DUT.r_f.x[11]);
    // end 
    // Run simulation
    initial begin
        #300 $finish;
    end

endmodule