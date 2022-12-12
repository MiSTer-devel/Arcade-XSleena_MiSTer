//XSleenaCore_cpuA.sv
//Author: @RndMnkIII
//Date: 12/08/2022
//See schematics page 20
`default_nettype none
`timescale 1ns/10ps
module XSleenaCore_cpuA (
	input wire HCLK, //6MHz
  	input wire RST,
);

	logic HCLKn;
	assign #5 HCLKn = ~HCLK;

	logic RSTn;
	assign #5 RSTn = ~RST;

//68A09
//Phase generator for MC6809E (taken from MiSTer Vectrex core)
reg mE = 0;
reg mQ = 0;
reg sE = 0;
reg sQ = 0;
always_ff @(posedge HCLKn) begin
	reg [1:0] clk_phase = 0;
	mE <= 0;
	mQ <= 0;
	sE <= 0;
	sQ <= 0;
	clk_phase <= clk_phase + 1'd1;
	case(clk_phase)
		2'b00: sE <= 1;
		2'b01: mQ <= 1;
		2'b10: mE <= 1;
		2'b11: sQ <= 1;
	endcase
end

//Main CPU (Motorola MC6809E - uses synchronous version of Greg Miller's cycle-accurate MC6809E made by Sorgelig)
wire maincpu_rw;
wire [15:0] maincpu_A;
wire [7:0] maincpu_Din, maincpu_Dout;
mc6809is ic62
(
	.CLK(clk_49m),
	.fallE_en(mE),
	.fallQ_en(mQ),
	.D(maincpu_Din),
	.DOut(maincpu_Dout),
	.ADDR(maincpu_A),
	.RnW(maincpu_rw),
	.nIRQ(irq),
	.nFIRQ(1),
	.nNMI(1),
	.nHALT(1'b1), //implement PAUSE with HALTn
	.nRESET(RSTn),
	.nDMABREQ(1'b1)
);
endmodule
