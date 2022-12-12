//ttl_74174_sync.v
// Hex D flip-flop with clear (asynchronous); positive-edge-triggered
`default_nettype none
`timescale 1ns/1ps

module ttl_74174_sync #(parameter BLOCKS = 6)
( 
    input wire Clk,
    //(*direct_enable*) input wire Cen,
    input wire Cen,
    input wire Clr_n,
    input wire [BLOCKS-1:0] D,
    output wire [BLOCKS-1:0] Q
);
    //------------------------------------------------//
    reg [BLOCKS-1:0] Q_current;
    reg last_cen;

    initial last_cen = 1'b1;

    initial Q_current = {(BLOCKS){1'b0}};
    always @(posedge Clk)
    begin
        last_cen <= Cen;

        if (!Clr_n) //pseudo asynchronous clear
            Q_current <= {(BLOCKS){1'b0}};
        else
        if (Cen && !last_cen) //detect rising edge of Cen
        begin
            Q_current <= D;
        end
        else begin
            Q_current <= Q_current;
        end
    end
    //------------------------------------------------//
    assign Q = Q_current;

endmodule