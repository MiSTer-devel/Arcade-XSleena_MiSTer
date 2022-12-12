//SRAM_dual_async3.v
//Asynchronous static RAM of variable size with initial memory contents
`default_nettype none
`timescale 1ns/1ns

//default 8x1K ram size
module SRAM_dual_async3#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 10, DELAY = 25, DATA_HEX_FILE="dump.hex")(
    input wire [ADDR_WIDTH-1:0] ADDRA,
	input wire [ADDR_WIDTH-1:0] ADDRB,
    input wire CEA1n,
    input wire CEA2,
    input wire OEAn,
    input wire WEAn,
	input wire CEB1n,
    input wire CEB2,
    input wire OEBn,
    input wire WEBn,
    inout wire [DATA_WIDTH-1:0] DATA_A,
	inout wire [DATA_WIDTH-1:0] DATA_B);

    reg [DATA_WIDTH-1:0] mem[0:(2**ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] data_outA;
	reg [DATA_WIDTH-1:0] data_outB;
    wire ce_A;
	wire ce_B;

    initial begin
        $readmemh(DATA_HEX_FILE, mem);
    end
    
    assign ce_A = ~CEA1n & CEA2;
    always @(*)
    begin: mem_writeA
        if (ce_A && !WEAn) begin
          mem[ADDRA] = DATA_A;
        end
    end

    always @(*)
    begin: mem_readA
        if (ce_A && WEAn && !OEAn) begin
          data_outA = mem[ADDRA];
        end
    end

    assign #DELAY DATA_A = (ce_A && WEAn && !OEAn) ? data_outA : 8'bz;

	//--------------------------------------------------------------
	assign ce_B = ~CEB1n & CEB2;
    always @(*)
    begin: mem_writeB
        if (ce_B && !WEBn) begin
          mem[ADDRB] = DATA_B;
        end
    end

    always @(*)
    begin: mem_readB
        if (ce_B && WEBn && !OEBn) begin
          data_outB = mem[ADDRB];
        end
    end

    assign #DELAY DATA_B = (ce_B && WEBn && !OEBn) ? data_outB : 8'hzz;
endmodule