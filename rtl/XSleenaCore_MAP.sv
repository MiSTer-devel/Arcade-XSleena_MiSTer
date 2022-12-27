//XSleenaCore_MAP.sv
//Author: @RndMnkIII
//Date: 11/10/2022
//Schematics: page 9A
`default_nettype none
`timescale 1ns/100ps
`define CPU_OVERCLOCK_HACK

//Text RAM tilemap address mapping: 0x2000-27FF
module XSleenaCore_MAP (
	input wire clk,
	//CPU Clocking
	input wire main_2xb,
	
	input wire [7:0] HN,
	input wire M4Hn,
	input wire [10:0] AB, //2K range
	input wire [5:0] DHPOS,
	input wire [7:0] DVPOS,
	input wire WDn,
	input wire M1Hn,
	input wire MAPSELn,
	input wire RW,
	input wire [7:0] DB_in,
	output logic [7:0] DB_out,
	input wire [1:0] HPOS, //uses only 1
	input wire HCLKn, //HCLK2n
	input wire P1_P2n,
	output logic [6:0] MAP,

	//ROM interface
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input bram_cs,

	//Greetings screen shog
	input show_kofi
);

logic ic16a; //OR gate
//CPU OVERCLOCK HACK
// `ifdef CPU_OVERCLOCK_HACK
	assign ic16a = (main_2xb| MAPSELn); //this selector enables MAP tilemap SRAM input/output external data bus
// `else
// 	assign ic16a = (M1Hn | MAPSELn); //this selector enables MAP tilemap SRAM input/output external data bus
// `endif

	logic [7:0] SRAM_Din, SRAM_Dout, SRAM_Dout1, SRAM_Dout2, SRAM_Dout3;

	//--- SONY CXK5816P-10 2Kx8 100ns SRAM ---
//CPU OVERCLOCK HACK
// `ifdef CPU_OVERCLOCK_HACK
	SRAM_dual_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("rnd2K.bin_vmem.txt")) ic23(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(AB[10:0]),
		.ADDR1({HN[2], DVPOS[7:3], DHPOS[5:1]}),
		.DATA0(SRAM_Din),
		.DATA1(8'h00),
		.cen0(1'b1),
		.cen1(1'b1),
		.we0(MAPSELn ? 1'b0 : ~WDn),
		.we1(1'b0),
		.Q0(SRAM_Dout),
		.Q1(SRAM_Dout3)
	);

	SRAM_dual_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("rnd2K.bin_vmem.txt")) ic23_greets(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(AB[10:0]),
		.ADDR1({HN[2], DVPOS[7:3], DHPOS[5:1]}),
		.DATA0(SRAM_Din),
		.DATA1(8'h00),
		.cen0(1'b0),
		.cen1(1'b1),
		.we0(1'b0),
		.we1(1'b0),
		.Q0(),
		.Q1(SRAM_Dout1)
	);

	assign SRAM_Dout2 = (show_kofi) ? SRAM_Dout1 : SRAM_Dout3;
// `else
// 	logic [3:0] ic25_Y;
// 	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic25 
// 	(.Enable_bar(1'b0),.Select(MAPSELn),
// 	.A_2D({DHPOS[4], AB[3], DHPOS[3], AB[2], DHPOS[2], AB[1], DHPOS[1], AB[0]}),
// 	.Y(ic25_Y));

// 	logic [3:0] ic22_Y; //IC22???
// 	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic22
// 	(.Enable_bar(1'b0),.Select(MAPSELn),
// 	.A_2D({DVPOS[5], AB[7], DVPOS[4], AB[6], DVPOS[3], AB[5], DHPOS[5], AB[4]}),
// 	.Y(ic22_Y));

// 	logic [3:0] ic39_Y;
// 	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic39 
// 	(.Enable_bar(1'b0),.Select(MAPSELn),
// 	.A_2D({1'b1, WDn, HN[2], AB[10], DVPOS[7], AB[9], DVPOS[6], AB[8]}),
// 	.Y(ic39_Y));

// 	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("rnd2K.bin_vmem.txt")) ic23(
// 		.clk(clk),
// 		.ADDR({ic39_Y[2:0],ic22_Y[3:0],ic25_Y[3:0]}),
// 		.DATA(SRAM_Din),
// 		.cen(1'b1), //active high
// 		.we(~ic39_Y[3]), //active high
// 		.Q(SRAM_Dout)
//     );

// 	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("greetings_vmem.txt")) ic23_greets(
// 		.clk(clk),
// 		.ADDR({ic39_Y[2:0],ic22_Y[3:0],ic25_Y[3:0]}),
// 		.DATA(8'h00),
// 		.cen(1'b1), //active high
// 		.we(1'b0), //active high
// 		.Q(SRAM_Dout1)
//     );

// 	assign SRAM_Dout2 = (show_kofi) ? SRAM_Dout1 : SRAM_Dout;
// `endif

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces ic7 tri-state logic ---
// This replaces TTL logic LS245 ICs: ic7
// Adds one master clock period delay
	//MAP Tilemap SRAM data output
	always_ff @(posedge clk) begin
		if (RW && !ic16a) DB_out <= SRAM_Dout;
		else              DB_out <= 8'hFF; //replaces hi-Z bus state
	end

	//MAP Tilemap SRAM data input
	always_ff @(posedge clk) begin
		if(!RW && !ic16a)      SRAM_Din <= DB_in;
		else                   SRAM_Din <= 8'hFF; //replaces hi-Z bus state
	end
//-------------------------------------------------------------------------------

	logic [7:0] ic8_Q;
	ttl_74273_sync ic8(.CLRn(1'b1), .Clk(clk), .Cen(HN[2]), .D(SRAM_Dout2), .Q(ic8_Q));

	logic [9:0] MAP_ROM_ADDR;
	assign MAP_ROM_ADDR[7:0] = ic8_Q[7:0];
	
	logic [7:0] ic55_Q;
	ttl_74273_sync ic55(.CLRn(1'b1), .Clk(clk), .Cen(M4Hn), .D({ic55_Q[4],ic55_Q[3],ic55_Q[2],SRAM_Dout2[7],SRAM_Dout2[6],SRAM_Dout2[5],SRAM_Dout2[1],SRAM_Dout2[0]}), .Q(ic55_Q));
	
	logic [1:0] ic54_Q;
	ttl_74174_sync #(.BLOCKS(2)) ic54
    (
        .Clk(clk),
        .Cen(HN[2]),
        .Clr_n(1'b1),
        .D(ic55_Q[1:0]),
        .Q(ic54_Q)
    );
	assign MAP_ROM_ADDR[9:8] = {ic54_Q[1],ic54_Q[0]};

	//--- Intel P27256 32Kx8 MAP ROM 250ns ---
	logic [7:0] MAP_ROM_Dout, MAP_ROM_Dout_dly;
	logic ROM_DATA_PLOAD = 1'b0;

	//*** START OF MAP ROM request generator ****
	logic [14:0] req_ROM_addr;
	logic ROM_req;
	logic [14:0] curr_ROM_addr;
	logic [14:0] last_ROM_addr = 15'h0;


	assign curr_ROM_addr = {MAP_ROM_ADDR[9:0],DHPOS[0],HPOS[1],DVPOS[2:0]};
	always_ff @(posedge clk) begin
		ROM_req <= 1'b0;
		last_ROM_addr <= curr_ROM_addr;
		
		if(last_ROM_addr != curr_ROM_addr) begin
			ROM_req <= 1'b1;
			req_ROM_addr <= curr_ROM_addr;
		end
	end
	//*** END OF MAP ROM request generator ***

	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("pb-01.ic24_vmem.txt")) ic24 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //active high
	// 	.ADDR(req_ROM_addr), 
	// 	.DATA(MAP_ROM_Dout)
	// );

	//PORT0: ROM load interface
	//PORT1: normal ROM access interface
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic24(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1(req_ROM_addr),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs),
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(MAP_ROM_Dout)
	);

	logic [1:0] ic41_Y;
	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic41
	(.Enable_bar(1'b0),.Select(P1_P2n),
	.A_2D({1'b1,HN[0],HN[0],1'b1}),
	.Y(ic41_Y));

	//fix ic41_Y delay
	logic [1:0] ic41_Yfix;
	always_ff @(posedge clk) begin
		ic41_Yfix <= ic41_Y;
	end

	//*** CHECK PLOAD OF ROM DATA ***
	logic last_HCLKn;
	always_ff @(posedge clk) begin
	last_HCLKn <= HCLKn;
	ROM_DATA_PLOAD <= 1'b0;
		//if (!RESETn) ROM_DATA_PLOAD <= 1'b0;
		if(last_HCLKn && !HCLKn && (ic41_Yfix == 2'd3)) begin
			ROM_DATA_PLOAD <= 1'b1;
		end
	end

	//2 DSR, 7 DSL, 9 S0, 10 S1, 6-3 P3-0, 12-15 Q3-0 
	// S1 S0 Dsr
	//  0  1   1  Shift Righ    {Dsr,q0, q1, q2} -> {Q3,Q2,Q1,Q0}
	//  1  1   1  Parallel Load {D3,D2,D1,D0} -> {Q3,Q2,Q1,Q0}
	logic [3:0] ic56_Q;
	ttl_74194_sync ic56
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic41_Yfix[1]), .S1(ic41_Yfix[0]), //HCLK2n
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(MAP_ROM_Dout[0]), .D1(MAP_ROM_Dout[1]), .D2(MAP_ROM_Dout[2]), .D3(MAP_ROM_Dout[3]),
		.Q0(ic56_Q[0]), .Q1(ic56_Q[1]), .Q2(ic56_Q[2]), .Q3(ic56_Q[3]));

	logic [3:0] ic40_Q;
	ttl_74194_sync ic40
		(.clk(clk), .cen(HCLKn),.CR_n(1'b1), .S0(ic41_Yfix[1]), .S1(ic41_Yfix[0]), //HCLK2n
		.Dsl(1'b0), .Dsr(1'b0), //   
		.D0(MAP_ROM_Dout[4]), .D1(MAP_ROM_Dout[5]), .D2(MAP_ROM_Dout[6]), .D3(MAP_ROM_Dout[7]),
		.Q0(ic40_Q[0]), .Q1(ic40_Q[1]), .Q2(ic40_Q[2]), .Q3(ic40_Q[3]));

	logic [3:0] ic57_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic57
	(.Enable_bar(1'b0),.Select(P1_P2n),
	.A_2D({ic56_Q[3],ic56_Q[2],ic40_Q[1],ic40_Q[0],ic40_Q[3],ic40_Q[2],ic56_Q[1],ic56_Q[0]}),
	.Y(ic57_Y));

	logic [7:0] ic58_Q;
	ttl_74273_sync ic58(.CLRn(1'b1), .Clk(clk), .Cen(HCLKn), .D({ic57_Y[0],ic57_Y[3],ic57_Y[2],ic57_Y[1],ic58_Q[4],ic58_Q[5],ic58_Q[6],ic58_Q[7]}), .Q(ic58_Q));

	logic [7:0] ic59_Q;
	ttl_74273_sync ic59(.CLRn(1'b1), .Clk(clk), .Cen(HCLKn), .D({1'b0,ic55_Q[7],ic55_Q[6],ic55_Q[5],ic58_Q[3],ic58_Q[2],ic58_Q[1],ic58_Q[0]}), .Q(ic59_Q));

	assign MAP = ic59_Q[6:0];
endmodule