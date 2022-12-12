//ttl_74374.sv
// Octal D edge triggered FF
// function table, logic diagrams and switching characteristics
// extracted from TI 74LS374 Datasheet.
//iverilog ttl_74374.v
`default_nettype none
`timescale 1ns/1ns
module ttl_74374 #(parameter DLY=10)
(
  input  wire OCn,
  input  wire CLK,
  input  wire [7:0] D,
  output wire [7:0] Q
);
    reg [7:0] Q_current;
    
    always_ff @(posedge CLK ) begin
        Q_current <= D;
    end

    //If OCn is disabled output is in high impedance state
    assign #DLY Q = (OCn) ? 8'hzz : Q_current;
endmodule