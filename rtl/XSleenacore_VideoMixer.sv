//XSleenacore_VideoMixer.sv
//Author: @RndMnkIII
//Date: 11/10/2022
//Schematics: pages 5-6B
`default_nettype none
`timescale 1ns/100ps

module XSleenacore_VideoMixer (
  input wire clk,
	input wire RW,
	input wire [7:0] DB_in,
  output logic [7:0] DB_out,
	input wire PLSELn,
	input wire [9:0] AB, //1Kb
	input wire [6:0] MAPCOL,
	input wire [6:0] OBJCOL,
	input wire [6:0] BACK1COL,
	input wire [3:0] B2COL,
	input wire [2:0] B2PAL,
	input wire [2:0] PRI,
	input wire WDn,
	input wire BLKn,
	input wire HCLKn,
	//output color
	output logic [3:0] VIDEO_R,
	output logic [3:0] VIDEO_G,
	output logic [3:0] VIDEO_B,
	//ROM interface
  input bram_wr,
  input [7:0] bram_data,
  input [19:0] bram_addr,
  input bram_cs
);
  //Layer priority decode logic
  logic ic61a, ic61b, ic60a, ic60b; //4-input NOR gate 7425
  assign ic61a = ~(|MAPCOL[3:0]); //zero transparent color
	assign ic61b = ~(|OBJCOL[3:0]); //zero transparent color
  assign ic60a = ~(|BACK1COL[3:0]); //zero transparent color
	assign ic60b = ~(|B2COL[3:0]); //zero transparent color

  //MB7114 256BX4bits Priority PROM
  logic [3:0] ic59_D;
  // ROM_sync #(.DATA_WIDTH(4), .ADDR_WIDTH(8), .DATA_HEX_FILE("pt-0.ic59_vmem.txt")) ic59 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //active high
	// 	.ADDR({1'b0,PRI[2:0],ic60b,ic60a,ic61b,ic61a}), 
	// 	.DATA(ic59_D)
	// );
	//PORT0: ROM load interface
	//PORT1: normal ROM access interface
	SRAM_dual_sync #(.DATA_WIDTH(4), .ADDR_WIDTH(8)) ic59(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1({1'b0,PRI[2:0],ic60b,ic60a,ic61b,ic61a}),
		.DATA0(bram_data[3:0]),
		.DATA1(8'h00),
		.cen0(bram_cs),
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic59_D)
	);

  //This replaces TTL LS153 logic with ICs: ic73, ic72, ic71, ic70
  logic [6:0] out_color;
  always_comb begin
    case ({ic59_D[1:0]})
      2'b00: begin
        out_color = MAPCOL;
      end
      2'b01: begin
        out_color = OBJCOL;
      end
      2'b10: begin
        out_color = BACK1COL;
      end
      2'b11: begin
        out_color = {B2PAL,B2COL};
      end
    endcase
  end

  //This replaces TTL LS157 logic with ICs: ic83, ic82, ic81, ic80,
  //and LS04 ic69 (a,b) NOT gates
  logic [8:0] PLRAM_ADDR;
  logic ic95_CSn, ic94_CSn;
  logic ic95_WRn, ic94_WRn;
  logic PLRAM_LSB_ENn, PLRAM_MSB_ENn;

  always_ff @(posedge clk) begin
    if(!PLSELn) begin
      PLRAM_ADDR <= AB[8:0];
      ic95_CSn <=  AB[9];
      ic94_CSn <= ~AB[9];
      ic95_WRn <= WDn; 
      ic94_WRn <= WDn;
      PLRAM_LSB_ENn <=  AB[9];
      PLRAM_MSB_ENn <= ~AB[9];
    end
    else  begin
      PLRAM_ADDR <= {ic59_D[1:0], out_color};
      ic95_CSn <= 1'b0;
      ic94_CSn <= 1'b0;
      ic95_WRn <= 1'b1; 
      ic94_WRn <= 1'b1;
      PLRAM_LSB_ENn <= 1'b1;
      PLRAM_MSB_ENn <= 1'b1;
    end
  end

  //--- TMM2015BP-10 2Kx8bit 100ns SRAM ---
  //Pinout: 19 A10, 22 A9, 23 A8, 1 A7, 2 A6, 3 A5, 4 A4, 5 A3, 6 A2, 7 A1, 8 A0 
  //        17 D7, 16 D6, 15 D5, 14 D4, 13 D3, 11 D2, 10 D1, 9 D0
  //Only used 512 bytes
  logic [7:0] PLRAM_LSB_Din, PLRAM_LSB_Dout;
  // SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("xs_jungle_col1.bin_vmem.txt")) ic95(
  SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("xs_desert_col1.bin_vmem.txt")) ic95(
		.clk(clk),
		.ADDR(PLRAM_ADDR),
		.DATA(PLRAM_LSB_Din),
		.cen(~ic95_CSn), //active high
		.we(~ic95_WRn), //active high
		.Q(PLRAM_LSB_Dout)
  );

  //--- MBM2148L-55 1Kx4bit 55ns SRAM ---
  // Only used 512 bytes
  // Implemented as 9bit address x 8 bit data
  logic [7:0] PLRAM_MSB_Din, PLRAM_MSB_Dout;
  // SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("xs_jungle_col2.bin_vmem.txt")) ic94(
     SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(9), .DATA_HEX_FILE("xs_desert_col2.bin_vmem.txt")) ic94(
		.clk(clk),
		.ADDR(PLRAM_ADDR),
		.DATA(PLRAM_MSB_Din),
		.cen(~ic94_CSn), //active high
		.we(~ic94_WRn), //active high
		.Q(PLRAM_MSB_Dout)
  );

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces ic110,ic93 tri-state logic ---
// This replaces TTL logic LS245 ICs: ic110, ic93
	//PLRAM data output
	always_ff @(posedge clk) begin
		if      (RW && !PLRAM_LSB_ENn) DB_out <= PLRAM_LSB_Dout;
    else if (RW && !PLRAM_MSB_ENn) DB_out <= PLRAM_MSB_Dout;
		else                           DB_out <= 8'hFF; //replaces hi-Z bus state
	end

	//PLRAM data input
	always_ff @(posedge clk) begin
		if     (!RW && !PLRAM_LSB_ENn) PLRAM_LSB_Din <= DB_in;
    else if(!RW && !PLRAM_MSB_ENn) PLRAM_MSB_Din <= DB_in;
		else begin
      PLRAM_LSB_Din <= 8'hFF; //replaces hi-Z bus state
      PLRAM_MSB_Din <= 8'hFF; //replaces hi-Z bus state
    end
	end
//-------------------------------------------------------------------------------

  logic [7:0] ic109_Q;
  logic HCLKn_buf;
  assign HCLKn_buf = HCLKn;
  ttl_74273_sync ic109(.CLRn(BLKn), .Clk(clk), .Cen(HCLKn_buf), .D(PLRAM_LSB_Dout), .Q(ic109_Q));

  assign VIDEO_R = ic109_Q[3:0];
  assign VIDEO_G = ic109_Q[7:4];

	logic [3:0] ic108_Q;
  ttl_74174_sync #(.BLOCKS(4)) ic108
  (
    .Clk(clk),
    .Cen(HCLKn_buf),
    .Clr_n(BLKn),
    .D(PLRAM_MSB_Dout[3:0]),
    .Q(ic108_Q)
  );
  assign VIDEO_B = ic108_Q[3:0];
endmodule