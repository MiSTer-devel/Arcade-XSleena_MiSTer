//n8bit_counter.sv
//Author: @RndMnkIII
//Date: 17/10/2022
`default_nettype none
`timescale 1ns/1ps

module n8bit_counter
(
  input wire Reset_n,
  input wire clk,
  input wire cen,
  input wire direction, // 1 = Up, 0 = Down
  input wire load_n,    // 1 = Count, 0 = Load
  input wire ent_n,
  input wire enp_n,
  input wire [7:0] P,
  output logic [7:0] Q   // 4-bit output
);

logic [7:0] count;
logic last_cen;

initial count = 8'h0;
initial last_cen = 1'b0;

always @(posedge clk) begin
    last_cen <= cen;

    if (cen && !last_cen) begin //detect rising edge
        if(!Reset_n) begin
            count <= 8'h0;
        end
        else if (!load_n)
        begin
            count <=  P;
        end
        else if (~ent_n & ~enp_n) // Count only if both enable signals are active (low)
        begin
            if (direction)
            begin
            // Counting up
            if (count == 8'd255) count <= 8'd0;
            else count <=  count + 8'd1;
            end
            else
            begin
            // Counting down
            if (count == 8'd0) count <= 8'd255;
            else count <=  count - 8'd1;
            end
        end
    end
end

assign Q = count;
endmodule