//ttl_74273_sync.v
// Octal D flip-flop with reset; positive-edge-triggered
`default_nettype none
`timescale 1ns/1ps
module ttl_74273_sync #(parameter BLOCKS = 8)
(
    input wire CLRn,
    input wire Clk,
    input wire Cen /* synthesis syn_direct_enable = 1 */,
    input wire [BLOCKS-1:0] D,
    output wire [BLOCKS-1:0] Q
);
    //------------------------------------------------//
    reg [BLOCKS-1:0] Q_current;
    reg last_cen;

    initial Q_current = {(BLOCKS){1'b0}};
    initial last_cen = 1'b1;
    always @(posedge Clk)
    begin
        last_cen <= Cen;
        if (!CLRn) Q_current <= {(BLOCKS){1'b0}};
        else if(Cen && !last_cen) Q_current <= D; //detect rising edge of Cen
    end
    //------------------------------------------------//
    assign Q = Q_current;
endmodule