//ttl_74273.v
// Octal D flip-flop with reset; positive-edge-triggered
//iverilog ttl_74273.v
`default_nettype none
`timescale 1ns/1ns
module ttl_74273 #(parameter DELAY_RISE = 12, DELAY_FALL = 13) 
(
  input wire Clk,
  input wire RESETn,
  input wire [7:0] D,
  output wire [7:0] Q
);
    //------------------------------------------------//
    reg [7:0] Q_current;
    // initial begin 
    //   Q_current <= 8'h00;
    // end//supposition
    
    always @(posedge Clk or negedge RESETn)
    begin
        
        if (!RESETn)
        Q_current <= 0;
        else
        begin
        Q_current <= D;
        end
    end
    //------------------------------------------------//
    assign #(DELAY_RISE, DELAY_FALL) Q = Q_current;
endmodule