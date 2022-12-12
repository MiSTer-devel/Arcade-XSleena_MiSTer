//XSleenaCore_BACK1.sv
//Author: @RndMnkIII
//Date: 21/11/2022
//Schematics: pages 7-8A
`default_nettype none
`timescale 1ns/100ps
//`define DEFAULT_REG_VALS
import xain_pkg::*;

//Background1 tilemap address mapping: 0x3000-37FF
module XSleenaCore_BACK1 (
	input wire clk,
	input wire clk_ram,
	input wire RESETn,
	input wire M1Hn,
	input wire [10:0] AB,
	input wire [5:0] DHPOS,
	input wire DVCUNT,
	input wire [7:0] DVPOS,
	input wire BACK1SELn,
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
	input wire W3A00n,
	input wire W3A01n,
	input wire W3A02n,
	input wire W3A03n,
	//Output color and palette
	output logic [3:0] B1COL,
	output logic [2:0] B1PAL,

	//SDRAM ROM interface
	output logic [24:0] sdr_addr,
	output logic sdr_req,
	input wire sdr_rdy,
	input wire [15:0] sdr_data
);
	logic BLA;
	logic [3:0] B1VP;
	logic [10:0] B1CG;
	logic [3:0] B1HP;
	logic BINV1;
	logic [2:0] B1P;

	//Registers Section:

`ifdef DEFAULT_REG_VALS
	// logic [7:0] ic79_Q = 8'h00; //3A00W //Scroll X
	// logic ic9A_Q = 1'b0;        //3A01W
	// logic [7:0] ic78_Q = 8'h00; //3A02W //Scroll Y
	// logic ic9B_Q = 1'b1;        //3A03W

	//Desert Stage
	logic [7:0] ic79_Q = 8'hCF; //3A00W //Scroll X
	logic ic9A_Q = 1'b0;        //3A01W
	logic [7:0] ic78_Q = 8'h00; //3A02W //Scroll Y
	logic ic9B_Q = 1'b1;        //3A03W
`else
	//Scroll X
	//3A00W
	logic [7:0] ic79_Q;
	ttl_74273_sync ic79(.CLRn(1'b1), .Clk(clk), .Cen(W3A00n), .D(DB_in), .Q(ic79_Q));
	//3A01W
	logic ic9A_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic9A(
		.clk(clk),
		.din(DB_in[0]),
		.q(ic9A_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(W3A01n) // signal whose edge will trigger the FF
  	);

	//Scroll Y
	//3A02W
	logic [7:0] ic78_Q;
	ttl_74273_sync ic78(.CLRn(1'b1), .Clk(clk), .Cen(W3A02n), .D(DB_in), .Q(ic78_Q));
	//3A03W
	logic ic9B_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic9B(
		.clk(clk),
		.din(DB_in[0]),
		.q(ic9B_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(W3A03n) // signal whose edge will trigger the FF
  	);
`endif

	//This replaces TTL LS283 ICs: ic97, ic96, ic77, ic76
	//LS86 ICs: ic60 (b,c,d)
	logic [8:0] SUM_X, SUM_Y;
	assign SUM_X = {ic9A_Q,ic79_Q} + {DVCUNT,DHPOS,HPOS}; //ignores carry out
	assign SUM_Y = {ic9B_Q,ic78_Q} + {1'b0,DVPOS};

	assign B1VP = SUM_Y[3:0];

	logic [7:0] ic95_Q;
	ttl_74273_sync ic95(.CLRn(1'b1), .Clk(clk), .Cen(HCLKn), .D(SUM_X[7:0]), .Q(ic95_Q));	
	assign B1HP = ic95_Q[3:0];

	logic ic63B_Q;
	DFF_pseudoAsyncClrPre #(.W(1)) ic63B(
		.clk(clk),
		.din(SUM_X[8]),
		.q(ic63B_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(HCLKn) // signal whose edge will trigger the FF
  	);

	logic ic75a; //NOT gate
	assign ic75a = ~M1Hn;

	logic [3:0] ic94_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic94 
	(.Enable_bar(1'b0),.Select(BACK1SELn),
	.A_2D({ic95_Q[7],AB[3],ic95_Q[6],AB[2],ic95_Q[5],AB[1],ic95_Q[4],AB[0]}),
	.Y(ic94_Y));

	logic [3:0] ic93_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic93 
	(.Enable_bar(1'b0),.Select(BACK1SELn),
	.A_2D({SUM_Y[7],AB[7],SUM_Y[6],AB[6],SUM_Y[5],AB[5],SUM_Y[4],AB[4]}),
	.Y(ic93_Y));

	logic [3:0] ic110_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic110 
	(.Enable_bar(1'b0),.Select(BACK1SELn),
	.A_2D({1'b1,WDn,ic75a,AB[10],SUM_Y[8],AB[9],ic63B_Q,AB[8]}),
	.Y(ic110_Y));

	//TMM2018-55 2Kx8bit 55ns SRAM
	logic [7:0] SRAM_Din, SRAM_Dout;
	//"xs_title_bgram1_vmem.txt"
	// SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_jungle_back2.bin_vmem.txt")) ic121(
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_desert_bgram1.bin_vmem.txt")) ic121(
	//SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("xs_title_bgram1_vmem.txt")) ic121(
		.clk(clk),
		.ADDR({ic110_Y[2:0],ic93_Y[3:0],ic94_Y[3:0]}),
		.DATA(SRAM_Din),
		.cen(1'b1), //active high
		.we(~ic110_Y[3]), //active high
		.Q(SRAM_Dout)
    );

	logic ic16d; //OR gate
	assign ic16d = (M1Hn | BACK1SELn);

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces tri-state logic ---
// This replaces TTL logic LS245 ICs: ic80
// Adds one master clock period delay
	//BACK1 Tilemap SRAM data output
	always_ff @(posedge clk) begin
		if (RW && !ic16d) DB_out <= SRAM_Dout;
		else              DB_out <= 8'hFF; //replaces hi-Z bus state
	end

	//BACK1 Tilemap SRAM data input
	always_ff @(posedge clk) begin
		if(!RW && !ic16d)      SRAM_Din <= DB_in;
		else                   SRAM_Din <= 8'hFF; //replaces hi-Z bus state
	end
//-------------------------------------------------------------------------------

	logic [7:0] ic81_Q;
	ttl_74273_sync ic81(.CLRn(1'b1), .Clk(clk), .Cen(T2n), .D(SRAM_Dout), .Q(ic81_Q));

	logic [7:0] ic98_Q;
	ttl_74273_sync ic98(.CLRn(1'b1), .Clk(clk), .Cen(BLA), .D(ic81_Q), .Q(ic98_Q));

	logic [6:0] ic82_Q;
	ttl_74273_sync #(.BLOCKS(7)) ic82(.CLRn(1'b1), .Clk(clk), .Cen(T3n), .D({SRAM_Dout[7:4],SRAM_Dout[2:0]}), .Q(ic82_Q));

	logic [6:0] ic99_Q;
	ttl_74273_sync #(.BLOCKS(7)) ic99(.CLRn(1'b1), .Clk(clk), .Cen(BLA), .D(ic82_Q), .Q(ic99_Q));

	assign B1CG = {ic99_Q[2:0], ic98_Q[7:0]};
	assign B1P = ic99_Q[5:3];
	assign BINV1 = ic99_Q[6];


	//---------- ROM SECTION ------------
	logic ic62b, ic61d; //XOR gate
	assign ic62b = (BINV1 ^ B1HP[2]);
	assign ic61d = (BINV1 ^ B1HP[3]);

	logic ic48a; //NOT gate
	assign ic48a = ~ic61d;

	//--- Intel P27256 32Kx8 BACK1 ROM 250ns ---
	// ROMH: IC136,IC135,IC134,IC133
	// ROML: IC114,IC113,IC112,IC111
	//*** START OF BACK1 ROM address request generator ***
	// logic [24:0] req_ROM_addr;
	// logic ROM_req;
	// logic ROM_data_rdy;
	// logic [15:0] ROM_data;
	logic [7:0] ROMH, ROML;

	logic last_HCLKn;
	logic [12:0] curr_ROM13_addr;
	logic [12:0] last_ROM13_addr = 13'h0;

	assign curr_ROM13_addr = {B1CG[10:0],ic48a,ic62b};

	always_ff @(posedge clk_ram) begin
		last_HCLKn <= HCLKn;
		sdr_req<= 1'b0;

		if(last_HCLKn && !HCLKn) begin//detect falling edge
			last_ROM13_addr <= curr_ROM13_addr;

			//Dont make address request while the system is resetting
			if(!RESETn) begin
				sdr_addr <= REGION_ROM_BACK1.base_addr[24:0] | 17'h0;
				sdr_req <= 1'b0;
			end
			//ignore address changes based on B1VP
			else if (last_ROM13_addr != curr_ROM13_addr) begin
				sdr_addr <= REGION_ROM_BACK1.base_addr[24:0] | {curr_ROM13_addr,B1VP[3:0],1'b0};
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

	// sdr_req_manager_single back1_sdr_req_man(
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
	//*** END OF BACK1 ROM address request generator ***

	logic ic61a,ic61b,ic61c; //XOR gate
	logic ic26b; //AND gate
	logic ic48d; //NOT gate

	assign ic61a = (P1_P2n ^ B1HP[0]);
	assign ic61b = (P1_P2n ^ B1HP[1]);
	assign ic61c = (P1_P2n ^ B1HP[2]);
	assign ic26b = (ic61a & ic61b);
	assign ic48d = ~ic61c;
	assign BLA = ic48d;

	logic ic62d; //XOR gate
	logic [1:0] ic132_Y;

	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic132
	(.Enable_bar(1'b0),.Select(ic62d),
	.A_2D({1'b1,ic26b,ic26b,1'b1}),
	.Y(ic132_Y));

	logic [3:0] ic65_Q;
	ttl_74174_sync #(.BLOCKS(4)) ic65
    (
        .Clk(clk),
        .Cen(ic61c),
        .Clr_n(1'b1),
        .D({B1P[2:0],BINV1}),
        .Q(ic65_Q)
    );

	assign ic62d = (P1_P2n ^ ic65_Q[0]);

	//2 DSR, 7 DSL, 9 S0, 10 S1, 6-3 P3-0, 12-15 Q3-0 
	// S1 S0 Dsr
	//  0  1   1  Shift Righ    {Dsr,q0, q1, q2} -> {Q3,Q2,Q1,Q0}
	//  1  1   1  Parallel Load {D3,D2,D1,D0} -> {Q3,Q2,Q1,Q0}
	logic [3:0] ic152_Q;
	ttl_74194_sync ic152
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic132_Y[1]), .S1(ic132_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[0]), .D1(ROMH[1]), .D2(ROMH[2]), .D3(ROMH[3]),
		.Q0(ic152_Q[0]), .Q1(ic152_Q[1]), .Q2(ic152_Q[2]), .Q3(ic152_Q[3]));

	logic [3:0] ic151_Q;
	ttl_74194_sync ic151
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic132_Y[1]), .S1(ic132_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[4]), .D1(ROMH[5]), .D2(ROMH[6]), .D3(ROMH[7]),
		.Q0(ic151_Q[0]), .Q1(ic151_Q[1]), .Q2(ic151_Q[2]), .Q3(ic151_Q[3]));

	logic [3:0] ic150_Q;
	ttl_74194_sync ic150
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic132_Y[1]), .S1(ic132_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[0]), .D1(ROML[1]), .D2(ROML[2]), .D3(ROML[3]),
		.Q0(ic150_Q[0]), .Q1(ic150_Q[1]), .Q2(ic150_Q[2]), .Q3(ic150_Q[3]));

	logic [3:0] ic149_Q;
	ttl_74194_sync ic159
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic132_Y[1]), .S1(ic132_Y[0]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[4]), .D1(ROML[5]), .D2(ROML[6]), .D3(ROML[7]),
		.Q0(ic149_Q[0]), .Q1(ic149_Q[1]), .Q2(ic149_Q[2]), .Q3(ic149_Q[3]));

	logic [3:0] ic153_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic153
	(.Enable_bar(1'b0),.Select(ic62d),
	.A_2D({ic149_Q[3],ic149_Q[0],ic150_Q[3],ic150_Q[0],ic151_Q[3],ic151_Q[0],ic152_Q[3],ic152_Q[0]}),
	.Y(ic153_Y));
	//-----------------------------------------------------------------------
	assign B1COL = {ic153_Y[3],ic153_Y[2],ic153_Y[1],ic153_Y[0]}; //Palette color index (0-15)
	assign B1PAL = ic65_Q[3:1]; //Palette color bank (0-7)
endmodule