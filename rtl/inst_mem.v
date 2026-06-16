module inst_mem(
    input  wire [31:0] addr,
    output wire [31:0] instruction
);

    // 64 words = 256 bytes
    // Valid PC range: 0x00000000 to 0x000000FC
    reg [31:0] rom [0:63];

    // Word-addressed: divide byte address by 4 using bits [7:2]
    assign instruction = rom[addr[7:2]];

    integer i;
    initial begin
        // Default to NOP so uninitialized memory is safe
        for (i = 0; i < 64; i = i + 1)
            rom[i] = 32'h00000013;
        $readmemh("prg/program.txt", rom);
    end

endmodule