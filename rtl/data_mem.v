module data_mem(
    input  wire 		clk,       // System clock
    input  wire 		memRead,   // Control signal to read
    input  wire 		memWrite,  // Control signal to write
    input  wire [31:0] 	addr,      // Address from ALU calculation
    input  wire [31:0] 	writeData, // Data from register rs2 to write into memory
    output wire [31:0] 	readData   // Data read from memory sent back to register file
);

    // Create a data memory array of 64 words 
    reg [31:0] ram [0:63];
    
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            ram[i] = 32'h00000000;
    end

    // Asynchronous continuous read when memRead is enabled
    // 7:2 -> 6 bits for 64 entries
    assign readData = (memRead) ? ram[addr[7:2]] : 32'h00000000;  

    // Synchronous write on falling edge to protect single-cycle timing paths
    always @(negedge clk) begin
        if (memWrite) begin
            ram[addr[7:2]] <= writeData;
        end
    end

    //Simulation-only alignment check
    always @(posedge clk) begin
        if ((memRead || memWrite) && (addr[1:0] != 2'b00)) begin
            $display("WARNING: Unaligned memory access at addr=%h", addr);
        end
    end

endmodule