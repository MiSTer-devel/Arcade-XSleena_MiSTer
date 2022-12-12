//XSleenaCore_CLK_CEN_Cen.v
//Author: @RndMnkIII
//Date: 07/10/2022
//clk_i   48MHz
`default_nettype none
`timescale 1ns/1ps

module XSleenaCore_CLK_CEN_Cen (
    input wire  i_clk, //48MHz
    output wire clk_12_cen,
    output wire HCLKn_cen
);
    //--------- 12 MHz ---------
    reg ck_stb1=1'b0;
    reg	[1:0] counter1=2'h3;

    always @(posedge i_clk) begin
      { ck_stb1, counter1 } <= counter1 + 2'h1; //stores carry out on ck_stb1
    end

    assign clk_12_cen = ck_stb1;

    //--------- HCLKn ---------
    reg ck_stb2=1'b0;
    reg	[2:0] counter2=3'h7;
    always @(posedge i_clk) begin
      { ck_stb2, counter2 } <= counter2 + 3'h1; //stores carry out on ck_stb2
    end

    assign HCLKn_cen = ~counter2[2] & ~counter2[1] & counter2[0];
endmodule
