//ttl_74374.sv
// Octal D edge triggered FF
// function table, logic diagrams and switching characteristics
// extracted from TI 74LS374 Datasheet.
//iverilog ttl_74374.v
`default_nettype none
`timescale 1ns/1ns
module ttl_74374_sync_noHiZout
(
  input wire clk,
  input wire cen,
  input  wire OCn,
  input  wire [7:0] D,
  output wire [7:0] Q
);
    reg [7:0] Q_current;
	reg last_cen;
	initial Q_current = 8'h0;
	initial last_cen = 1'b1;
always @(posedge clk) begin
	last_cen <= cen;
	 if (cen && !last_cen) Q_current <= D;
end

    assign Q = (OCn) ? 8'hFF : Q_current;
endmodule