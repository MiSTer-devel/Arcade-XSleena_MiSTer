//============================================================================
//============================================================================
//  Xain'd Sleena (Bootleg) for MiSTer FPGA
//
//  Copyright (C) 2022 Francisco Javier Fuentes Moreno @RndMnkIII
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`default_nettype none
`define CPU_OVERCLOCK_HACK

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
//assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign FB_FORCE_BLANK = 0;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[2:1];
wire [2:0] scandoubler_fx = status[5:3];
wire orientation = ~status[10];
wire pause_in_osd = status[8];
wire system_pause;
wire [1:0] turbo_mode; //{turbo_m,turbo_s}

assign HDMI_FREEZE = 0; //system_pause;
wire NATIVE_VFREQ = status[9] == 1'd0;

video_timing_t video_timing;
assign video_timing = video_timing_t'({1'b0,status[9]});

// If video timing changes, force mode update
reg  video_status;
reg new_vmode = 0;
always @(posedge MS_CLK) begin
    if (video_status != status[9]) begin
        video_status <= status[9];
        new_vmode <= ~new_vmode;
    end
end

`include "build_id.v" 
localparam CONF_STR ={
	"XSleena;;",
	"-;",
    "P1,Video Settings;",
    "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[6],Flip,Off,On;",
	"P1O[7],Rotate CCW,Off,On;",
    "P1-;",
    "P1O[9],Video Timing,57.44Hz(Native),60Hz(Standard);",
    "P1O[10],Orientation,Horz,Vert;",
	"P1O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
    "O[8],OSD Pause,Off,On;",
    "-;",
	"P2,SNAC;",
	"P2O[23:22],DB15 Devices,Off,OnlyP1,OnlyP2,P1&P2;",
	"-;",
    "P3,SDRAM Debug;",
    "P3O[19],Request BACK1,On,Off;",
	"P3O[20],Request BACK2,On,Off;",
	"P3O[21],Request OBJ,On,Off;",
    "-;",
	"P4,Hacks;",
	"P4O[29],CPU Turbo,1.0x,2.0x;",
    "-;",
	"DIP;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Shot,Jump,Start P1,Coin,Start P2,Pause;",
	"jn,A,B,Start,R,Select,L;",
	"DEFMRA,/_Arcade/XSleenaBA.mra;",
	"V,v",`BUILD_DATE 
};

	// "P4O[30],Enable Hiscores,Off,On;",
	// "P4O[31],Autosave Hiscores,Off,On;",

//debug SDRAM interface
wire [2:0] DBG_SDR_REQ = status[21:19];

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;
wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req = 0;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din = 0;
wire        ioctl_wait;

wire [15:0] joystick_0, joystick_1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(MS_CLK),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),

    .forced_scandoubler(forced_scandoubler),
    .new_vmode(new_vmode),
    .video_rotated(video_rotated),

    .buttons(buttons),
    .status(status),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_req(ioctl_upload_req),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////
//wire clk_56p45M;
//wire clk_112p90M;
//wire clk_112p90M_PS;
wire pll_locked;
logic pll_init_locked = 0;
wire clk_60M;
wire clk_120M;


//10x pixel clock
//n=1, m=5, freq=12.54504 for 62.7252 master clock, 125.4504 SDRAM clock
//n=524, m=2739 w=12, for 60.0 master clock 120MHz SDRAM clock

//9x pixel clock
//56.45268, 112.90536


//native   57.4Hz using 60MHz master clock for 12MHz
//standard 60.0Hz using fractional clock enables for 12.545040MHz
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(MS_CLK),
	.outclk_1(SDR_CLK),
	.locked(pll_locked),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

wire reset = RESET | status[0] | buttons[1] | ~pll_init_locked;

wire MS_CLK, SDR_CLK, SDR_PS_CLK;
//PLL Reconfig

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);
localparam PLL_PARAM_COUNT = 9;

//50.13504
//100.27008
wire [31:0] PLL_60HZ[PLL_PARAM_COUNT * 2] = '{
    'h0, 'h0, // set waitrequest mode
    'h4, 'hA0A, // M COUNTER
    'h3, 'h10000, // N COUNTER
    'h5, 'hA0A, // C0 COUNTER
    'h5, 'h40505, // C1 COUNTER
	'h9, 'h2, //CHARGE PUMP
    'h8, 'h7, // BANDWIDTH SETTING
    'h7, 'h0DD3FDC4, //M COUNTER FRACTION
    'h2, 'h1 // start fractional PLL reconfigure
};

//48.0
//96.0
wire [31:0] PLL_57HZ[PLL_PARAM_COUNT * 2] = '{
    'h0, 'h0, // set waitrequest mode
    'h4, 'h20504, // M COUNTER
    'h3, 'h10000, // N COUNTER
    'h5, 'h505, // C0 COUNTER
    'h5, 'h60302, // C1 COUNTER
	'h9, 'h2, //CHARGE PUMP
    'h8, 'h7, // BANDWIDTH SETTING
    'h7, 'h9999999A, //M COUNTER FRACTION
    'h2, 'h1 // start fractional PLL reconfigure 
};


video_timing_t video_timing_lat = VIDEO_57HZ;
reg reconfig_pause = 0;

always @(posedge CLK_50M) begin
	reg [3:0] param_idx = 0;
    reg [7:0] reconfig = 0;

	cfg_write <= 0;

	if (pll_locked & ~cfg_waitrequest) begin
        pll_init_locked <= 1;
		if (&reconfig) begin // do reconfig
            case(video_timing_lat)
            VIDEO_57HZ: begin
                cfg_address <= PLL_57HZ[param_idx * 2 + 0][5:0];
                cfg_data    <= PLL_57HZ[param_idx * 2 + 1];
            end
            VIDEO_60HZ: begin
                cfg_address <= PLL_60HZ[param_idx * 2 + 0][5:0];
                cfg_data    <= PLL_60HZ[param_idx * 2 + 1];
            end
            endcase

            cfg_write <= 1;
            param_idx <= param_idx + 4'd1;
            if (param_idx == PLL_PARAM_COUNT - 1) reconfig <= 8'd0;

        end else if (video_timing != video_timing_lat) begin // new timing requested
            video_timing_lat <= video_timing;
            reconfig <= 8'd1;
            reconfig_pause <= 1;
            param_idx <= 0;
        end else if (|reconfig) begin // pausing before reconfigure
            reconfig <= reconfig + 8'd1;
        end else begin
            reconfig_pause <= 0; // unpause once pll is locked again
        end
    end
end
///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
// SDRAM
///////////////////////////////////////////////////////////////////////
//CH0 -> MAINCPU
//CH1 -> SPRITES
//CH2 -> BG1
//CH3 -> BG2/ROM LOADING INTERFACE
wire [15:0] sdr_mcpu_dout;
wire [24:0] sdr_mcpu_addr;
wire sdr_mcpu_req, sdr_mcpu_rdy;

wire [15:0] sdr_scpu_dout;
wire [24:0] sdr_scpu_addr;
wire sdr_scpu_req, sdr_scpu_rdy;

wire [15:0] sdr_obj_dout;
wire [24:0] sdr_obj_addr;
wire sdr_obj_req, sdr_obj_rdy;

wire [15:0] sdr_bg1_dout;
wire [24:0] sdr_bg1_addr;
wire sdr_bg1_req, sdr_bg1_rdy;

wire [15:0] sdr_bg2_dout;
wire [24:0] sdr_bg2_addr;
wire sdr_bg2_req;

// wire [15:0] sdr_map_dout;
// wire [24:0] sdr_map_addr;
// wire sdr_map_req,  sdr_map_rdy;

reg [24:0] sdr_rom_addr;
reg [15:0] sdr_rom_data;
reg [1:0] sdr_rom_be;
reg sdr_rom_req;

wire sdr_rom_write = ioctl_download && (ioctl_index == 0);
// wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
// wire [15:0] sdr_ch3_din = sdr_rom_write ? sdr_rom_data : sdr_cpu_din;
wire [15:0] sdr_ch3_din = sdr_rom_data;
// wire [1:0] sdr_ch3_be = sdr_rom_write ? sdr_rom_be : sdr_cpu_wr_sel;
wire [1:0] sdr_ch3_be = sdr_rom_be;
// wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : ~{|sdr_cpu_wr_sel};
wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : 1'b1; //or ROM downloading or SDRAM ROM read
wire sdr_ch3_req = sdr_rom_write ? sdr_rom_req : sdr_bg2_req & ~DBG_SDR_REQ[1];
wire sdr_ch3_rdy;
wire sdr_bg2_rdy = sdr_ch3_rdy;
wire sdr_rom_rdy = sdr_ch3_rdy;

wire [19:0] bram_addr;
wire [7:0] bram_data;
wire [5:0] bram_cs;
wire bram_wr;

//board_cfg_t board_cfg;

sdram sdram
(
    .*,
    .doRefresh(1),
    .init(~pll_init_locked),
    .clk(SDR_CLK),
`ifdef CPU_OVERCLOCK_HACK
    .ch0a_addr(24'h0),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
    .ch0a_dout(),
    .ch0a_req(1'b0),
    .ch0a_ready(),

    .ch0b_addr(24'h0),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
    .ch0b_dout(),
    .ch0b_req(1'b0),
    .ch0b_ready(),
`else    
    .ch0a_addr(sdr_mcpu_addr[24:1]),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
    .ch0a_dout(sdr_mcpu_dout),
    .ch0a_req(sdr_mcpu_req),
    .ch0a_ready(sdr_mcpu_rdy),

    .ch0b_addr(sdr_scpu_addr[24:1]),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
    .ch0b_dout(sdr_scpu_dout),
    .ch0b_req(sdr_scpu_req),
    .ch0b_ready(sdr_scpu_rdy),
`endif
    .ch1_addr(sdr_obj_addr[24:1]), //16bit address
    .ch1_dout(sdr_obj_dout),
    .ch1_req(sdr_obj_req & ~DBG_SDR_REQ[2]),
    .ch1_ready(sdr_obj_rdy),

    .ch2_addr(sdr_bg1_addr[24:1]), //16bit address
    .ch2_dout(sdr_bg1_dout),
    .ch2_req(sdr_bg1_req & ~DBG_SDR_REQ[0]),
    .ch2_ready(sdr_bg1_rdy),

    .ch3_addr(sdr_ch3_addr[24:1]), //16bit address
    .ch3_din(sdr_ch3_din),
    .ch3_dout(sdr_bg2_dout),
    .ch3_be(sdr_ch3_be),
    .ch3_rnw(sdr_ch3_rnw),
    .ch3_req(sdr_ch3_req),
    .ch3_ready(sdr_ch3_rdy)
);

rom_loader rom_loader(
    .sys_clk(MS_CLK),
    .ram_clk(SDR_CLK),

    .ioctl_wr(ioctl_wr && !ioctl_index),
    .ioctl_data(ioctl_dout[7:0]),

    .ioctl_wait(ioctl_wait),

    .sdr_addr(sdr_rom_addr),
    .sdr_data(sdr_rom_data),
    .sdr_be(sdr_rom_be),
    .sdr_req(sdr_rom_req),
    .sdr_rdy(sdr_rom_rdy),

    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

    .board_cfg()
);

//////////////////////////     CORE     //////////////////////////
logic [3:0] VIDEO_4R;
logic [3:0] VIDEO_4G;
logic [3:0] VIDEO_4B;
logic HBLANK_CORE, VBLANK_CORE;
logic HSYNC_CORE, VSYNC_CORE;
logic  HBlank, VBlank, HSync, VSync;
logic  HSync2, VSync2;
logic HSYNC, VSYNC;
logic CSYNC;
logic ce_pix;

XSleenaCore xlc (
	.CLK(MS_CLK),
	.SDR_CLK(SDR_CLK),
	.RSTn(~reset),
	.NATIVE_VFREQ(NATIVE_VFREQ),

	//Inputs
	.DSW1(DSW1), // 80 Flip Screen On, 40 Cabinet Cocktail, 20 Allow continue Yes, 10 Demo Sounds On, 0C CoinB 1C/1C, 03 CoinA 1C/1C
	.DSW2(DSW2), //
	.PLAYER1(PLAYER1),
	.PLAYER2(PLAYER2),
	.SERVICE(SERVICE),
	.JAMMA_24(1'b1),
	.JAMMA_b(1'b1),
	//Video output
	.VIDEO_R(VIDEO_4R),
	.VIDEO_G(VIDEO_4G),
	.VIDEO_B(VIDEO_4B),
	.CE_PIXEL(ce_pix),
	.HBLANK(HBLANK_CORE), //NEGATIVE HBLANK
	.VBLANK(VBLANK_CORE), //NEGATIVE VBLANK
	.VSYNC(VSYNC_CORE), //NEGATIVE VSYNC
	.HSYNC(HSYNC_CORE), //NEGATIVE HSYNC
	.CSYNC(CSYNC),
	
	//Memory interface
	//SDRAM
    .sdr_mcpu_addr(sdr_mcpu_addr),
    .sdr_mcpu_dout(sdr_mcpu_dout),
    .sdr_mcpu_req(sdr_mcpu_req),
    .sdr_mcpu_rdy(sdr_mcpu_rdy),

    .sdr_scpu_addr(sdr_scpu_addr),
    .sdr_scpu_dout(sdr_scpu_dout),
    .sdr_scpu_req(sdr_scpu_req),
    .sdr_scpu_rdy(sdr_scpu_rdy),

    .sdr_obj_addr(sdr_obj_addr),
    .sdr_obj_dout(sdr_obj_dout),
    .sdr_obj_req(sdr_obj_req),
    .sdr_obj_rdy(sdr_obj_rdy),

    .sdr_bg1_addr(sdr_bg1_addr),
    .sdr_bg1_dout(sdr_bg1_dout),
    .sdr_bg1_req(sdr_bg1_req),
    .sdr_bg1_rdy(sdr_bg1_rdy),

    .sdr_bg2_addr(sdr_bg2_addr),
    .sdr_bg2_dout(sdr_bg2_dout),
    .sdr_bg2_req(sdr_bg2_req),
    .sdr_bg2_rdy(sdr_bg2_rdy),

    // .sdr_map_addr(sdr_map_addr),
    // .sdr_map_dout(sdr_map_dout),
    // .sdr_map_req(sdr_map_req),
    // .sdr_map_rdy(sdr_map_rdy),

	//BRAM
    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

	//sound output
	  .snd1(snd1),
	  .snd2(snd2),
	  .sample(sample),

	//coin counters
	//.CUNT1(CUNT1),
	//.CUNT2(CUNT2),
	 .pause_rq(system_pause),
	//HACKS
	.CPU_turbo_mode(turbo_mode)
);

//Audio
logic [15:0] snd1, snd2;
logic sample;
assign AUDIO_S = 1'b1; //Signed audio samples
assign AUDIO_MIX = 2'b11; //0 No Mix, 1 25%, 2 50%, 3 100% mono

//synchronize audio
reg [15:0] snd1_r, snd2_r;
always @(posedge CLK_AUDIO) begin
	snd1_r <= snd1;
	snd2_r <= snd2;
	AUDIO_L <= snd1_r;
	AUDIO_R <= snd2_r;
end

//Reverse polarity of blank/sync signals for MiSTer
assign HBlank=  ~HBLANK_CORE;
assign VBlank=  ~VBLANK_CORE;
assign HSync =   HSYNC_CORE;
assign VSync =  ~VSYNC_CORE;


assign CLK_VIDEO = MS_CLK;

logic [7:0] R, G, B;
XSleenaCore_RGB4bitLUT R_LUT( .COL_4BIT(VIDEO_4R), .COL_8BIT(R));
XSleenaCore_RGB4bitLUT G_LUT( .COL_4BIT(VIDEO_4G), .COL_8BIT(G));
XSleenaCore_RGB4bitLUT B_LUT( .COL_4BIT(VIDEO_4B), .COL_8BIT(B));

// H/V offset
// wire [3:0]	hoffset = status[14:11];
// wire [3:0]	voffset = status[18:15];

assign VIDEO_ARX = (!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0;
/////////////////////// ARCADE VIDEO /////////////////////////////
wire [21:0] gamma_bus;
wire        direct_video;

// Video rotation 
wire no_rotate = ~status[10];
wire rotate_ccw = status[7];
wire video_rotated;
wire flip = status[6];

arcade_video #(256,24) arcade_video
(
        .*,
		.fx(scandoubler_fx),
		.gamma_bus(gamma_bus),
		.forced_scandoubler(forced_scandoubler),
        .clk_video(MS_CLK),
        .ce_pix(ce_pix),
	    .CE_PIXEL(CE_PIXEL),
	    .RGB_in({R,G,B}),
        .HBlank(HBlank),
        .VBlank(VBlank),
        .HSync(HSync),
        .VSync(VSync)
);

screen_rotate screen_rotate(.*);
//////////////////////////////////////////////////////////////////

///////////////////         Keyboard           //////////////////

reg btn_up       = 0;
reg btn_down     = 0;
reg btn_left     = 0;
reg btn_right    = 0;
reg btn_1        = 0;
reg btn_2        = 0;
reg btn_coin1    = 0;
reg btn_coin2    = 0;
reg btn_1p_start = 0;
reg btn_2p_start = 0;
reg btn_pause    = 0;
reg btn_service  = 0;

wire pressed = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
always @(posedge MS_CLK) begin
	reg old_state;
	old_state <= ps2_key[10];
	if(old_state != ps2_key[10]) begin
		case(code)
			'h16: btn_1p_start <= pressed; // 1
			'h1E: btn_2p_start <= pressed; // 2
			'h2E: btn_coin1    <= pressed; // 5
			'h36: btn_coin2    <= pressed; // 6
			'h46: btn_service  <= pressed; // 9
			'h4D: btn_pause    <= pressed; // P

			'h75: btn_up      <= pressed; // up
			'h72: btn_down    <= pressed; // down
			'h6B: btn_left    <= pressed; // left
			'h74: btn_right   <= pressed; // right
			'h14: btn_1       <= pressed; // ctrl
			'h11: btn_2       <= pressed; // alt
		endcase
	end
end

//////////////////////// GAME INPUTS ////////////////////////////
wire [15:0] joy = joystick_0 | joystick_1;

//SNAC joysticks
wire [15:0] SNAC_joy = JOY_DB1 | JOY_DB2;
wire [1:0] SNAC_dev;
assign SNAC_dev =  status[23:22];
wire         JOY_CLK, JOY_LOAD;
wire         JOY_DATA  = USER_IN[5];

always_comb begin
	USER_OUT[0] = JOY_LOAD;
	USER_OUT[1] = JOY_CLK;
	USER_OUT[2] = 1'b1;
	USER_OUT[3] = 1'b1;
	USER_OUT[4] = 1'b1;
	USER_OUT[5] = 1'b1;
	USER_OUT[6] = 1'b1;
end

wire [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( MS_CLK  ), //53.6MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

wire [15:0] JOY_DB1;
wire [15:0] JOY_DB2;
always_comb begin
	if ((SNAC_dev[0])) begin
		JOY_DB1 = JOYDB15_1;
	end else begin
		JOY_DB1 = 16'h00;
	end
end

always_comb begin
	if ((SNAC_dev[1])) begin
		JOY_DB2 = JOYDB15_2;
	end else begin
		JOY_DB2 = 16'h00;
	end
end

//////// Game inputs, the same controls are used for two player alternate gameplay ////////
//Dip Switches
// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge MS_CLK) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

//Added support for multigame core.
reg [7:0] game;
always @(posedge MS_CLK) begin
	if((ioctl_index == 1) && (ioctl_addr == 0)) begin
		game <= ioctl_dout;
	end
end

logic [7:0] DSW1, DSW2;
assign DSW1 = sw[0];
assign DSW2 = sw[1];


//Joysticks
//Player 1
wire m_up1;
wire m_down1;
wire m_left1;
wire m_right1;
wire m_SW1_1;
wire m_SW2_1;
logic m_start1;

//Player 2
wire m_up2;
wire m_down2;
wire m_left2;
wire m_right2;
wire m_SW1_2;
wire m_SW2_2;
logic m_start2;

logic m_coin1, m_coin2;
logic m_pause; //active high

//Xain'd Sleena uses only one set of game controls and 2 start buttons that are needed for play a continue
//wire [15:0] joy = joystick_0 | joystick_1;

// assign m_up1       = (SNAC_dev[0]) ? ~JOY_DB1[3]  : ~btn_up    & ~joystick_0[3];
// assign m_down1     = (SNAC_dev[0]) ? ~JOY_DB1[2]  : ~btn_down  & ~joystick_0[2];
// assign m_left1     = (SNAC_dev[0]) ? ~JOY_DB1[1]  : ~btn_left  & ~joystick_0[1];
// assign m_right1    = (SNAC_dev[0]) ? ~JOY_DB1[0]  : ~btn_right & ~joystick_0[0];
// assign m_SW1_1     = (SNAC_dev[0]) ? ~JOY_DB1[4]  : ~btn_1     & ~joystick_0[4];  //joy1 btn A
// assign m_SW2_1     = (SNAC_dev[0]) ? ~JOY_DB1[5]  : ~btn_2     & ~joystick_0[5];  //joy1 btn B

// assign m_up2       = (SNAC_dev[1]) ? ~JOY_DB2[3]  : ~btn_up    & ~joystick_1[3];
// assign m_down2     = (SNAC_dev[1]) ? ~JOY_DB2[2]  : ~btn_down  & ~joystick_1[2];
// assign m_left2     = (SNAC_dev[1]) ? ~JOY_DB2[1]  : ~btn_left  & ~joystick_1[1];
// assign m_right2    = (SNAC_dev[1]) ? ~JOY_DB2[0]  : ~btn_right & ~joystick_1[0];
// assign m_SW1_2     = (SNAC_dev[1]) ? ~JOY_DB2[4]  : ~btn_1     & ~joystick_1[4];  //joy2 btn A
// assign m_SW2_2     = (SNAC_dev[1]) ? ~JOY_DB2[5]  : ~btn_2     & ~joystick_1[5];  //joy2 btn B
assign m_up1       = ~JOY_DB1[3]  & ~btn_up    & ~joystick_0[3];
assign m_down1     = ~JOY_DB1[2]  & ~btn_down  & ~joystick_0[2];
assign m_left1     = ~JOY_DB1[1]  & ~btn_left  & ~joystick_0[1];
assign m_right1    = ~JOY_DB1[0]  & ~btn_right & ~joystick_0[0];
assign m_SW1_1     = ~JOY_DB1[4]  & ~btn_1     & ~joystick_0[4];  //joy1 btn A
assign m_SW2_1     = ~JOY_DB1[5]  & ~btn_2     & ~joystick_0[5];  //joy1 btn B

assign m_up2       = ~JOY_DB2[3]  & ~btn_up    & ~joystick_1[3];
assign m_down2     = ~JOY_DB2[2]  & ~btn_down  & ~joystick_1[2];
assign m_left2     = ~JOY_DB2[1]  & ~btn_left  & ~joystick_1[1];
assign m_right2    = ~JOY_DB2[0]  & ~btn_right & ~joystick_1[0];
assign m_SW1_2     = ~JOY_DB2[4]  & ~btn_1     & ~joystick_1[4];  //joy2 btn A
assign m_SW2_2     = ~JOY_DB2[5]  & ~btn_2     & ~joystick_1[5];  //joy2 btn B
// 4     5      6      7       8     9
//Shot,Jump,Start P1,Coin,Start P2,Pause

//SNAC: switch1 A, switch2 B, pause START+A, P2 Start (from P1 controls) START+B
// always @(posedge MS_CLK) begin
// 	m_start1    <= (SNAC_dev[0]) ? ~JOY_DB1[10]  : ~btn_1p_start & ~joy[6]; 
// 	m_start2    <= (SNAC_dev[0] | SNAC_dev[1]) ? ~((SNAC_dev[1] & JOY_DB2[10]) | (SNAC_dev[0] & JOY_DB1[5] & JOY_DB1[10]))   : ~btn_2p_start & ~joy[8]; //SNAC Select+B
// 	m_coin1     <= (SNAC_dev[0]) ? ~JOY_DB1[11]  : ~btn_coin1    & ~joystick_0[7];  //SNAC Select
// 	m_coin2     <= (SNAC_dev[1]) ? ~JOY_DB2[11]  : ~btn_coin2    & ~joystick_1[7];  
// 	m_pause     <= (SNAC_dev[0] || SNAC_dev[1]) ? (JOY_DB1[4] & JOY_DB1[10])|(JOY_DB2[4] & JOY_DB2[10]) : btn_pause    |  joy[9]; //active high //SNAC Select+A
// end

assign m_start1 = ~JOY_DB1[10] & ~btn_1p_start & ~joy[6]; 
assign m_start2 = ~((JOY_DB2[10]) | (JOY_DB1[6])) & ~btn_2p_start & ~joy[8]; //SNAC P1 button C, P2 Start
assign m_coin1  = ~JOY_DB1[11] & ~btn_coin1    & ~joystick_0[7]; 
assign m_coin2  = ~JOY_DB2[11] & ~btn_coin2    & ~joystick_1[7];  
assign m_pause  = (JOY_DB1[4] & JOY_DB1[10]) | (JOY_DB2[4] & JOY_DB2[10]) | btn_pause    |  joy[9]; //active high //SNAC Start+A


logic [7:0] PLAYER1, PLAYER2;
logic SERVICE;
//All inputs are active low except SERVICE
//               {2P,1P,1PSW2,1PSW1,1PD,1PU,1PL,1PR}              
assign PLAYER1 = {m_start2,m_start1,m_SW2_1,m_SW1_1,m_down1,m_up1,m_left1,m_right1};
//               {COIN2,COIN1,2PSW2,2PSW1,2PD,2PU,2PL,2PR}             
assign PLAYER2 = {m_coin2 ,m_coin1 ,m_SW2_2,m_SW1_2,m_down2,m_up2,m_left2,m_right2};
assign SERVICE = 1'b1; //Not used in game

//PAUSE
pause #(8,8,8,60) pause ( //R=G=B=8, 60MHz timing
 .clk_sys(MS_CLK),
 .reset(reset),
 .user_button((m_pause)),
 .pause_cpu(system_pause),
 .pause_request(0),
 .options({1'b0, pause_in_osd}),
 .OSD_STATUS(OSD_STATUS)
);

//HACKS
//Enable turbo mode to speed up the main and sub CPUs from 1.5MHz (original hardware speed) to 3.MHz
//for do it this was required to change the RAM related areas of tile/sprites from single port to dual
//port because in turbo mode sometimes the main CPU is accessing to this RAM areas while the tile engine 
//is drawing to the screen.
assign turbo_mode = {status[29],status[29]}; //{turbo_m],turbo_s}
endmodule
