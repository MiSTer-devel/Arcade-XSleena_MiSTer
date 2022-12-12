//XSleenaCore_BACK2.sv
//Author: @RndMnkIII
//Date: 19/10/2022
//Schematics: pages 5-6B
`default_nettype none
`timescale 1ns/100ps
//`define DEFAULT_REG_VALS
import xain_pkg::*;

//Background2 RAM tilemap address mapping: 0x2800-2FFF
module XSleenaCore_BACK2 (
	input wire clk,
	input wire clk_ram,
	input wire RESETn,
	input wire M1Hn,
	input wire [10:0] AB,
	input wire [5:0] DHPOS,
	input wire DVCUNT,
	input wire [7:0] DVPOS,
	input wire BACK2SELn,
	input wire RW,
	input wire WDn,
	input wire [7:0] DB_in,
	output logic [7:0] DB_out,
	input wire [1:0] HPOS, //uses only 1
	input wire HCLKn, //HCLK0n
	input wire T2n,
	input wire T3n,
	input wire P1_P2n,
	//Registers
	input wire W3A04n,
	input wire W3A05n,
	input wire W3A06n,
	input wire W3A07n,
	//output color and palette
	output logic [3:0] B2COL,
	output logic [2:0] B2PAL,

	//SDRAM ROM interface
	output logic [24:0] sdr_addr,
	output logic sdr_req,
	input wire sdr_rdy,
	input wire [15:0] sdr_data
);
	logic BLA2;
	logic [3:0] B2VP;
	logic [10:0] B2CG;
	logic [3:0] B2HP;
	logic BINV2;
	logic [2:0] B2P;

	//Registers Section:
`ifdef DEFAULT_REG_VALS
	// Jungle Stage
	// logic [7:0] ic14_Q = 8'h00; //3A04W
	// logic ic13A_Q = 1'b0;       //3A05W
	// logic [7:0] ic28_Q = 8'h00; //3A06W
	// logic ic27B_Q = 1'b1;       //3A07W
	// Desert Stage
	logic [7:0] ic14_Q = 8'h00; //3A04W
	logic ic13A_Q = 1'b0;       //3A05W
	logic [7:0] ic28_Q = 8'h00; //3A06W
	logic ic27B_Q = 1'b1;       //3A07W
`else
	//Scroll X
	//3A04W
	logic [7:0] ic14_Q;
	ttl_74273_sync ic14(.CLRn(1'b1), .Clk(clk), .Cen(W3A04n), .D(DB_in), .Q(ic14_Q));

	//3A05W
	logic ic13A_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic13A(
		.clk(clk),
		.din(DB_in[0]),
		.q(ic13A_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(W3A05n) // signal whose edge will trigger the FF
  	);

	//Scroll Y
	//3A06W
	logic [7:0] ic28_Q;
	ttl_74273_sync ic28(.CLRn(1'b1), .Clk(clk), .Cen(W3A06n), .D(DB_in), .Q(ic28_Q));

	//3A07W
	logic ic27B_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic27B(
		.clk(clk),
		.din(DB_in[0]),
		.q(ic27B_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(W3A07n) // signal whose edge will trigger the FF
  	);
`endif

	//This replaces TTL LS283 ICs: ic12, ic11, ic26, ic25
	//LS86 ICs: ic23 (a,b,c)
	logic [8:0] SUM_X, SUM_Y;
	assign SUM_X = {ic13A_Q,ic14_Q} + {DVCUNT,DHPOS,HPOS}; 
	assign SUM_Y = {ic27B_Q,ic28_Q} + {1'b0,DVPOS};

	assign B2VP = SUM_Y[3:0];

	logic [7:0] ic10_Q;
	ttl_74273_sync ic10(.CLRn(1'b1), .Clk(clk), .Cen(HCLKn), .D(SUM_X[7:0]), .Q(ic10_Q));	
	assign B2HP = ic10_Q[3:0];

	logic ic13B_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic13B(
		.clk(clk),
		.din(SUM_X[8]),
		.q(ic13B_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(HCLKn) // signal whose edge will trigger the FF
  	);

	logic [3:0] ic9_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic9 
	(.Enable_bar(1'b0),.Select(BACK2SELn),
	.A_2D({ic10_Q[7],AB[3],ic10_Q[6],AB[2],ic10_Q[5],AB[1],ic10_Q[4],AB[0]}),
	.Y(ic9_Y));

	logic [3:0] ic24_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic24 
	(.Enable_bar(1'b0),.Select(BACK2SELn),
	.A_2D({SUM_Y[7],AB[7],SUM_Y[6],AB[6],SUM_Y[5],AB[5],SUM_Y[4],AB[4]}),
	.Y(ic24_Y));

	logic [3:0] ic8_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic110 
	(.Enable_bar(1'b0),.Select(BACK2SELn),
	.A_2D({1'b1,WDn,~M1Hn,AB[10],SUM_Y[8],AB[9],ic13B_Q,AB[8]}), //HACK ~M1Hn
	.Y(ic8_Y));

	//TMM2018-55 2Kx8bit 55ns SRAM 
	logic [7:0] SRAM_Din, SRAM_Dout;
	//SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_jungle_back1.bin_vmem.txt")) ic22(
	//SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_jungle_back1.bin_vmem.txt")) ic22(
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_desert_bgram0.bin_vmem.txt")) ic22(	
	//SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_title_bgram0_vmem.txt")) ic22(
		.clk(clk),
		.ADDR({ic8_Y[2:0],ic24_Y[3:0],ic9_Y[3:0]}),
		.DATA(SRAM_Din),
		.cen(1'b1), //active high
		.we(~ic8_Y[3]), //active high
		.Q(SRAM_Dout)
    );

	logic ic75a; //OR gate
	assign ic75a = (M1Hn | BACK2SELn);

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces tri-state logic ---
// This replaces TTL logic LS245 ICs: ic80
// Adds one master clock period delay
	//BACK2 Tilemap SRAM data output
	always_ff @(posedge clk) begin
		if (RW && !ic75a) DB_out <= SRAM_Dout;
		else              DB_out <= 8'hFF; //replaces hi-Z bus state
	end

	//BACK2 Tilemap SRAM data input
	always_ff @(posedge clk) begin
		if(!RW && !ic75a)      SRAM_Din <= DB_in;
		else                   SRAM_Din <= 8'hFF; //replaces hi-Z bus state
	end
//-------------------------------------------------------------------------------

	logic [7:0] ic21_Q;
	ttl_74273_sync ic21(.CLRn(1'b1), .Clk(clk), .Cen(T2n), .D(SRAM_Dout), .Q(ic21_Q));

	logic [7:0] ic32_Q;
	ttl_74273_sync ic32(.CLRn(1'b1), .Clk(clk), .Cen(BLA2), .D(ic21_Q), .Q(ic32_Q));

	logic [6:0] ic20_Q;
	ttl_74273_sync #(.BLOCKS(7)) ic20(.CLRn(1'b1), .Clk(clk), .Cen(T3n), .D({SRAM_Dout[7:4],SRAM_Dout[2:0]}), .Q(ic20_Q));

	logic [6:0] ic31_Q;
	ttl_74273_sync #(.BLOCKS(7)) ic31(.CLRn(1'b1), .Clk(clk), .Cen(BLA2), .D(ic20_Q), .Q(ic31_Q));

	assign B2CG = {ic31_Q[2:0], ic32_Q[7:0]}; //10:0
	assign B2P = ic31_Q[5:3];
	assign BINV2 = ic31_Q[6];

	//---------- ROM SECTION ------------
	logic ic54c, ic55b; //XOR gate
	assign ic54c = (BINV2 ^ B2HP[2]);
	assign ic55b = (BINV2 ^ B2HP[3]);

	logic ic57e; //NOT gate
	assign ic57e = ~ic55b;

	//--- Intel P27256 32Kx8 MAP ROM 250ns ---
	// ROMH: IC44,IC45,IC46,IC47
	// ROML: IC43,IC42,IC41,IC40
	//*** START OF BACK2 ROM address request generator ***
	// logic [24:0] req_ROM_addr;
	// logic ROM_req;
	// logic ROM_data_rdy;
	// logic [15:0] ROM_data;
	logic [7:0] ROMH, ROML;

	logic last_HCLKn;
	logic [12:0] curr_ROM13_addr;
	logic [12:0] last_ROM13_addr = 13'h0;

	assign curr_ROM13_addr = {B2CG[10:0],ic57e,ic54c};

	always_ff @(posedge clk_ram) begin
		last_HCLKn <= HCLKn;
		sdr_req <= 1'b0;

		if(last_HCLKn && !HCLKn) begin//detect falling edge
			last_ROM13_addr <= curr_ROM13_addr;

			//Dont make address request while the system is resetting
			if(!RESETn) begin
				sdr_addr <= 0;
				sdr_req <= 1'b0;
			end
			//ignore address changes based on B2VP
			else if (last_ROM13_addr != curr_ROM13_addr) begin
				sdr_addr <= REGION_ROM_BACK2.base_addr[24:0] | {curr_ROM13_addr,B2VP[3:0],1'b0};
				sdr_req <= 1'b1;
			end
		end
	end

	always_ff @(posedge clk_ram) begin
		if(sdr_rdy) begin
			ROMH <= sdr_data[15:8];
			ROML <= sdr_data[7:0];
		end
	end

	// sdr_req_manager_single back2_sdr_req_man(
	// 	.clk(clk_ram),
	// 	.clk_ram(clk_ram),

	// 	.rom_addr(req_ROM_addr),
	// 	.rom_data(ROM_data),
	// 	.rom_req(ROM_req),
	// 	.rom_rdy(ROM_data_rdy),

	// 	.sdr_addr(sdr_addr),
	// 	.sdr_data(sdr_data),
	// 	.sdr_req(sdr_req),
	// 	.sdr_rdy(sdr_rdy)
	// );
	//*** END OF BACK2 ROM address request generator ***

	logic ic54a,ic54d,ic54b; //XOR gate
	logic ic64c; //AND gate
	logic ic57d; //NOT gate

	assign ic54a = (P1_P2n ^ B2HP[0]);
	assign ic54d = (P1_P2n ^ B2HP[1]);
	assign ic54b = (P1_P2n ^ B2HP[2]);
	assign ic64c = (ic54a & ic54d);
	assign ic57d = ~ic54b;
	assign BLA2 = ic57d;

	logic ic23d; //XOR gate
	logic [1:0] ic34_Y;

	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic34
	(.Enable_bar(1'b0),.Select(ic23d),
	.A_2D({1'b1,ic64c,ic64c,1'b1}),
	.Y(ic34_Y));

	logic [3:0] ic33_Q;
	ttl_74174_sync #(.BLOCKS(4)) ic33
    (
        .Clk(clk),
        .Cen(ic54b),
        .Clr_n(1'b1),
        .D({B2P[2:0],BINV2}),
        .Q(ic33_Q)
    );

	assign ic23d = (P1_P2n ^ ic33_Q[0]);

	//2 DSR, 7 DSL, 9 S0, 10 S1, 6-3 P3-0, 12-15 Q3-0 
	// S1 S0 Dsr
	//  0  1   1  Shift Righ    {Dsr,q0, q1, q2} -> {Q3,Q2,Q1,Q0}
	//  1  1   1  Parallel Load {D3,D2,D1,D0} -> {Q3,Q2,Q1,Q0}
	logic [3:0] ic35_Q;
	ttl_74194_sync ic35
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic34_Y[1]), .S1(ic34_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[0]), .D1(ROMH[1]), .D2(ROMH[2]), .D3(ROMH[3]),
		.Q0(ic35_Q[0]), .Q1(ic35_Q[1]), .Q2(ic35_Q[2]), .Q3(ic35_Q[3]));

	logic [3:0] ic50_Q;
	ttl_74194_sync ic50
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic34_Y[1]), .S1(ic34_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[4]), .D1(ROMH[5]), .D2(ROMH[6]), .D3(ROMH[7]),
		.Q0(ic50_Q[0]), .Q1(ic50_Q[1]), .Q2(ic50_Q[2]), .Q3(ic50_Q[3]));

	logic [3:0] ic52_Q;
	ttl_74194_sync ic52
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic34_Y[1]), .S1(ic34_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[0]), .D1(ROML[1]), .D2(ROML[2]), .D3(ROML[3]),
		.Q0(ic52_Q[0]), .Q1(ic52_Q[1]), .Q2(ic52_Q[2]), .Q3(ic52_Q[3]));

	logic [3:0] ic53_Q;
	ttl_74194_sync ic53
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic34_Y[1]), .S1(ic34_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[4]), .D1(ROML[5]), .D2(ROML[6]), .D3(ROML[7]),
		.Q0(ic53_Q[0]), .Q1(ic53_Q[1]), .Q2(ic53_Q[2]), .Q3(ic53_Q[3]));

	logic [3:0] ic51_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic153
	(.Enable_bar(1'b0),.Select(ic23d),
	.A_2D({ic53_Q[3],ic53_Q[0],ic52_Q[3],ic52_Q[0],ic50_Q[3],ic50_Q[0],ic35_Q[3],ic35_Q[0]}),
	.Y(ic51_Y));
	//-----------------------------------------------------------------------
	assign B2COL = {ic51_Y[3],ic51_Y[2],ic51_Y[1],ic51_Y[0]}; //Palette color index (0-15)
	assign B2PAL = ic33_Q[3:1]; //Palette color bank (0-7)
endmodule