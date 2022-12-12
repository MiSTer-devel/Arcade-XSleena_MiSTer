//ttl_74257.v
// Quad 2-input multiplexer  tri-state output
//Author: @RndMnkIII
//Date: 31/08/2022
`include "helper.v"
`default_nettype none
`timescale 1ns/1ns

module ttl_74257 #(parameter BLOCKS = 4, WIDTH_IN = 2, WIDTH_SELECT = $clog2(WIDTH_IN),
                   DELAY_RISE = 12, DELAY_FALL = 13)
(
  input wire Enable_bar, //0 enable logic output, 1 hi-Z output
  input wire [WIDTH_SELECT-1:0] Select, //0 select A, 1 select B
  input wire [BLOCKS*WIDTH_IN-1:0] A_2D,
  output wire [BLOCKS-1:0] Y
);

//------------------------------------------------//
wire [WIDTH_IN-1:0] A [0:BLOCKS-1];
reg [BLOCKS-1:0] computed;
integer i;

always @(*)
begin
  for (i = 0; i < BLOCKS; i=i+1)
  begin
    if (!Enable_bar)
      computed[i] = A[i][Select];
    else
      computed[i] = 1'bz; //if Enable_bar output = Hi-Z.
  end
end
//------------------------------------------------//

`ASSIGN_UNPACK_ARRAY(BLOCKS, WIDTH_IN, A, A_2D)
assign #(DELAY_RISE, DELAY_FALL) Y = computed;

endmodule