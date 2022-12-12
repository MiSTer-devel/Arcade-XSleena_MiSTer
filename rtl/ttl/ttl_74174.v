//ttl_74174.v
// Hex D flip-flop with reset; positive-edge-triggered
`default_nettype none
`timescale 1ns/1ns

module ttl_74174 #(parameter DELAY_RISE = 20, DELAY_FALL = 21)
(input wire Clk,
  input wire RESETn,
  input wire [5:0] D,
  output wire [5:0] Q
);
    //------------------------------------------------//
    reg [5:0] Q_current; // = 6'h00;

    //initial Q_current = 6'h00; //supposition
    always @(posedge Clk or negedge RESETn)
    begin
        if (!RESETn)
        Q_current <= 6'h00;
        else
        begin
        Q_current <= D;
        end
    end
    //------------------------------------------------//
    assign #(DELAY_RISE, DELAY_FALL) Q = Q_current;
endmodule