module forwarding_unit(
    input  wire [4:0] rs1_ex,
    input  wire [4:0] rs2_ex,

    input  wire [4:0] rd_exmem,
    input  wire       regWrite_exmem,

    output reg        forwardA,    // single bit: forward or not
    output reg        forwardB
);

    always @(*) begin
        forwardA = (regWrite_exmem && (rd_exmem != 0) && (rd_exmem == rs1_ex));
        forwardB = (regWrite_exmem && (rd_exmem != 0) && (rd_exmem == rs2_ex));
    end

endmodule

// module forwarding_unit(
//     input  wire [4:0] rs1_ex,
//     input  wire [4:0] rs2_ex,

//     input  wire [4:0] rd_exmem,
//     input  wire       regWrite_exmem,
//     input  wire       memToReg_exmem, // Identifies if the instruction is a Load

//     output reg [1:0]  forwardA,       // 2-bit selection control
//     output reg [1:0]  forwardB
// );

//     always @(*) begin
//         // Default: No forwarding (use values directly from ID/EX register)
//         forwardA = 2'b00;
//         forwardB = 2'b00;

//         //---------------------------------------------------------
//         // EX/MEM Hazard (Forwarding from an ALU operation)
//         //---------------------------------------------------------
//         if (regWrite_exmem && (rd_exmem != 5'b0) && (!memToReg_exmem)) begin
//             if (rd_exmem == rs1_ex) forwardA = 2'b10;
//             if (rd_exmem == rs2_ex) forwardB = 2'b10;
//         end

//         //---------------------------------------------------------
//         // MEM/WB Hazard (Forwarding directly from Data Memory Read)
//         //---------------------------------------------------------
//         if (regWrite_exmem && (rd_exmem != 5'b0) && memToReg_exmem) begin
//             if (rd_exmem == rs1_ex) forwardA = 2'b01;
//             if (rd_exmem == rs2_ex) forwardB = 2'b01;
//         end
//     end

// endmodule