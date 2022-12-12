//SRAM_async3.v
//Asynchronous static RAM of variable size with initial memory contents
`default_nettype none
`timescale 1ns/1ns

//default 8x1K ram size
module SRAM_async_alwaysdout#(parameter DATA_WIDTH = 8, ADDR_WIDTH = 10, DELAY = 25, DATA_HEX_FILE="dump.hex")(
    input wire [ADDR_WIDTH-1:0] ADDR,
    input wire CE1n,
    input wire CE2,
    input wire OEn,
    input wire WEn,
    inout wire [DATA_WIDTH-1:0] DATA);

    reg [DATA_WIDTH-1:0] mem[0:(2**ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] data_out;
    wire ce;

    initial begin
        $readmemh(DATA_HEX_FILE, mem);
    end
    
    assign ce = ~CE1n & CE2;
    always @(*)
    begin: mem_write
        if (ce && !WEn) begin
          mem[ADDR] = DATA;
        end
    end

    always @(*)
    begin: mem_read
        if (ce && WEn && !OEn) begin
          data_out = mem[ADDR];
        end
    end

    //assign #DELAY DATA = (ce && WEn && !OEn) ? data_out : 8'hzz;
    assign #DELAY DATA = (ce && !OEn) ? data_out : 8'hzz;
endmodule