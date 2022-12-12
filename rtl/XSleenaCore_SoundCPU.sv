//XSleenaCore_SoundCPU.sv
//Author: @RndMnkIII
//Date: 15/11/2022

//frame:		command:	PC:
//68            FD          8816
//971			01			8816	
//1412			0F			8816
//1845			09			8816
//1850			8A			8816 ->  $000E:8A Stores sound code in RAM $0E, also uses $00, $02
//1851          09          ...

`default_nettype none
`timescale 1ns/10ps

module XSleenaCore_SoundCPU (
    input wire clk,
	input wire HCLK, //6MHz
	input wire M1H,
  	input wire RSTn,
	input wire W3A08n, //Sound latch
	input wire [7:0] DB_in,
	output logic signed [15:0] snd1, //combined FM+PSG
	output logic signed [15:0] snd2, //combined FM+PSG
	output logic sample1,
	output logic sample2,
	//ROM interface
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input bram_cs,
	input wire pause_rq
);
	logic SIRQn;
	logic SRDn, SWDn;
	logic OPN1n, OPN2n;

	//For simulation used the asynchronous version by Greg Miller
	logic sndcpu_RW;
	logic [15:0] SAB;
	logic [7:0] sndcpu_Din, sndcpu_Dout;
	logic sndcpu_E;
	logic ic27A_Qn;//sndcpu IRQn

	//**************************************
	//*** Sound Cpu (Schematics page 7B,8B) ***
	//**************************************
	//Interrupt vectors:
	//RESET (FFFE-FFFF) 0x8000 USED, FIRED by main RESET
	//NMI   (FFFC-FFFD) 0x8000
	//SWI   (FFFA-FFFB) 0x8000
	//IRQ   (FFF8-FFF9) 0x8816 USED, FIRED when maincpu writes to 
	//FIRQ  (FFF6-FFF7) 0x8E62 USED, FIRED when YM1 IRQn is SET
	//SWI2  (FFF4-FFF5) 0x8000
	//SWI3  (FFF2-FFF3) 0x8000

	//Real PCB uses a 68A09 CPU for Sound using the HCLK external clock source as XTAL input
	//in this implementation the clkE, clkQ falling edge clock enable signals are
	//generated from HCLK.

	//*** Start of Generate clkQf, clkEf from HCLKf_cen
	//Check falling edge of HCLK
	logic last_HCLK;
	logic HCLKf_cen;

	always @(posedge clk) begin
		last_HCLK <= HCLK;
	end

	always_comb begin
		HCLKf_cen = last_HCLK & ~HCLK;
	end

	logic [1:0] ckphase = 2'b00;
	logic    rE = 1'b0;
	logic    rQ = 1'b0;
	logic clkEf_cen;
	logic clkQf_cen;

	always @(posedge clk) begin
		if (HCLKf_cen) begin
			case (ckphase)
				2'b00:
					rE <= 0;
				2'b01:
					rQ <= 1;
				2'b10:
					rE <= 1;
				2'b11:
					rQ <= 0;
			endcase
			ckphase <= ckphase + 2'b01;
		end
	end

	// always_comb begin
	// 	clkEf_cen = HCLKf_cen & ~ckphase[1] & ~ckphase[0]; //00 Falling clkE
	// 	clkQf_cen = HCLKf_cen &  ckphase[1] &  ckphase[0]; //11 Falling clkQ
	// 	sndcpu_E = rE;
	// end

	//delay a one master clock period 6809 clock with respect to YM2203 clock
	always_ff @(posedge clk) begin
		clkEf_cen <= HCLKf_cen & ~ckphase[1] & ~ckphase[0]; //00 Falling clkE
		clkQf_cen <= HCLKf_cen &  ckphase[1] &  ckphase[0]; //11 Falling clkQ
		sndcpu_E <= rE;
	end
	//*** End of Generate clkQf, clkEf from HCLKf_cen

	mc6809is ic62(
		.CLK(clk),
		.fallE_en(clkEf_cen),
		.fallQ_en(clkQf_cen),
		.D(sndcpu_Din),
		.DOut(sndcpu_Dout),
		.ADDR(SAB),
		.RnW(sndcpu_RW),
		.BS(),
		.BA(),
		.nIRQ(ic27A_Qn),
		.nFIRQ(SIRQn),
		.nNMI(1'b1),
		.AVMA(),
		.BUSY(),
		.LIC(),
		.nHALT(~pause_rq),
		.nRESET(RSTn),
		.nDMABREQ(1'b1),
		.RegData()
	);

	logic [7:0] ic38_Y; //3-8 Decoder
	
	DFF_pseudoAsyncClrPre #(.W(1)) ic27a (
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic27A_Qn),
		.set(1'b0),    // active high
		.clr(~ic38_Y[2]),    // active high
		.cen(W3A08n) // signal whose edge will trigger the FF
	);

	logic [7:0] ic39_Q;
	ttl_74374_sync_noHiZout ic39(.clk(clk), .cen(W3A08n), .OCn(ic38_Y[2]), .D(DB_in), .Q(ic39_Q));

	logic ic37a; //NOT gate
	assign ic37a = ~sndcpu_RW;

	logic ic36a, ic36b; //NAND gate
	assign ic36a = ~(sndcpu_E & sndcpu_RW);
	assign SRDn = ic36a;
	assign ic36b = ~(sndcpu_E & ic37a);
	assign SWDn = ic36b;

	logic ic37c; //NOT gate
	assign ic37c = ~SAB[15];

	/* SOUND CPU MEMORY MAP */
	//A15 A14 A13 A12  A11 A10 A9 A8  A7 A6 A5 A4  A3 A2 A1 A0
	//  0   0   0   0    0   X  X  X   X  X  X  X   X  X  X  X    0x0-0x7ff    SRAM
	//  0   0   0   0    1   X  X  X   X  X  X  X   X  X  X  X  0x800-0xfff    NOT USED
	//  0   0   0   1    0   X  X  X   X  X  X  X   X  X  X  X  0x1000-0x17ff  SOUND LATCH, IRQn CLEAR
	//  0   0   0   1    1   X  X  X   X  X  X  X   X  X  X  X  0x1800-0x1fff  NOT USED
	//  0   0   1   0    0   X  X  X   X  X  X  X   X  X  X  X  0x2000-0x27ff  NOT USED
	//  0   0   1   0    1   X  X  X   X  X  X  X   X  X  X  X  0x2800-0x2fff  OPN I
	//  0   0   1   1    0   X  X  X   X  X  X  X   X  X  X  X  0x3000-0x37ff  OPN II
	//  0   0   1   1    1   X  X  X   X  X  X  X   X  X  X  X  0x3800-0x3fff  NOT USED
	//  0   1   X   X    X   X  X  X   X  X  X  X   X  X  X  X  0x4000-0x7fff  ROM (NOT USED)
	//  1   X   X   X    X   X  X  X   X  X  X  X   X  X  X  X  0x8000-0xffff  ROM
	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic38
	(
		.Enable1_bar(SAB[14]), //4 G2An
		.Enable2_bar(SAB[15]), //5 G2Bn
		.Enable3(1'b1), //6 G1
		.A(SAB[13:11]), //3,2,1 C,B,A
		.Y(ic38_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	assign OPN1n = ic38_Y[5];
	assign OPN2n = ic38_Y[6];

	//--- Intel P27256 32Kx8 CPUA ROMS 250ns ---
	logic [7:0] ic49_ROM_Dout;
	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("p2-0.ic49_vmem.txt")) ic49 (
	// 		.clk(clk),
	// 		.Cen(1'b1), //the CEn and OEn logic is applied in the CPU data bus multiplexer, active high
	// 		.ADDR(SAB[14:0]), 
	// 		.DATA(ic49_ROM_Dout)
	// 	);
	//PORT0: ROM load interface
	//PORT1: normal ROM access interface
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic49(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1(SAB[14:0]),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs),
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic49_ROM_Dout)
	);

	//--- OKI MSM2128-20RS 2Kx 8bits SRAM 200ns ---
	logic [7:0] ic48_RAM_Dout;
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(11), .DATA_HEX_FILE("rnd2K.bin_vmem.txt")) ic48(
		.clk(clk),
		.ADDR(SAB[10:0]),
		.DATA(sndcpu_Dout),
		.cen(~ic38_Y[0]), //active high,   ~ic38_Y[0]
		.we(~ic36b), //active high
		.Q(ic48_RAM_Dout)
	);


	//*** Start of Generate M1H_cen
	//Check rising edge of M1H
	logic last_M1H;
	logic M1H_cen;

	always @(posedge clk) begin
		last_M1H <= M1H;
	end

	always_comb begin
		M1H_cen = ~last_M1H & M1H;
	end
	//*** End of of Generate M1H_cen


	//*** DEBUG COMMANDS ***
//	always @(negedge rQ) begin
//		if(!ic38_Y[2]) begin
//			// $display($psprintf("[AUDIO_LATCH]   [R]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//			$display($psprintf("[AUDIO_LATCH]   [R]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//					{XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
//					XSleenaCore_tb.xlc.xs_clk.VPOS, 
//					XSleenaCore_tb.frm_cnt, SAB, sndcpu_Din));
//		end
//	end
//	always @(posedge M1H) begin
//		if (!SWDn && !OPN1n) begin
//			if (!SAB[0]) begin
//				$display($psprintf("[YM2203 I  REG ][W]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//				                   {XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
//				                   XSleenaCore_tb.xlc.xs_clk.VPOS, 
//                                   XSleenaCore_tb.frm_cnt, SAB, sndcpu_Dout));
//			end
//			else begin
//				$display($psprintf("[YM2203 I  DATA][W]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//					{XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
//					XSleenaCore_tb.xlc.xs_clk.VPOS, 
//					XSleenaCore_tb.frm_cnt, SAB, sndcpu_Dout));
//			end
//		end
//		if (!SWDn && !OPN2n) begin
//			if (!SAB[0]) begin
//				$display($psprintf("[YM2203 II REG ][W]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//				                   {XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
//				                   XSleenaCore_tb.xlc.xs_clk.VPOS, 
//                                   XSleenaCore_tb.frm_cnt, SAB, sndcpu_Dout));
//			end
//			else begin
//				$display($psprintf("[YM2203 II DATA][W]  [X:%03d] [Y:%03d] [F:%05d] @%04X = %02X\n",
//					{XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
//					XSleenaCore_tb.xlc.xs_clk.VPOS, 
//					XSleenaCore_tb.frm_cnt, SAB, sndcpu_Dout));
//			end
//		end
//	end
	//************************
	
	logic [7:0] ym2_Dout;
	jt03 ic84(
		.rst(~RSTn),      // rst active high, should be at least 6 clk&cen cycles long
		.clk(clk),        // CPU clock
		.cen(M1H_cen & ~pause_rq),       // optional clock enable, if not needed leave as 1'b1
		.din(sndcpu_Dout),
		.addr(SAB[0]),
		.cs_n(OPN2n),
		.wr_n(SWDn),
		.dout(ym2_Dout),
		.irq_n(), //NOT USED on ic84
		// I/O pins used by YM2203 embedded YM2149 chip
		.IOA_in(8'h0), //NOT USED
		.IOB_in(8'h0), //NOT USED
		// Separated output
		.psg_A(),
		.psg_B(),
		.psg_C(),
		//.fm_snd(fmsnd2),
		// combined output
		.psg_snd(),
		.snd(snd2),
		.snd_sample(sample2),
		// Debug
		.debug_view()
	);

	logic [7:0]  ym1_Dout;
	jt03 ic74(
		.rst(~RSTn),      // rst active high, should be at least 6 clk&cen cycles long
		.clk(clk),        // CPU clock
		.cen(M1H_cen & ~pause_rq),        // optional clock enable, if not needed leave as 1'b1
		.din(sndcpu_Dout),
		.addr(SAB[0]),
		.cs_n(OPN1n),
		.wr_n(SWDn),
		.dout(ym1_Dout),
		.irq_n(SIRQn),
		// I/O pins used by YM2203 embedded YM2149 chip
		.IOA_in(8'h00), //NOT USED
		.IOB_in(8'h00), //NOT USED
		// Separated output
		.psg_A(),
		.psg_B(),
		.psg_C(),
		//.fm_snd(fmsnd1),
		// combined output
		.psg_snd(),
		.snd(snd1),
		.snd_sample(sample1),
		// Debug
		.debug_view()
	);

//--- FPGA Synthesizable unidirectinal data bus MUX ---
	//main CPU data input
    always_ff @(posedge clk) begin
        if(!ic37c && !ic36a)              sndcpu_Din <= ic49_ROM_Dout;
        else if(!ic38_Y[0] && !ic36a)     sndcpu_Din <= ic48_RAM_Dout; 
		else if(!ic38_Y[2])               sndcpu_Din <= ic39_Q; //latch data from maincpu
		// else if(!SRDn && !OPN2n)          sndcpu_Din <= ym2_Dout; //YM2
		// else if(!SRDn && !OPN1n)          sndcpu_Din <= ym1_Dout; //YM1
		else                              sndcpu_Din <= 8'hFF;             
    end
//-------------------------------------------------------------------------------
endmodule
