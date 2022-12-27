//XSleenaCore.sv
//Author: @RndMnkIII
//Date: 11/10/2022
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARSTnRTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

`default_nettype none
`timescale 1ns/100ps
`define RENDER_OBJ_LAYER
`define RENDER_MAP_LAYER
`define RENDER_BACK1_LAYER
`define RENDER_BACK2_LAYER
`define CPU_OVERCLOCK_HACK

module XSleenaCore (
	input wire CLK,
	input wire SDR_CLK,
	input wire RSTn,
	input wire NATIVE_VFREQ,

	//inputs
	input wire [7:0] DSW1,
	input wire [7:0] DSW2,
	input wire [7:0] PLAYER1,
	input wire [7:0] PLAYER2,
	input wire SERVICE,
	input wire JAMMA_24,
	input wire JAMMA_b,

	//Video output
	output logic CSYNC,
	output logic [3:0] VIDEO_R,
	output logic [3:0] VIDEO_G,
	output logic [3:0] VIDEO_B,
	output logic PIX_CLK,
	output logic CE_PIXEL,
	output logic HBLANK,
	output logic VBLANK,
	output logic HSYNC,
	output logic VSYNC,

	//Memory interface
    output [24:0] sdr_mcpu_addr,
    input [15:0] sdr_mcpu_dout,
    output sdr_mcpu_req,
    input sdr_mcpu_rdy,

    output [24:0] sdr_scpu_addr,
    input [15:0] sdr_scpu_dout,
    output sdr_scpu_req,
    input sdr_scpu_rdy,

    output [24:0] sdr_obj_addr,
    input [15:0] sdr_obj_dout,
    output sdr_obj_req,
    input sdr_obj_rdy,

    output [24:0] sdr_bg1_addr,
    input [15:0] sdr_bg1_dout,
    output sdr_bg1_req,
    input sdr_bg1_rdy,

    output [24:0] sdr_bg2_addr,
    input [15:0] sdr_bg2_dout,
    output sdr_bg2_req,
    input sdr_bg2_rdy,

    // output [24:0] sdr_map_addr,
    // input [15:0] sdr_map_dout,
    // output sdr_map_req,
    // input sdr_map_rdy,

    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input [5:0] bram_cs,

	//sound output
   output logic signed [15:0] snd1,
	output logic signed [15:0] snd2,
	output logic sample,

	//coin counters
	output logic CUNT1, //to coin counter 1
	output logic CUNT2, //to coin counter 2

	//pause interface
	input  wire  pause_rq,

	//hacks interface
	input wire [1:0] CPU_turbo_mode //{turbo_m,turbo_s}
);
	//Clocking signals
	logic HCLK, HCLKn;
	logic [7:0] HN;
	logic [1:0] HPOS;
	logic [5:0] DHPOS;
	logic DVCUNT;
	logic VCUNT;
	logic M4Hn;
    logic VI;
	logic VBLK;
    logic [7:0] VPOS;
    logic [7:0] DVPOS;
    logic VBLKn;
    logic IMS;
    logic T1n;
    logic T2n;
    logic T3n;
    logic T3;
    logic M0n;
    logic M1n;
    logic M2n;
    logic M3n;
    logic CLRn;
    logic BLKn;
    logic EDIT;
    logic EDITn;
    logic OBJCHG;
    logic OBJCHGn;
    logic OBJCLRn;
    logic RAMCLRn;
    logic OBCH;

	//IO map signals
	logic R3A04n; //MCU data read
	logic R3A06n; //MCU reset
	logic W3A08n; //Sound latch
	logic W3A09n; //maincpu NMI clear
	logic W3A0An; //maincpu FIRQ clear
	logic W3A0Bn; //maincpu IRQ clear
	logic W3A0Cn; //subcpu IRQ assert
	logic W3A0En; //MCU data write
	logic [3:0] IOWDn;
	logic W3A04n;
	logic W3A05n;
	logic W3A06n;
	logic W3A07n;
	logic P1_P2n;
	logic P1_P2;
	logic [2:0] PRI; //Layer priority register
	logic BSL; //maincpu ROM bank switch

	logic MAPSELn;
	logic BACK1SELn;
	logic BACK2SELn;
	logic OBJSELn;
	logic IOn;
	logic PLSELn;

	logic [7:0] MAP_Dout, BACK1_Dout, BACK2_Dout, OBJ_Dout, PLRAM_Dout, IO_Dout;

	//Clock CEN generator
	logic CLK12_CEN, CLK12n_CEN;
	logic HCLK_CEN, HCLKn_CEN;

	jtframe_frac_cen #(.WC(8), .W(2)) xs_clkcen
	(
		.clk(CLK),
		.n(8'd1),
		.m(8'd4),
		.cen({HCLK_CEN, CLK12_CEN})
	);

	//CPU Turbo mode Hack
	logic main_1x,  main_1xb; //M2H, M2Hn
	logic main_2x,  main_2xb; //M1H, M1Hn
	logic main_4x,  main_4xb; //HCLK, HCLKn
	logic sub_1x,  sub_1xb;
	logic sub_2x,  sub_2xb;
	logic sub_4x,  sub_4xb;

	always_comb begin //maincpu
		case(CPU_turbo_mode[1])
			1'd0: begin //1.00x 
				main_1x = M2H; main_2x = M1H; main_4x = _HCLK;
				main_1xb = M2Hn; main_2xb = M1Hn; main_4xb = _HCLKn;
			end
			1'd1: begin //2.00x
				main_1x = M1H; main_2x = _HCLK; main_4x = CLK12_CEN;
				main_1xb = M1Hn; main_2xb = _HCLKn; main_4xb = ~CLK12_CEN;
			end
		endcase
	end

	always_comb begin //subcpu
		case(CPU_turbo_mode[0])
			1'd0: begin //1.00x 
				sub_1x = M2H; sub_2x = M1H; sub_4x = _HCLK;
				sub_1xb = M2Hn; sub_2xb = M1Hn; sub_4xb = _HCLKn;
			end
			1'd1: begin //2.00x
				sub_1x = M1H; sub_2x = _HCLK; sub_4x = CLK12_CEN;
				sub_1xb = M1Hn; sub_2xb = _HCLKn; sub_4xb = ~CLK12_CEN;
			end
		endcase
	end

	//  --------------------------
	// |    CONNECTORS (J1,J2)    |
	//  --------------------------
	// SHARED SIGNALS BETWEEN TOP AND BOTTOM BOARDS
	// See schematics pages 10A and 10B

    (* keep *) logic M2H, M2Hn;
    (* keep *) logic M1H, M1Hn;
	(* keep *) logic _HCLK;
	(* keep *) logic _HCLKn;
	logic _P1_P2n;

    assign M2H = HN[1];
    assign M2Hn = ~HN[1];
    assign M1H = HN[0];
    assign M1Hn = ~HN[0];
	assign _HCLKn = HCLKn;
	assign _HCLK = ~HCLKn;
	assign _P1_P2n = ~P1_P2;

	logic W3A00n, W3A01n, W3A02n, W3A03n;
	assign {W3A03n, W3A02n, W3A01n, W3A00n} = IOWDn;
    logic [15:0] AB; //shared address bus
    logic [7:0] DB_in, DB_out; //shared data bus
	logic RW;
	logic WDn;

	//  --------------------------
	// |       BOTTOM BOARD       |
	//  --------------------------
	// Schematics pages: 1-9A

	//Schematics pages: 1A,2A
	//Generate HCLKn_CEN, detect rising edge
	logic last_HCLKn;
	always @(posedge CLK) begin
		last_HCLKn <= HCLKn;
		//HCLKn_CEN <= 1'b0;
		//if(!last_HCLKn && HCLKn) HCLKn_CEN <= 1'b1;
	end
	assign HCLKn_CEN = ~last_HCLKn & HCLKn;

	XSleenaCore_CLK xs_clk( 
		.clk(CLK), //48MHz or 60MHz
		.clk_12_cen(CLK12_CEN),
		.RSTn(RSTn),
		.P1_P2n(_P1_P2n),
		//clocks
		//H counter signals
		.HCLK(HCLK), //HCLK
        .HCLKn(HCLKn), //HCLK3,HCLK2,HCLK1,HCLK0
		.HN(HN),
		//.M1Hn(M1Hn),
		.HPOS(HPOS),
		.DHPOS(DHPOS),
		.DVCUNT(DVCUNT),
		.VCUNT(VCUNT),
		.M4Hn(M4Hn),
        //V counter signals
        .VI(VI),
        .VPOS(VPOS),
        .DVPOS(DVPOS),
        .IMS(IMS),
        //Video signals
        .VBLK(VBLK),
        .VBLKn(VBLKn),
		.VSYNC(VSYNC),
		.HSYNC(HSYNC),
        .CSYNC(CSYNC),
        //Other clocking signals
        .T1n(T1n),
        .T2n(T2n),
        .T3n(T3n),
        .T3(T3),
        .M0n(M0n),
        .M1n(M1n),
        .M2n(M2n),
        .M3n(M3n),
        .CLRn(CLRn),
        .BLKn(BLKn),
        .EDIT(EDIT),
        .EDITn(EDITn),
        .OBJCHG(OBJCHG),
        .OBJCHGn(OBJCHGn),
        .OBJCLRn(OBJCLRn),
        .RAMCLRn(RAMCLRn),
        .OBCH(OBCH)
	);

	//Generate signals for main,sub CPU for turbo modes


	//MiSTer Video signals
	//
	//HSYNC
	//VSYNC
	assign PIX_CLK  = HCLKn;
	assign HBLANK   = BLKn;
	assign VBLANK   = VBLKn;
	assign CE_PIXEL = HCLKn_CEN;
	

	//Schematics pages: 7A,8A
	logic [6:0] BACK1COL;
	XSleenaCore_BACK1 xs_back1(
		.clk(CLK),
		.clk_ram(SDR_CLK),
		//CPU Clocking
		.main_2xb(main_2xb),
		.RESETn(RSTn),
		.M1Hn(M1Hn),
		.AB(AB[10:0]),
		.DHPOS(DHPOS),
		.DVCUNT(DVCUNT),
		.DVPOS(DVPOS),
		.BACK1SELn(BACK1SELn),
		.RW(RW),
		.WDn(WDn),
		.DB_in(DB_out),
		.DB_out(BACK1_Dout),
		.HPOS(HPOS),
		.HCLKn(HCLKn),
		.T2n(T2n),
		.T3n(T3n),
		.P1_P2n(P1_P2n),
		//Registers (they come from TOP BOARD)
		.W3A00n(W3A00n),
		.W3A01n(W3A01n),
		.W3A02n(W3A02n),
		.W3A03n(W3A03n),
		//Output color and palette
		.B1COL(BACK1COL[3:0]),
		.B1PAL(BACK1COL[6:4]),
		//SDRAM ROM interface
		.sdr_addr(sdr_bg1_addr),
		.sdr_req(sdr_bg1_req),
		.sdr_rdy(sdr_bg1_rdy),
		.sdr_data(sdr_bg1_dout)
	);

	//Schematics pages: 9A
	logic [6:0] MAPCOL;
	XSleenaCore_MAP xs_map(
		.clk(CLK),
		//CPU Clocking
		.main_2xb(main_2xb),
		
		.HN(HN),
		.M4Hn(M4Hn),
		.AB(AB[10:0]),
		.DHPOS(DHPOS),
		.DVPOS(DVPOS),
		.WDn(WDn),
		.M1Hn(M1Hn),
		.MAPSELn(MAPSELn),
		.RW(RW),
		.DB_in(DB_out),
		.DB_out(MAP_Dout),
		.HPOS(HPOS), //uses only 1
		.HCLKn(HCLKn), //HCLK2n
		.P1_P2n(P1_P2n),
		.MAP(MAPCOL),
		//SDRAM ROM interface
		// .sdr_addr(sdr_map_addr),
		// .sdr_req(sdr_map_req),
		// .sdr_rdy(sdr_map_rdy),
		// .sdr_data(sdr_map_dout),
		//ROM interface
		.bram_wr(bram_wr),
		.bram_data(bram_data),
		.bram_addr(bram_addr),
		.bram_cs(bram_cs[3]),
		//greetings interface
		.show_kofi(pause_rq)
	);

	//Schematics pages: 3A,4A,5A,6A
	logic [6:0] OBJ;
	XSleenaCore_OBJ xs_obj(
		.clk(CLK),
		.clk_ram(SDR_CLK),
		//CPU Clocking
		.main_2xb(main_2xb),

		.M1Hn(M1Hn),
		.OBJSELn(OBJSELn),
		.AB(AB[8:0]), //only 512bytes accesible
		.DB_in(DB_out),
		.DB_out(OBJ_Dout),
		.HN(HN),
		.WDn(WDn),
		.VCUNT(VCUNT),
		.RW(RW),
		.DHPOS(DHPOS),
		.DVCUNT(DVCUNT),
		.HCLKn(HCLKn), //HCLK0n
		.HCLK(HCLK),
		.T1n(T1n),
		.T2n(T2n),
		.T3n(T3n),
		.T3(T3),
		.VBLK(VBLK),
		.VBLKn(VBLKn),
		.VPOS(VPOS),
		.OBJCLRn(OBJCLRn),
		.RAMCLRn(RAMCLRn),
		.OBJCHG(OBJCHG),
		.OBJCHGn(OBJCHGn),
        .OBCH(OBCH),
		.M0n(M0n),
		.M1n(M1n),
		.M2n(M2n),
		.M3n(M3n),
		.EDIT(EDIT),
		.EDITn(EDITn),
		.CLRn(CLRn),
		.P1_P2n(P1_P2n),
		//output color and palette
		.OBJ(OBJ),
		//SDRAM ROM interface
		.sdr_addr(sdr_obj_addr),
		.sdr_req(sdr_obj_req),
		.sdr_rdy(sdr_obj_rdy),
		.sdr_data(sdr_obj_dout)
	);

	//  --------------------------
	// |         TOP BOARD        |
	//  --------------------------
	// Schematics pages: 1-9B

	//---- Main CPU input data bus selector
	always_comb begin
		if(RW && !MAPSELn && !main_2xb)         DB_in = MAP_Dout;
		else if(RW && !BACK1SELn && !main_2xb)  DB_in = BACK1_Dout;
		else if(RW && !BACK2SELn && !main_2xb)  DB_in = BACK2_Dout;
		else if(RW && !OBJSELn   && !main_2xb)  DB_in = OBJ_Dout;
		else if(RW && !PLSELn)                  DB_in = PLRAM_Dout;
		else if(RW && !IOn)                     DB_in = IO_Dout;
		else                                    DB_in = 8'hFF;
	end
//CPU OVERCLOCK HACK
// `ifdef CPU_OVERCLOCK_HACK
// 	always_comb begin
// 		if(RW && !MAPSELn && !HCLKn)         DB_in = MAP_Dout;
// 		else if(RW && !BACK1SELn && !HCLKn)  DB_in = BACK1_Dout;
// 		else if(RW && !BACK2SELn && !HCLKn)  DB_in = BACK2_Dout;
// 		else if(RW && !OBJSELn && !HCLKn)    DB_in = OBJ_Dout;
// 		else if(RW && !PLSELn)              DB_in = PLRAM_Dout;
// 		else if(RW && !IOn)                 DB_in = IO_Dout;
// 		else                                DB_in = 8'hFF;
// 	end
// `else
// 	always_comb begin
// 		if(RW && !MAPSELn && !M1Hn)         DB_in = MAP_Dout;
// 		else if(RW && !BACK1SELn && !M1Hn)  DB_in = BACK1_Dout;
// 		else if(RW && !BACK2SELn && !M1Hn)  DB_in = BACK2_Dout;
// 		else if(RW && !OBJSELn && !M1Hn)    DB_in = OBJ_Dout;
// 		else if(RW && !PLSELn)              DB_in = PLRAM_Dout;
// 		else if(RW && !IOn)                 DB_in = IO_Dout;
// 		else                                DB_in = 8'hFF;
// 	end
// `endif
	
	//Schematics pages: 1B,2B 
    XSleenaCore_cpuA_B xs_cpuAB( 
		.clk(CLK),
		.clk_ram(SDR_CLK),
		.clk12M_cen(CLK12_CEN),
		//CPU clocking
		.main_4x(main_4x),
		.main_4xb(main_4xb),
		.main_2x(main_2x),
		.main_2xb(main_2xb),
		.main_1x(main_1x),
		.main_1xb(main_1xb),
		.sub_4x(sub_4x),
		.sub_4xb(sub_4xb),
		.sub_2x(sub_2x),
		.sub_2xb(sub_2xb),
		.sub_1x(sub_1x),
		.sub_1xb(sub_1xb),

  	    .RSTn(RSTn),
		.VBLK(VBLK),
	    .W3A09n(W3A09n), //maincpu NMI clear
	    .W3A0Bn(W3A0Bn), //maincpu IRQ clear
	    .IMS(IMS),
	    .W3A0An(W3A0An), //maincpu FIRQ clear
	    .W3A0Cn(W3A0Cn), //subcpu IRQ assert
	    .M2H(M2H),
	    .M2Hn(M2Hn),
	    .M1H(M1H),
		.M1Hn(M1Hn),
		.HCLK(_HCLK), //clock for CPU_OVERCLOCK_HACK
	    .BSL(BSL), //ROM BANK Switch in 0x4000-0x7fff CPU address space
        //outputs
        .AB(AB[14:0]), //shared address bus
        .RW(RW), //maincpu RW
		.DB_in(DB_in),
        .DB_out(DB_out), //shared data bus, outputs
        .MAPSELn(MAPSELn),
        .BACK1SELn(BACK1SELn),
        .BACK2SELn(BACK2SELn),
        .OBJSELn(OBJSELn),
        .IOn(IOn),
        .PLSELn(PLSELn),
        .WDn(WDn),
		//SDRAM ROM interface
		.sdr_addr_a(sdr_mcpu_addr),
		.sdr_req_a(sdr_mcpu_req),
		.sdr_rdy_a(sdr_mcpu_rdy),
		.sdr_data_a(sdr_mcpu_dout),
		.sdr_addr_b(sdr_scpu_addr),
		.sdr_req_b(sdr_scpu_req),
		.sdr_rdy_b(sdr_scpu_rdy),
		.sdr_data_b(sdr_scpu_dout),
		//ROM interface
		.bram_wr(bram_wr),
		.bram_data(bram_data),
		.bram_addr(bram_addr),
		.bram_cs(bram_cs[1:0]), //MAIN+SUB CPUs ROM CODE
		//pause
		.pause_rq(pause_rq)
    );

	//Schematics pages: 3B 
	XSleenaCore_IO xs_io(
		.clk(CLK),
		.RSTn(RSTn),
		.AB(AB[3:0]), //maincpu address bus 0x0000-0x7fff
		.IOn(IOn),
		.RW(RW),
		//.VBLK(VBLK2n), //HACK should be VBLK
		.VBLK(VBLK),
		.DB_in(DB_out), //shared data bus, 
		.DB_out(IO_Dout),
		.PLAYER1(PLAYER1), //{COIN1,1P,1PSW2,1PSW1,1PD,1PU,1PL,1PR}
		.PLAYER2(PLAYER2), //{COIN2,2P,2PSW2,2PSW1,2PD,2PU,2PL,2PR}
		.SERVICE(SERVICE),
		.DSW1(DSW1),
		.DSW2(DSW2),
		.JAMMA_24(JAMMA_24), //Unknow Conn J3X2 D2 1S953, R32 1K, R35 100, 0.01uF
		.JAMMA_b(JAMMA_b),  //Unknow Conn J3X2 D3 1S953, R   1K, R   100, 0.01uF

		//only for MCU protected versions
		.P5READn(1'b1),
		.P5ACCEPTn(1'b1),
	
		//Outputs and register map
		.R3A04n(R3A04n), //MCU data read
		.R3A06n(R3A06n), //MCU reset
		.W3A08n(W3A08n), //Sound latch
		.W3A09n(W3A09n), //maincpu NMI clear
		.W3A0An(W3A0An), //maincpu FIRQ clear
		.W3A0Bn(W3A0Bn), //maincpu IRQ clear
		.W3A0Cn(W3A0Cn), //subcpu IRQ assert
		.W3A0En(W3A0En), //MCU data write
		.IOWDn(IOWDn),
		.W3A04n(W3A04n),
		.W3A05n(W3A05n),
		.W3A06n(W3A06n),
		.W3A07n(W3A07n),
		.CUNT1(CUNT1), //to coin counter 1
		.CUNT2(CUNT2), //to coin counter 2
		.P1_P2n(P1_P2n),
		.P1_P2(P1_P2),
		.PRI(PRI), //Layer priority register
		.BSL(BSL) //maincpu ROM bank switch
	);

	//Schematics pages: 5B, 6B 
	logic [6:0] BACK2COL;
	XSleenaCore_BACK2 xs_back2(
		.clk(CLK),
		.clk_ram(SDR_CLK),
		//CPU Clocking
		.main_2xb(main_2xb),

		.RESETn(RSTn),
		.M1Hn(M1Hn),
		.AB(AB[10:0]),
		.DHPOS(DHPOS),
		.DVCUNT(DVCUNT),
		.DVPOS(DVPOS),
		.BACK2SELn(BACK2SELn),
		.RW(RW),
		.WDn(WDn),
		.DB_in(DB_out),
		.DB_out(BACK2_Dout),
		.HPOS(HPOS),
		.HCLKn(_HCLKn),
		.T2n(T2n),
		.T3n(T3n),
		.P1_P2n(P1_P2n),
		//Registers
		.W3A04n(W3A04n),
		.W3A05n(W3A05n),
		.W3A06n(W3A06n),
		.W3A07n(W3A07n),
		//Output color and palette
		.B2COL(BACK2COL[3:0]),
		.B2PAL(BACK2COL[6:4]),
		//SDRAM ROM interface
		.sdr_addr(sdr_bg2_addr),
		.sdr_req(sdr_bg2_req),
		.sdr_rdy(sdr_bg2_rdy),
		.sdr_data(sdr_bg2_dout)
	);

	//Schematics pages: 4B
	XSleenacore_VideoMixer xs_vmix(
	 	.clk(CLK),
		.RW(RW),
		.DB_in(DB_out),
	 	.DB_out(PLRAM_Dout),
		.PLSELn(PLSELn),
		.AB(AB[9:0]), //1Kb
	`ifdef RENDER_MAP_LAYER
		.MAPCOL(MAPCOL),
	`else
		.MAPCOL(7'h0),
	`endif
	`ifdef RENDER_OBJ_LAYER
		.OBJCOL(OBJ),
	`else
		.OBJCOL(7'h0),
	`endif
	`ifdef RENDER_BACK1_LAYER
		.BACK1COL(BACK1COL),
	`else
		.BACK1COL(7'h0),
	`endif	
	`ifdef RENDER_BACK2_LAYER
		.B2COL(BACK2COL[3:0]),
		.B2PAL(BACK2COL[6:4]),
	`else
		.B2COL(4'h0),
		.B2PAL(3'h0),
	`endif
		.PRI(PRI),
		.WDn(WDn),
		.BLKn(BLKn),
		.HCLKn(_HCLKn),
		//output color
		.VIDEO_R(VIDEO_R),
		.VIDEO_G(VIDEO_G),
		.VIDEO_B(VIDEO_B),
		//ROM interface
		.bram_wr(bram_wr),
		.bram_data(bram_data),
		.bram_addr(bram_addr),
		.bram_cs(bram_cs[4])
	);
	
	//Schematics pages: 7,8B
	XSleenaCore_SoundCPU xs_snd(
	.clk(CLK),
	.HCLK(HCLK), //6MHz
	.M1H(M1H),
  	.RSTn(RSTn),
	.W3A08n(W3A08n), //Sound latch
	.DB_in(DB_out),
	.snd1(snd1), //combined FM+PSG
	.snd2(snd2), //combined FM+PSG
	.sample1(sample),
	.sample2(),
	//ROM interface
	.bram_wr(bram_wr),
	.bram_data(bram_data),
	.bram_addr(bram_addr),
	.bram_cs(bram_cs[2]),
	.pause_rq(pause_rq)
	);
endmodule