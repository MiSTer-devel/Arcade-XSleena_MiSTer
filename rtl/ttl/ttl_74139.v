// Dual 2-line to 4-line decoder/demultiplexer (inverted outputs)
`default_nettype none
`timescale 1ns/1ns

module ttl_74139  #(parameter DELAY = 15)
(
  input wire Enable_bar,
  input wire [1:0] A_2D,
  output wire [3:0] Y_2D
);
  assign #DELAY Y_2D[0] = ~(~Enable_bar & ~A_2D[1] & ~A_2D[0]); 
  assign #DELAY Y_2D[1] = ~(~Enable_bar & ~A_2D[1] &  A_2D[0]);
  assign #DELAY Y_2D[2] = ~(~Enable_bar &  A_2D[1] & ~A_2D[0]);
  assign #DELAY Y_2D[3] = ~(~Enable_bar &  A_2D[1] &  A_2D[0]);
endmodule