module ex_mem_reg (
    input wire        clk,
    input wire        reset,

    // From EX stage
    input wire [31:0] pc_plus4_in,     // for JAL/JALR writeback
    input wire [31:0] alu_result_in,   // computed address or result
    input wire [31:0] write_data_in,   // rs2 value, for SW
    input wire [4:0]  rd_in,

    // Control signals from EX stage
    input wire        regWrite_in,
    input wire        memWrite_in,
    input wire        memRead_in,
    input wire        memToReg_in,
    input wire        jump_in,          // ← added

    // Outputs to MEM/WB stage
    output reg [31:0] pc_plus4_out,
    output reg [31:0] alu_result_out,
    output reg [31:0] write_data_out,
    output reg [4:0]  rd_out,

    output reg        regWrite_out,
    output reg        memWrite_out,
    output reg        memRead_out,
    output reg        memToReg_out,
    output reg        jump_out          // ← added
);

    always @(posedge clk) begin
        if (reset) begin
            pc_plus4_out   <= 32'h00000000;
            alu_result_out <= 32'h00000000;
            write_data_out <= 32'h00000000;
            rd_out         <= 5'b00000;
            regWrite_out   <= 1'b0;
            memWrite_out   <= 1'b0;
            memRead_out    <= 1'b0;
            memToReg_out   <= 1'b0;
            jump_out       <= 1'b0;
        end else begin
            pc_plus4_out   <= pc_plus4_in;
            alu_result_out <= alu_result_in;
            write_data_out <= write_data_in;
            rd_out         <= rd_in;
            regWrite_out   <= regWrite_in;
            memWrite_out   <= memWrite_in;
            memRead_out    <= memRead_in;
            memToReg_out   <= memToReg_in;
            jump_out       <= jump_in;
        end
    end

endmodule