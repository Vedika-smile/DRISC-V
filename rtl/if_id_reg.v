module if_id_reg(
    input clk,
    input reset,

    input stall, //load-use hazard
    input flush, //branch or jump 

    input [31:0] pc_in,
    input [31:0] inst,
    output reg [31:0] pc_out,
    output reg [31:0] inst_out
);

always @(posedge clk) begin
    if (reset) begin
        pc_out <= 32'h00000000;
        inst_out <= 32'h00000013;
    end 
    else if (flush) begin
        pc_out <= pc_out;
        inst_out <= 32'h00000013;
    end
    else if (stall) begin
        pc_out <= pc_out;
        inst_out <= inst_out;
    end
    else begin
        pc_out<=pc_in;
        inst_out <= inst;
    end
end

endmodule