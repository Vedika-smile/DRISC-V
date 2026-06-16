module regfile(
    input  wire        clk,
    input  wire        reset,
    input  wire        w_enb,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] data,
    output wire [31:0] rdout1,
    output wire [31:0] rdout2
);
	
	reg [31:0] x [31:0];
	
	assign rdout1 = (rs1 == 0) ? 32'b0 : x[rs1];
    assign rdout2 = (rs2 == 0) ? 32'b0 : x[rs2];
	
	integer i;
	always @(posedge clk, posedge reset) begin
		if (reset) begin						// Reset
			for (i = 0; i < 32; i = i + 1) begin 
				x[i] <= 0;
			end
		end
		else if (w_enb & (rd != 0)) begin			// Write enable and can not overwrite x0
			x[rd] <= data;						// Store data to rd register
		end 
	
	end
	
endmodule