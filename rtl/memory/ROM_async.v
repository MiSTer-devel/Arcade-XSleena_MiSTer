//ROM_async.v
//27256D EPROM typical delay 150ns
`default_nettype none
`timescale 1ns/1ns

module ROM_async #(parameter DATA_WIDTH = 8, ADDR_WIDTH = 15, DELAY = 150, DATA_HEX_FILE="dump.hex")(
    input wire [ADDR_WIDTH-1:0] ADDR, 
    input wire CEn,
    input wire OEn,
    output wire [DATA_WIDTH-1:0] DATA);

    reg [DATA_WIDTH-1:0] romdata [0:(2**ADDR_WIDTH)-1];
    wire [DATA_WIDTH-1:0] d0;
    wire [DATA_WIDTH-1:0] hizval = {DATA_WIDTH{1'bZ}};

    initial begin
        $readmemh(DATA_HEX_FILE, romdata);
    end

    assign #DELAY DATA = (~CEn & ~OEn) ? romdata[ADDR] : hizval;
endmodule