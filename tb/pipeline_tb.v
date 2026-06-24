module pipeline_tb;

    reg clk;
    reg reset;

    top_pipeline DUT (
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        reset = 1;
        #20 reset = 0;
    end

    initial begin
        $dumpfile("sim/pipe.vcd");
        $dumpvars(0, pipeline_tb);
    end

    // ONE combined monitor — shows everything needed in one aligned line
    // initial begin
    //     $monitor("t=%0t | pc=%h instr=%h | rd_wb=%0d regWrite_wb=%b data=%h | x1=%h x2=%h x3=%h x4=%h",
    //               $time,
    //               DUT.curr_pc, DUT.instruction,
    //               DUT.rd_wb, DUT.regWrite_wb, DUT.r_f.data,
    //               DUT.r_f.x[1], DUT.r_f.x[2], DUT.r_f.x[3], DUT.r_f.x[4 ]);
    //     // $monitor("t=%0t | memRead_ex=%b memWrite_ex=%b addr=%h readData=%h",
    //     //   $time, DUT.memRead_ex, DUT.memWrite_ex, DUT.alu_result_ex, DUT.readData);

    //     // $monitor("t=%0t | memRead_ex=%b memWrite_ex=%b addr=%h writeData=%h readData=%h",
    //     //   $time, DUT.memRead_ex, DUT.memWrite_ex, DUT.alu_result_ex,
    //     //   DUT.write_data_ex, DUT.readData);

    //     // $monitor("t=%0t | memWrite_ex=%b addr=%h writeData=%h | ram1=%h | memRead_ex=%b readData=%h",
    //     //   $time, DUT.memWrite_ex, DUT.alu_result_ex, DUT.write_data_ex,
    //     //   DUT.DMEM.ram[1], DUT.memRead_ex, DUT.readData);
    //     // $monitor("t=%0t | instr=%h | rd=%0d rd_id=%0d rd_ex=%0d rd_wb=%0d | regWrite_wb=%b data=%h",
    //     //   $time, DUT.inst_if, DUT.rd, DUT.rd_id, DUT.rd_ex, DUT.rd_wb,
    //     //   DUT.regWrite_wb, DUT.writeBackData_wb);
    //     $monitor("t=%0t | instr=%h | branch_id=%b funct3_id=%b zero=%b alu_a=%h alu_b=%h alu_result=%h | pc_id=%h imm_ext_id=%h | curr_pc=%h",
    //       $time,
    //       DUT.inst_if,
    //       DUT.branch_id, DUT.funct3_id, DUT.zero,
    //       DUT.alu_a, DUT.alu_b, DUT.alu_result,
    //       DUT.pc_id, DUT.imm_ext_id,
    //       DUT.curr_pc);
    //     //   $monitor("t=%0t | instr=%h rs2=%0d | rdout2=%h rdout2_id=%h | branch_id=%b alu_b=%h",
    //     //   $time, DUT.inst_if, DUT.rs2, DUT.rdout2, DUT.rdout2_id,
    //     //   DUT.branch_id, DUT.alu_b);
    // end

    initial begin
    $monitor("t=%0t | pc=%h instr=%h | rd_wb=%0d regWrite_wb=%b data=%h | x1=%h x2=%h x3=%h x4=%h",
              $time,
              DUT.curr_pc, DUT.instruction,
              DUT.rd_wb, DUT.regWrite_wb, DUT.r_f.data,
              DUT.r_f.x[1], DUT.r_f.x[2], DUT.r_f.x[3], DUT.r_f.x[4]);
    end

    // Separate block to catch the final store to memory and print the result
    always @(posedge clk) begin
        if (DUT.memWrite_ex && DUT.alu_result_ex == 32'h8) begin
            $display("------------------------------------------------------");
            $display("t=%0t | SW to mem[0x8] detected | writeData=%0d (0x%h)",
                    $time, DUT.write_data_ex, DUT.write_data_ex);
            $display("Multiply result (x1*x2 via repeated add) = %0d", DUT.write_data_ex);
            $display("------------------------------------------------------");
        end
    end

    // Optional: print final memory content + register values at end of simulation
    initial begin
        #2000;  // adjust delay so it runs after the program finishes
        $display("========================================");
        $display("FINAL RESULT CHECK");
        $display("x1 = %0d  x2 = %0d  x3 (product) = %0d", 
                DUT.r_f.x[1], DUT.r_f.x[2], DUT.r_f.x[3]);
        $display("DMEM[word 2] (byte addr 0x8) = %0d (0x%h)", 
                DUT.DMEM.ram[2], DUT.DMEM.ram[2]);
        if (DUT.DMEM.ram[2] == 32'd30)
            $display("STATUS: PASS - 5 x 6 = 30 correctly computed and stored");
        else
            $display("STATUS: FAIL");
        $display("========================================");
        $finish;
    end
    

    initial begin
        #2000 $finish;
    end

endmodule