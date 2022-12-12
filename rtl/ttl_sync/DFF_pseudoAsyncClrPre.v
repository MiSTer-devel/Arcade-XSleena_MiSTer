//Author: @RndMnkIII
//Date: 12/03/2022
`default_nettype none
`timescale 1ns/10ps
module DFF_pseudoAsyncClrPre #(parameter W=1 ) (
    input  wire          clk,
    input  wire [W-1:0]  din,
    output wire [W-1:0]  q,
    output wire [W-1:0]  qn,
    input  wire [W-1:0]  set,    
    input  wire [W-1:0]  clr,    
    input  wire [W-1:0]  cen 
);

reg  [W-1:0] last_edge;
reg  [W-1:0] Q_current;
initial Q_current = {W{1'b0}};

generate
    genvar i;
    for (i=0; i < W; i=i+1) begin: flip_flop
        always @(posedge clk) begin
            last_edge[i] <= cen[i];
            if( clr[i] ) begin
                Q_current[i]  <= 1'b0;
            end else
            if( set[i] ) begin
                Q_current[i]  <= 1'b1;
            end else
            if( cen[i] && !last_edge[i] ) begin
                Q_current[i]  <=  din[i];
            end
        end

        assign q[i]  =  Q_current[i];
        assign qn[i] = ~Q_current[i];
    end
endgenerate

endmodule