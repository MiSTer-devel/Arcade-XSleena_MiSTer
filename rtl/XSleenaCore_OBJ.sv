//XSleenaCore_OBJ.sv
//Author: @RndMnkIII
//Date: 20/08/2022
//Schematics: pages 3-6A
`default_nettype none
`timescale 1ns/100ps

//Object (sprites) RAM tilemap address mapping: 0x3800-39FF
// -----------------------------------
//|       SPRITE DATA STRUCTURE       |
//|-----------------------------------|
//| BYTE 0 | BYTE 1 | BYTE 2 | BYTE 3 |  
//|76543210|76543210|76543210|76543210|
//|-----------------------------------|
//|        |     +++|--------|        | Tile #			{OBJNOHI,OBJNOLO}
//|        |  +++   |        |        | Palette bank	OBJPL
//|        | +      |        |        | Flip-X			OINV
//|        |        |        |++++++++| Position-X      LD0n
//|++++++++|        |        |        | Position-Y      LD1n
//|        |+       |        |        | Double height
// -----------------------------------
// CLR1n = (OBJCHG) ? 1'b1 : CLRn;
// LD1n  = (OBJCHG) ? M3n  : 1'b1;
// CLR0n = (OBJCHG) ? CLRn : 1'b1;
// LD0n  = (OBJCHG) ? 1'b1 :  M3n;
`define CPU_OVERCLOCK_HACK
import xain_pkg::*;

module XSleenaCore_OBJ (
	input wire clk,
	input wire clk_ram,
	//CPU Clocking
	input wire main_2xb,
	
	input wire M1Hn,
	input wire OBJSELn,
	input wire [8:0] AB, //only 512bytes accesible
	input wire [7:0] DB_in,
	output logic [7:0] DB_out,
	input wire [7:0] HN,
	input wire WDn,
	input wire VCUNT,
	input wire RW,
	input wire [5:0] DHPOS,
	input wire DVCUNT,
	input wire HCLKn, //HCLK0n
	input wire HCLK,
	input wire T1n,
	input wire T2n,
	input wire T3,
	input wire T3n,
	input wire VBLK,
	input wire VBLKn,
	input wire [7:0] VPOS,
	input wire OBJCLRn,
	input wire RAMCLRn,
	input wire OBJCHG,
	input wire OBJCHGn,
	input wire OBCH,
	input wire M0n,
	input wire M1n,	
	input wire M2n,
	input wire M3n,
	input wire EDIT,
	input wire EDITn,
	input wire CLRn,

	input wire P1_P2n,

	//output color and palette
	output logic [6:0] OBJ,

	//SDRAM ROM interface
	output logic [24:0] sdr_addr,
	output logic sdr_req,
	input wire sdr_rdy,
	input wire [15:0] sdr_data
);
	//internal routing signals
	logic OCHG, OCHGn;
	logic OBJWDn;
	logic [7:0] OBJDB0, OBJDB1;
	logic [6:0] OBJAD;
	logic SORWD0n, SORWD1n;
	logic [7:0] OBJNOLO;
	logic [7:0] OBJHP;
	logic [2:0] OBJNOHI;
	logic [3:0] OBJVLI;
	logic [2:0] OBJPL;
	logic OINV;
	logic [1:0] OBJLIN;
	logic [3:0] OBJCOL;
	logic LD0n, LD1n;
	logic CLR0n, CLR1n;
	logic OBJE0, OBJE1;

	//***************
	// *** PAGE 3 ***
	//***************
	//SRAM Section:
	wire [7:0] ic121_D; //shared bidirectional SRAM data bus

	//--- TMM2015BP-10 2Kx8 100ns SRAM ---

	//Only accessible 512bytes in the PCB
	//Following he TMM2018D datasheet, when WEn=0, the output is disabled (Hi-Z)
	//data input: CSn=0, WEn=1
	//data output: CSn=0,OEn=0,WEn=1
	//if CSn=1, row,column decoders are disabled, data input disabled, data output disable
	logic [7:0] SRAM_Din, SRAM_Dout, SRAM_Dout2;
//CPU OVERCLOCK HACK
// `ifdef CPU_OVERCLOCK_HACK
	SRAM_dual_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("rnd512B.bin_vmem.txt")) ic3(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(AB[8:0]),
		.ADDR1({VCUNT,HN[7:0]}),
		.DATA0(SRAM_Din),
		.DATA1(8'h00),
		.cen0(1'b1),
		.cen1(1'b1),
		.we0(OBJSELn ? 1'b0 : ~WDn),
		.we1(1'b0),
		.Q0(SRAM_Dout),
		.Q1(SRAM_Dout2)
	);
// `else
// 	//Address selector
// 	logic [3:0] ic2_Y;
// 	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic2
// 	(.Enable_bar(1'b0),.Select(OBJSELn),
// 	.A_2D({HN[3],AB[3],HN[2],AB[2],HN[1],AB[1],HN[0],AB[0]}),
// 	.Y(ic2_Y));
	
// 	logic [3:0] ic1_Y;
// 	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic1
// 	(.Enable_bar(1'b0),.Select(OBJSELn),
// 	.A_2D({HN[7],AB[7],HN[6],AB[6],HN[5],AB[5],HN[4],AB[4]}), //Check on PCB
// 	.Y(ic1_Y));

// 	logic [1:0] ic17bis_Y;
// 	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic17bis
// 	(.Enable_bar(1'b0),.Select(OBJSELn),
// 	.A_2D({1'b1,WDn,VCUNT,AB[8]}), //Check on PCB the IC#
// 	.Y(ic17bis_Y));

// 	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("rnd512B.bin_vmem.txt")) ic3(
// 		.clk(clk),
// 		.ADDR({ic17bis_Y[0],ic1_Y[3:0],ic2_Y[3:0]}),
// 		.DATA(SRAM_Din),
// 		.cen(1'b1), //active high
// 		.we(~ic17bis_Y[1]), //active high
// 		.Q(SRAM_Dout)
//     );
// 	assign SRAM_Dout2 = SRAM_Dout;
// `endif

	logic ic38a; //OR gate
//CPU OVERCLOCK HACK
// `ifdef CPU_OVERCLOCK_HACK
	assign ic38a = (main_2xb | OBJSELn); //this selector enables OBJ tilemap SRAM input/output external data bus
// `else
// 	assign ic38a = (M1Hn | OBJSELn); //this selector enables OBJ tilemap SRAM input/output external data bus
// `endif
	
//--- FPGA Synthesizable unidirectinal data bus MUX, replaces tri-state logic ---
// This replaces TTL logic LS245 ICs: ic5
// Adds one master clock period delay
	//OBJ Tilemap SRAM data output
	always_ff @(posedge clk) begin
		if (RW && !ic38a) DB_out <= SRAM_Dout;
		else              DB_out <= 8'hFF; //replaces hi-Z bus state
	end

	//OBJ  Tilemap SRAM data input
	always_ff @(posedge clk) begin
		if(!RW && !ic38a)      SRAM_Din <= DB_in;
		else                   SRAM_Din <= 8'hFF; //replaces hi-Z bus state
	end
//-------------------------------------------------------------------------------

	logic [7:0] ic4_Q;
	ttl_74273_sync ic4(.CLRn(1'b1), .Clk(clk), .Cen(HCLKn), .D(SRAM_Dout2), .Q(ic4_Q));

	logic [7:0] OBJ_Y_SUM;
	assign OBJ_Y_SUM = VPOS + ic4_Q;

	logic [3:0] ic36_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic36
	(.Enable_bar(1'b0),.Select(T1n),
	.A_2D({ic4_Q[3],OBJ_Y_SUM[3],ic4_Q[2],OBJ_Y_SUM[2],ic4_Q[1],OBJ_Y_SUM[1],ic4_Q[0],OBJ_Y_SUM[0]}),
	.Y(ic36_Y));

	logic [3:0] ic19_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic19
	(.Enable_bar(1'b0),.Select(T1n),
	.A_2D({ic4_Q[7],OBJ_Y_SUM[7],ic4_Q[6],OBJ_Y_SUM[6],ic4_Q[5],OBJ_Y_SUM[5],ic4_Q[4],OBJ_Y_SUM[4]}),
	.Y(ic19_Y));

	//Hack: add one master clock delay to catch correct value on T1n rising edge
	logic [3:0] ic36_Yr, ic19_Yr;
	always_ff @(posedge clk) begin
		ic36_Yr <= ic36_Y;
		ic19_Yr <= ic19_Y;
	end

	logic ic38d; //OR gate
	assign ic38d = (SRAM_Dout2[7] | OBJ_Y_SUM[4]);

	logic ic21b; //LS20 4-input NAND gate
	assign ic21b = ~(OBJ_Y_SUM[7] & OBJ_Y_SUM[6] & OBJ_Y_SUM[5] & ic38d);

	logic ic6B_Qn;
	DFF_pseudoAsyncClrPre #(.W(1)) ic6B(
		.clk(clk),
		.din(ic21b),
		.q(),
		.qn(ic6B_Qn),
		.set(~VBLKn),    // active high
		.clr(1'b0),    // active high
		.cen(T1n) // signal whose edge will trigger the FF
  	);

	logic ic15d; //NAND gate
	assign ic15d = ~(HCLK & ic6B_Qn);
	assign OBJWDn = ic15d;

	logic [3:0] ic51_Q;
	logic ic51_RCO;
	ttl_74161a_sync ic51
	(
	    .Clk(clk),
		.Cen(ic15d), //2
		.Clear_bar(OBJCLRn), //1
		.Load_bar(1'b1), //9
		.ENT(1'b1), //7
		.ENP(1'b1), //10
		.D({4'b1000}), //D 6, C 5, B 4, A 3 N/C
		.RCO(ic51_RCO), //15
		.Q(ic51_Q) //QD 11, QC 12, QB 13, QA 14
	);

	logic [3:0] ic52_Q;
	ttl_74161a_sync ic52
	(
		.Clk(clk),
		.Cen(ic15d), //2
		.Clear_bar(OBJCLRn), //1
		.Load_bar(1'b1), //9
		.ENT(ic51_RCO), //7
		.ENP(ic51_RCO), //10
		.D({4'b1000}), //D 6, C 5, B 4, A 3 N/C
		.RCO(), //15
		.Q(ic52_Q) //QD 11, QC 12, QB 13, QA 14
	);

	//Hack: add one master clock delay to catch correct value on T1n rising edge
	logic [7:0] ic35_Q;
	ttl_74273_sync ic35(.CLRn(OCHGn), .Clk(clk), .Cen(HCLKn), .D({ic19_Yr[3:0],ic36_Yr[3:0]}), .Q(ic35_Q)); //Hack: use ic19_Yr, ic36_Yr version

	logic [7:0] ic34_Q;
	ttl_74273_sync ic34(.CLRn(OCHG), .Clk(clk), .Cen(HCLKn), .D({ic19_Yr[3:0],ic36_Yr[3:0]}), .Q(ic34_Q)); //Hack: use ic19_Yr, ic36_Yr version

	logic [7:0] ic50_Q;
 	ttl_74374_sync_noHiZout ic50(.clk(clk), .cen(HCLK), .OCn(SORWD0n), .D(ic35_Q), .Q(ic50_Q));

	//Hack: add one master clock period delay
	// logic [7:0] ic50_Qr;
	// always_ff @(posedge clk) begin
	// 	ic50_Qr <= ic50_Q;
	// end
	assign OBJDB0 = ic50_Q; //ic50_Qr

	logic [7:0] ic49_Q;
 	ttl_74374_sync_noHiZout ic49(.clk(clk), .cen(HCLK), .OCn(SORWD1n), .D(ic34_Q), .Q(ic49_Q));
	
	//Hack: add one master clock period delay
	// logic [7:0] ic49_Qr;
	// always_ff @(posedge clk) begin
	// 	ic49_Qr <= ic49_Q;
	// end
	assign OBJDB1 = ic49_Q; //ic49_Qr;

	assign OBJAD = {ic52_Q[2:0],ic51_Q[3:0]};

	// //***************
	// // *** PAGE 4 ***
	// //***************
	logic [3:0] ic84_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic84
	(.Enable_bar(1'b0),.Select(OBJCHG),
	.A_2D({HN[5],OBJAD[3],HN[4],OBJAD[2],HN[3],OBJAD[1],HN[2],OBJAD[0]}),
	.Y(ic84_Y));

	logic [3:0] ic67_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic67
	(.Enable_bar(1'b0),.Select(OBJCHG),
	.A_2D({RAMCLRn,OBJWDn, VCUNT,OBJAD[6], HN[7],OBJAD[5], HN[6],OBJAD[4]}),
	.Y(ic67_Y));

	logic [3:0] ic83_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic83
	(.Enable_bar(1'b0),.Select(OBJCHG),
	.A_2D({OBJAD[3],HN[5],OBJAD[2],HN[4],OBJAD[1],HN[3],OBJAD[0],HN[2]}),
	.Y(ic83_Y));

	logic [3:0] ic66_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic66
	(.Enable_bar(1'b0),.Select(OBJCHG),
	.A_2D({OBJWDn,RAMCLRn, OBJAD[6],VCUNT, OBJAD[5],HN[7], OBJAD[4],HN[6]}),
	.Y(ic66_Y));

	// //TMM2018-55 2Kx8bit 55ns SRAM
	// //ONLY USED 127 bytes
	logic [7:0] SRAM_OBJ0_Dout;
		SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(7), .DATA_HEX_FILE("rnd128B_vmem.txt")) ic101(
		.clk(clk),
		.ADDR({ic67_Y[2:0],ic84_Y[3:0]}),
		.DATA(OBJDB0),
		.cen(1'b1), //active high
		.we(~ic67_Y[3]), //active high
		.Q(SRAM_OBJ0_Dout)
    );

	//SORWD0n = (OBJCHG) ? RAMCLRn : OBJWDn;
	assign SORWD0n = ic67_Y[3];

	// //TMM2018-55 2Kx8bit 55ns SRAM
	// //ONLY USED 127 bytes
	logic [7:0] SRAM_OBJ1_Dout;
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(7), .DATA_HEX_FILE("rnd128B_vmem.txt")) ic100(
		.clk(clk),
		.ADDR({ic66_Y[2:0],ic83_Y[3:0]}),
		.DATA(OBJDB1),
		.cen(1'b1), //active high
		.we(~ic66_Y[3]), //active high
		.Q(SRAM_OBJ1_Dout)
    );

	//SORWD1n = (OBJCHG) ? OBJWDn  : RAMCLRn;
	assign SORWD1n = ic66_Y[3];

	logic [7:0] OBJHP0, OBJHP1;
	ttl_74374_sync_noHiZout ic116(.clk(clk), .cen(T2n), .OCn(OBJCHGn), .D(SRAM_OBJ0_Dout), .Q(OBJHP0));
	ttl_74374_sync_noHiZout ic115(.clk(clk), .cen(T2n), .OCn(OBJCHG), .D(SRAM_OBJ1_Dout), .Q(OBJHP1));
	assign OBJHP = (!OBJCHGn) ? OBJHP0 :  OBJHP1;

	logic ic17_Y;
	logic [7:0] ic123_Q;
	ttl_74273_sync ic123(.CLRn(1'b1), .Clk(clk), .Cen(M2n), .D({OBJHP[7:1],ic17_Y}), .Q(ic123_Q));
	assign OBJNOLO = ic123_Q;

	logic [7:0] ic122_Q;
	ttl_74273_sync ic122(.CLRn(1'b1), .Clk(clk), .Cen(M1n), .D(OBJHP), .Q(ic122_Q));

	logic [4:0] ic137_Q;
	ttl_74174_sync #(.BLOCKS(5)) ic137
    (
        .Clk(clk),
        .Cen(M0n),
        .Clr_n(1'b1),
        .D(OBJHP[4:0]),
        .Q(ic137_Q)
    );

	ttl_74157 #(.BLOCKS(1), .DELAY_RISE(0), .DELAY_FALL(0)) ic17
	(.Enable_bar(1'b0),.Select(ic122_Q[7]),
	.A_2D({ic137_Q[4],OBJHP[0]}),
	.Y(ic17_Y));

	logic [7:0] ic138_Q;
	ttl_74273_sync ic138(.CLRn(1'b1), .Clk(clk), .Cen(M2n), .D({ic122_Q[6],ic137_Q[3:0],ic122_Q[2:0]}), .Q(ic138_Q));

	assign OBJNOHI = ic138_Q[2:0];
	assign OBJVLI = ic138_Q[6:3];

	logic ic69d; //XOR gate
	assign ic69d = (HN[2] ^ HN[3]);

	logic ic75c, ic75b; //NOT gate
	assign ic75c = ~HN[2];
	assign ic75b = ~ic138_Q[7];


	logic [3:0] ic68_Q;
	ttl_74174_sync #(.BLOCKS(4)) ic68
    (
        .Clk(clk),
        .Cen(M3n),
        .Clr_n(1'b1),
        .D({ic75b,ic122_Q[5:3]}),
        .Q(ic68_Q)
    );

	assign OBJPL = ic68_Q[2:0];
	assign OINV = ic68_Q[3];

	logic ic69b, ic69c; //XOR gate
	assign ic69b = (ic69d ^ ic75b);
	assign ic69c = (ic75c ^ ic75b);

	assign OBJLIN  = {ic69b,ic69c};

	// //***************
	// // *** PAGE 5 ***
	// //***************

	//---------- ROM SECTION ------------
	//--- Intel P27256 32Kx8 MAP ROM 250ns ---
	//*** START OF OBJ ROM address request generator ***
	// logic [24:0] req_ROM_addr;
	// logic ROM_req;
	// logic ROM_data_rdy;
	// logic [15:0] ROM_data;
	logic [7:0] ROMH, ROML;

	logic last_HCLKn;
	logic [16:0] curr_ROM_addr;
	logic [16:0] last_ROM_addr = 17'h0;

	assign curr_ROM_addr = {OBJNOHI[2:0],OBJNOLO[7:0],OBJLIN[1:0],OBJVLI[3:0]};

	always_ff @(posedge clk_ram) begin
		last_HCLKn <= HCLKn;
		sdr_req <= 1'b0;
		if(last_HCLKn && !HCLKn) begin//detect falling edge
			last_ROM_addr <= curr_ROM_addr;
			if (last_ROM_addr != curr_ROM_addr) begin
				sdr_addr <=  REGION_ROM_OBJ.base_addr[24:0] | {curr_ROM_addr,1'b0};
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

	// sdr_req_manager_single obj_sdr_req_man(
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
	//*** END OF OBJ ROM address request generator ***

	logic [1:0] ic148_Y;
	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic148
	(.Enable_bar(1'b0),.Select(OINV),
	.A_2D({T3,1'b1,1'b1,T3}),
	.Y(ic148_Y));

	//fix ic148_Y delay
	logic [1:0] ic148_Yfix;
	always_ff @(posedge clk) begin
		ic148_Yfix <= ic148_Y;
	end

	// //2 DSR, 7 DSL, 9 S0, 10 S1, 6-3 P3-0, 12-15 Q3-0 
	// // S1 S0 Dsr
	// //  0  1   1  Shift Righ    {Dsr,q0, q1, q2} -> {Q3,Q2,Q1,Q0}
	// //  1  1   1  Parallel Load {D3,D2,D1,D0} -> {Q3,Q2,Q1,Q0}
	logic [3:0] ic147_Q;
	ttl_74194_sync ic147
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic148_Yfix[0]), .S1(ic148_Yfix[1]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[0]), .D1(ROMH[1]), .D2(ROMH[2]), .D3(ROMH[3]),
		.Q0(ic147_Q[0]), .Q1(ic147_Q[1]), .Q2(ic147_Q[2]), .Q3(ic147_Q[3]));

	logic [3:0] ic146_Q;
	ttl_74194_sync ic146
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic148_Yfix[0]), .S1(ic148_Yfix[1]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROMH[4]), .D1(ROMH[5]), .D2(ROMH[6]), .D3(ROMH[7]),
		.Q0(ic146_Q[0]), .Q1(ic146_Q[1]), .Q2(ic146_Q[2]), .Q3(ic146_Q[3]));

	logic [3:0] ic145_Q;
	ttl_74194_sync ic145
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic148_Yfix[0]), .S1(ic148_Yfix[1]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[0]), .D1(ROML[1]), .D2(ROML[2]), .D3(ROML[3]),
		.Q0(ic145_Q[0]), .Q1(ic145_Q[1]), .Q2(ic145_Q[2]), .Q3(ic145_Q[3]));

	logic [3:0] ic144_Q;
	ttl_74194_sync ic144
		(.clk(clk), .cen(HCLKn), .CR_n(1'b1), .S0(ic148_Yfix[0]), .S1(ic148_Yfix[1]),
		.Dsl(1'b0), .Dsr(1'b0), //  
		.D0(ROML[4]), .D1(ROML[5]), .D2(ROML[6]), .D3(ROML[7]),
		.Q0(ic144_Q[0]), .Q1(ic144_Q[1]), .Q2(ic144_Q[2]), .Q3(ic144_Q[3]));

	logic [3:0] ic90_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic90
	(.Enable_bar(1'b0),.Select(OINV),
	.A_2D({ic144_Q[3],ic144_Q[0],ic145_Q[3],ic145_Q[0],ic146_Q[3],ic146_Q[0],ic147_Q[3],ic147_Q[0]}),
	.Y(ic90_Y));

	assign OBJCOL[3:0] = ic90_Y[3:0];

	logic ic89b; //LS7425
	assign ic89b = ~(|ic90_Y);

	logic ic89a; //LS7425
	assign ic89a = ~(|ic90_Y);

	logic ic26c; //AND gate
	assign ic26c = (ic89b & EDITn);

	//FIX delay:
	always_ff @(posedge clk) begin
		OBJE0 <= ic26c;
	end
	//assign OBJE0 = ic26c;

	logic ic26a; //AND gate
	assign ic26a = (ic89a & EDIT);

	//FIX delay:
	always_ff @(posedge clk) begin
		OBJE1 <= ic26a;
	end
	//assign OBJE1 = ic26a;

	logic [3:0] ic143_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic143
	(.Enable_bar(1'b0),.Select(OBJCHG),
	.A_2D({1'b1,CLRn,M3n,1'b1,CLRn,1'b1,1'b1,M3n}),
	.Y(ic143_Y));

	//Hack: add one master clock period delay:
	always_ff @(posedge clk) begin
    	LD0n <= ic143_Y[0];
		CLR0n <= ic143_Y[1];
		LD1n <= ic143_Y[2];
		CLR1n <= ic143_Y[3];
	end


	// //***************
	// // *** PAGE 6 ***
	// //***************
	logic [3:0] ic86_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic86
	(.Enable_bar(1'b0),.Select(EDIT),
	.A_2D({1'b0,OBJCOL[3],1'b0,OBJCOL[2],1'b0,OBJCOL[1],1'b0,OBJCOL[0]}),
	.Y(ic86_Y));

	logic [3:0] ic87_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic87
	(.Enable_bar(1'b0),.Select(EDIT),
	.A_2D({OBJCOL[3],1'b0,OBJCOL[2],1'b0,OBJCOL[1],1'b0,OBJCOL[0],1'b0}),
	.Y(ic87_Y));


	logic [7:0] LD0_D,LD0_Dp1;
	logic [7:0] LD1_D,LD1_Dp1;

	logic [3:0] ic125_Q;
  	logic ic125_RCO;
  	ttl_74163a_sync ic125
	(
		.Clk(clk),
		.Clear_bar(CLR0n), //1
		.Load_bar(LD0n), //9
		.ENT(1'b1), //7
		.ENP(1'b1), //10
		.D(OBJHP[3:0]), //D 6, C 5, B 4, A 3 N/C
		.Cen(HCLKn), //2
		.RCO(ic125_RCO), //15
		.Q(ic125_Q) //QD 11, QC 12, QB 13, QA 14
	);

	logic [3:0] ic140_Q;
  	ttl_74163a_sync ic140
	(
		.Clk(clk),
		.Clear_bar(CLR0n), //1
		.Load_bar(LD0n), //9
		.ENT(ic125_RCO), //7
		.ENP(ic125_RCO), //10
		.D(OBJHP[7:4]), //D 6, C 5, B 4, A 3 N/C
		.Cen(HCLKn), //2
		.RCO(), //15
		.Q(ic140_Q) //QD 11, QC 12, QB 13, QA 14
	);

	//assign LD0_D = (EDIT) ? ( !P1_P2n ? {ic140_Q,ic125_Q} + 8'd1 : {ic140_Q,ic125_Q} - 8'd1) : {ic140_Q,ic125_Q};	
	assign LD0_D = {ic140_Q,ic125_Q};	


    // n8bit_counter cnt0
    // (
    //     .Reset_n(CLR0n),
    //     .clk(clk), 
    //     .cen(HCLKn),
    //     .direction(1'b1), // 1 = Up, 0 = Down
    //     .load_n(LD0n), //Use delayed signal for trigger with rising edge of CK1
    //     .ent_n(1'b0), //active low
    //     .enp_n(1'b0), //active low
    //     .P(OBJHP[7:0]),
    //     .Q(LD0_Dp1)   // 4-bit output
    // );
	// assign LD0_D = LD0_Dp1;

	logic [3:0] ic126_Q;
  	logic ic126_RCO;
  	ttl_74163a_sync ic126
	(
		.Clk(clk),
		.Clear_bar(CLR1n), //1
		.Load_bar(LD1n), //9
		.ENT(1'b1), //7
		.ENP(1'b1), //10
		.D(OBJHP[3:0]), //D 6, C 5, B 4, A 3 N/C
		.Cen(HCLKn), //2
		.RCO(ic126_RCO), //15
		.Q(ic126_Q) //QD 11, QC 12, QB 13, QA 14
	);

	logic [3:0] ic141_Q;
  	ttl_74163a_sync ic141
	(
		.Clk(clk),
		.Clear_bar(CLR1n), //1
		.Load_bar(LD1n), //9
		.ENT(ic126_RCO), //7
		.ENP(ic126_RCO), //10
		.D(OBJHP[7:4]), //D 6, C 5, B 4, A 3 N/C
		.Cen(HCLKn), //2
		.RCO(), //15
		.Q(ic141_Q) //QD 11, QC 12, QB 13, QA 14
	);
	//assign LD1_D = (EDIT) ? (!P1_P2n ? {ic141_Q,ic126_Q} + 8'd1 : {ic141_Q,ic126_Q} - 8'd1) : {ic141_Q,ic126_Q};
	assign LD1_D = {ic141_Q,ic126_Q};

	
    // n8bit_counter cnt1
    // (
    //     .Reset_n(CLR1n),
    //     .clk(clk), 
    //     .cen(HCLKn),
    //     .direction(1'b1), // 1 = Up, 0 = Down
    //     .load_n(LD1n), //Use delayed signal for trigger with rising edge of CK1
    //     .ent_n(1'b0), //active low
    //     .enp_n(1'b0), //active low
    //     .P(OBJHP[7:0]),
    //     .Q(LD1_Dp1)   // 4-bit output
    // );
	// assign LD1_D = LD1_Dp1;

	logic ic71a, ic71d; //NOR gate
	assign ic71a = ~(P1_P2n | EDIT);
	assign ic71d = ~(P1_P2n | EDITn);

	// //inverter stage if condition is meet
	logic ic124a, ic124d, ic124b, ic124c; //XOR gate
	logic ic139a, ic139d, ic139b, ic139c; //XOR gate

	logic ic127a, ic127d, ic127b, ic127c; //XOR gate
	logic ic142a, ic142d, ic142b, ic142c; //XOR gate

	assign ic124a = (ic71d ^ LD0_D[0]);
	assign ic124d = (ic71d ^ LD0_D[1]);
	assign ic124b = (ic71d ^ LD0_D[2]);
	assign ic124c = (ic71d ^ LD0_D[3]);

	assign ic139a = (ic71d ^ LD0_D[4]);
	assign ic139d = (ic71d ^ LD0_D[5]);
	assign ic139b = (ic71d ^ LD0_D[6]);
	assign ic139c = (ic71d ^ LD0_D[7]);

	assign ic127a = (ic71a ^ LD1_D[0]);
	assign ic127d = (ic71a ^ LD1_D[1]);
	assign ic127b = (ic71a ^ LD1_D[2]);
	assign ic127c = (ic71a ^ LD1_D[3]);

	assign ic142a = (ic71a ^ LD1_D[4]);
	assign ic142d = (ic71a ^ LD1_D[5]);
	assign ic142b = (ic71a ^ LD1_D[6]);
	assign ic142c = (ic71a ^ LD1_D[7]);

	// //TMM2018-55 2Kx8bit 55ns SRAM
	// //ONLY USED 256 bytes
	logic [7:0] SRAM_DBUS0_Out, SRAM_DBUS0_In; 
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(8), .DATA_HEX_FILE("rnd256B_vmem.txt")) ic117(
		.clk(clk),
		.ADDR({ic139c,ic139b,ic139d,ic139a,ic124c,ic124b,ic124d,ic124a}),
		.DATA(SRAM_DBUS0_In),
		.cen(1'b1), //active high
		.we(~HCLKn), //active high
		.Q(SRAM_DBUS0_Out)
    );

	logic [7:0] ic102_Q;
	ttl_74273_sync ic102(.CLRn(1'b1), .Clk(clk), .Cen(HCLK), .D(SRAM_DBUS0_Out), .Q(ic102_Q));

	// //TMM2018-55 2Kx8bit 55ns SRAM
	// //ONLY USED 256 bytes
	logic [7:0] SRAM_DBUS1_Out, SRAM_DBUS1_In; 
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(8), .DATA_HEX_FILE("rnd256B_vmem.txt")) ic120(
		.clk(clk),
		.ADDR({ic142c,ic142b,ic142d,ic142a,ic127c,ic127b,ic127d,ic127a}),
		.DATA(SRAM_DBUS1_In),
		.cen(1'b1), //active high
		.we(~HCLKn), //active high
		.Q(SRAM_DBUS1_Out)
    );

	logic [7:0] ic105_Q; //Uses all bits
	ttl_74273_sync ic105(.CLRn(1'b1), .Clk(clk), .Cen(HCLK), .D({OBCH,SRAM_DBUS1_Out[6:0]}), .Q(ic105_Q));

	logic ic75f; //NOT gate
	assign ic75f = ~ic105_Q[7];
	assign OCHG = ic105_Q[7];
	assign OCHGn = ic75f;

	logic [6:0] DB0_257, DB1_257;
	logic [6:0] DB0_257r, DB1_257r;
	logic [6:0] DB0_257r2, DB1_257r2;
	logic [6:0] DB0_257r3, DB1_257r3;
	ttl_74257_noHiZout ic103
	(.Enable_bar(HCLKn),.Select(OBJE0), //HCLK1n
	.A_2D({ic102_Q[3],ic86_Y[3],ic102_Q[2],ic86_Y[2],ic102_Q[1],ic86_Y[1],ic102_Q[0],ic86_Y[0]}),
	.Y(DB0_257[3:0]));

	ttl_74257_noHiZout #(.BLOCKS(3)) ic85
	(.Enable_bar(HCLKn),.Select(OBJE0), //HCLK1n
	.A_2D({ic102_Q[6],OBJPL[2],ic102_Q[5],OBJPL[1],ic102_Q[4],OBJPL[0]}),
	.Y(DB0_257[6:4]));

	ttl_74257_noHiZout ic104
	(.Enable_bar(HCLKn),.Select(OBJE1), //HCLK1n
	.A_2D({ic105_Q[3],ic87_Y[3],ic105_Q[2],ic87_Y[2],ic105_Q[1],ic87_Y[1],ic105_Q[0],ic87_Y[0]}),
	.Y(DB1_257[3:0]));

	ttl_74257_noHiZout  #(.BLOCKS(3)) ic88
	(.Enable_bar(HCLKn),.Select(OBJE1), //HCLK1n
	.A_2D({ic105_Q[6],OBJPL[2],ic105_Q[5],OBJPL[1],ic105_Q[4],OBJPL[0]}),
	.Y(DB1_257[6:4]));

	//Fix delay LS257
	always_ff @(posedge clk) begin
		SRAM_DBUS0_In[6:0] <= DB0_257;
		SRAM_DBUS1_In[6:0] <= DB1_257;
	end

	assign SRAM_DBUS0_In[7] = 1'b0;
	assign SRAM_DBUS1_In[7] = 1'b0;

	// //Selects sprite line buffer to display
	logic [3:0] ic119_Y;
	ttl_74157 #(.BLOCKS(4), .DELAY_RISE(0), .DELAY_FALL(0)) ic119
	(.Enable_bar(1'b0),.Select(EDIT), 
	.A_2D({ic102_Q[3],ic105_Q[3],ic102_Q[2],ic105_Q[2],ic102_Q[1],ic105_Q[1],ic102_Q[0],ic105_Q[0]}),
	.Y(ic119_Y));

	logic [2:0] ic118_Y;
	ttl_74157 #(.BLOCKS(3), .DELAY_RISE(0), .DELAY_FALL(0)) ic118
	(.Enable_bar(1'b0),.Select(EDIT), 
	.A_2D({ic102_Q[6],ic105_Q[6],ic102_Q[5],ic105_Q[5],ic102_Q[4],ic105_Q[4]}),
	.Y(ic118_Y));

	//-----------------------------------------------------
	assign OBJ = {ic118_Y[2:0],ic119_Y[3:0]}; //color palette bank and index value
	//assign OBJ = 7'h0; //DUMP VALUE
endmodule