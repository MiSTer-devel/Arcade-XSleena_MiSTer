    //ttl_74245.v
`default_nettype none
`timescale 1ns/1ns

module ttl_74245 #(parameter DELAY_RISE = 12, DELAY_FALL = 12)
(
    input wire DIR,
    input wire Enable_bar,
    inout wire [7:0] A,
    inout wire [7:0] B
);
    assign #(DELAY_RISE,DELAY_FALL) A = (Enable_bar ||  DIR) ? 8'hzz : B; //B->A
    assign #(DELAY_RISE,DELAY_FALL) B = (Enable_bar || !DIR) ? 8'hzz : A; //A->B
endmodule
