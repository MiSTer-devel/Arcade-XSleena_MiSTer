//XSleenaCore_tb.sv
//Testbench for the Solar Warrior Core module
//Author: @RndMnkIII
//Date: 11/08/2022



//CAPTURE RAM contents from MAME:
//mame -debug -window xsleenaba
//focus 0
//save xs_desert_obj.bin,3800,200
//save xs_desert_map.bin,2000,800
//save xs_desert_bgram1.bin,2800,800
//save xs_desert_bgram0.bin,3000,800
//capture palette from: memory window: memory/:maincpu/0/:palette, memory/:maincpu/0/:palette_ext
//paste on vscode and edit, paste on hexedit and save: xs_desert_col1.bin, xs_desert_col2.bin
//FRAME:6055 X:300 Y:261
//Scroll registers:
//3A00: CF
//3A01: 00
//3A02: 00
//3A03: 01
//3A04: 00
//3A05: 00
//3A06: 00
//3A07: 01


//Rename image files replacing blanks with zeros:
//find . -depth -name "* *" -execdir rename 's/ /0/g' "{}" \;
//PPM to PNG conversion:
// mogrify -format png *.ppm
//FFMPEG convert to MP4 video (starting from frame 2):
// ffmpeg -r 57.4 -f image2 -s 384x272 -i xs_frm_%05d.png -vcodec libx264 -crf 17  -pix_fmt yuv420p xs_03.mp4
//ROM conversion (linux):
// find . -name "xs_*.bin" -exec srec_cat {} -Binary -Output {}_vmem.txt -VMem 8 -Output_Block_Size 16 \;
//CRT FX:
//ffcrt.bat color-VGA-hi.cfg xs_05.mp4 xs_05_fx.mp4
//
//Questasim:
//Optimize the design:
//vopt +acc XSleenaCore_tb -o XSleenaCore_tb_opt
//Load the design:
//vsim XSleenaCore_tb_opt
//do SWC_CLK_HVgen.do
//run -all
//VSYNC simulated measured period: 17.40939264 ms
//VSYNC simulated measured frequency: 57.44 Hz
//HSYNC simulated measured period: 64.01512 us
//HSYNC simulated measured frequency: 15.621 KHz
//VBLANK simulated measured period: 2.1121 ms
/*
    Based on the Solar Warrior schematics, vertical timing counts as follows:

        08,09,0A,0B,...,FC,FD,FE,FF,E8,E9,EA,EB,...,FC,FD,FE,FF,
        08,09,....

    Thus, it counts from 08 to FF, then resets to E8 and counts to FF again.
    This gives (256 - 8) + (256 - 232) = 248 + 24 = 272 total scanlines.

    VBLK is signalled starting when the counter hits F8, and continues through
    the reset to E8 and through until the next reset to 08 again.

    Since MAME's video timing is 0-based, we need to convert this.
*/
`default_nettype none
`timescale 1ns/10ps
//`define ASYNC_SIMU
//`define CAPTURE_SYNC
`define SAVE_FRAME
`define QUESTASIM_COMP

module XSleenaCore_tb();

    //Simulated PLL
    // --input clock 50MHz
    // clkout_0 -> 48MHz
    // clkout_1 -> 48MHz shifted 180 degrees
    localparam clkout_0_freq = 48_000_000;
    localparam clkout_0_p =  (1.0 / clkout_0_freq ) * 1_000_000_000;
    localparam clkout_0_hp = clkout_0_p / 2.0;

    //Sound master clock
    //Parameters for sound clock
    localparam mc_freq3 = 16_000_000;
    localparam mc_p3 =  (1.0 / mc_freq3) * 1_000_000_000;
    localparam mc_hp3 = mc_p3 / 2.0;

    //Parameters for sound clock
    localparam mc_freq2 = 8_000_000;
    localparam mc_p2 =  (1.0 / mc_freq2) * 1_000_000_000;
    localparam mc_hp2 = mc_p2 / 2.0;

    //Parameters for master clock
    localparam mc_freq = 12_000_000; // 13_396_071 Hz Measured from real PCB (0.0294% of difference)
    localparam mc_p =  (1.0 / mc_freq) * 1_000_000_000;
    localparam mc_hp = mc_p / 2.0;

    //Parameters for SDRAM clock
    localparam sdr_freq = 96_000_000;
    localparam sdr_p =  (1.0 / sdr_freq) * 1_000_000_000;
    localparam sdr_hp = sdr_p / 2.0;

    //localparam END_DUMP_DELTA = 5_000_000_000; //ns 500* 4 * 40 
    logic [63:0] simu_time = 64'd100_000_000_000;
    //localparam START_DUMP_DELTA = 0;
    //localparam SIMULATION_TIME = END_DUMP_DELTA - START_DUMP_DELTA;
    //localparam RESET_DLY = 8_065_408;
    localparam RESET_DLY = 100;

    //Main clocks for Synchronous design
    logic clk_48M = 1'b0;
    logic clk_48M_180sh = 1'b1;

    //SDRAM clock (96 MHz)
    logic clk_96M = 1'b0;

    always #clkout_0_hp clk_48M = ~clk_48M;
    always #clkout_0_hp clk_48M_180sh = ~clk_48M_180sh;
    always #sdr_hp clk_96M = ~clk_96M;
    //in FPGA this is replaced by a pll

    //16MHz Sound master clock
    logic clk16M = 1'b0;
    always #mc_hp3 clk16M = !clk16M;

    //using clock divider
    logic clk8M = 0;
    always @(posedge clk16M) begin
        clk8M <= ~clk8M;
    end

    //12MHz master clock
    logic clk = 0;
    always #mc_hp clk = !clk;

	logic RSTn;
    logic CSYNC;
    logic VBLK;
    logic [3:0] VIDEO_R;
    logic [3:0] VIDEO_G;
    logic [3:0] VIDEO_B;
    logic DISP;
	logic BLK;
    logic PIX_CLK;
    logic [8:0] SCR_X, SCR_Y;
    logic HSYNC, VSYNC;

    XSleenaCore xlc (
        .CLK(clk_48M),
        .SDR_CLK(clk_96M),
        .RSTn(RSTn),

        //Inputs
        .DSW1(8'h3f), // 80 Flip Screen On, 40 Cabinet Cocktail, 20 Allow continue Yes, 10 Demo Sounds On, 0C CoinB 1C/1C, 03 CoinA 1C/1C
        .DSW2(8'hff), //
        .PLAYER1(8'hff),
        .PLAYER2(8'hff),
        .SERVICE(1'b1),
	    .JAMMA_24(1'b1),
	    .JAMMA_b(1'b1),
        //Video output
        .CSYNC(CSYNC),
        .VIDEO_R(VIDEO_R),
        .VIDEO_G(VIDEO_G),
        .VIDEO_B(VIDEO_B),
        
        //sound output
        // output logic signed [15:0] snd,

    	//coin counters
        //.CUNT1(CUNT1),
        //.CUNT2(CUNT2),

        //For simulation
        .SCR_Y(SCR_Y),
        .SCR_X(SCR_X),
        .DISP(DISP), //BLKn
	    .BLK(BLK), //VBLKn
        .PIX_CLK(PIX_CLK),
	    .VSYNC(VSYNC), //NEGATIVE SYNC
	    .HSYNC(HSYNC)  //POSITIVE SYNC
    );

    logic [7:0] R8B, G8B, B8B;
    logic [7:0] RMIX,GMIX,BMIX;
    logic [7:0] RMIXreg,GMIXreg,BMIXreg;

    XSleenaCore_RGB4bitLUT R_LUT( .COL_4BIT(VIDEO_R), .COL_8BIT(R8B));
    XSleenaCore_RGB4bitLUT G_LUT( .COL_4BIT(VIDEO_G), .COL_8BIT(G8B));
    XSleenaCore_RGB4bitLUT B_LUT( .COL_4BIT(VIDEO_B), .COL_8BIT(B8B));

`ifdef SAVE_FRAME
        `ifdef CAPTURE_SYNC
            //VSYNC show as MAGENTA, HSYNC as CYAN, VBLANK period as purple, HBLANK period as YELLOW
            assign RMIX = (!VSYNC) ? 8'hff : ((!BLK) ? 8'h80 : ((HSYNC)? 8'h00 : ((!DISP) ? 8'hff : R8B))); 
            assign GMIX = (!VSYNC) ? 8'h00 : ((!BLK) ? 8'h00 : ((HSYNC)? 8'hff : ((!DISP) ? 8'hff : G8B))); 
            assign BMIX = (!VSYNC) ? 8'hff : ((!BLK) ? 8'h80 : ((HSYNC)? 8'hff : ((!DISP) ? 8'h00 : B8B))); 
        `else
            assign RMIX = (!DISP) ? 8'h00 : R8B; 
            assign GMIX = (!DISP) ? 8'h00 : G8B; 
            assign BMIX = (!DISP) ? 8'h00 : B8B; 
        `endif
            //***Frame output***
            integer frame_file;
            reg [15:0] frm_cnt=0;
            reg [15:0] indice=0;
            reg start_frame=1'b0;
            reg end_frame= 1'b0;
        
            always @(posedge BLK) begin
                frm_cnt <= frm_cnt + 1;
            end
            always @(posedge PIX_CLK) begin
        // `ifdef CAPTURE_SYNC
        //         start_frame <= ((SCR_X == 9'd383) && (SCR_Y == 9'd8) && (frm_cnt >= 1)) ? 1'b1 : 1'b0; //check one pixel earlier for 0 scanline 9
        // `else
        //         start_frame <= ((SCR_X == 9'd17) && (SCR_Y == 9'd9) && (frm_cnt >= 1)) ? 1'b1 : 1'b0;
        // `endif

        // `ifdef CAPTURE_SYNC
        //         end_frame <= ((SCR_X == 9'd382) && (SCR_Y == 9'd8) && (frm_cnt >= 2)) ? 1'b1 : 1'b0; //check one pixel earlier for 383 scanline 8
        // `else
        //         end_frame <= ((SCR_X == 9'd16) && (SCR_Y == 9'd9) && (frm_cnt >= 2)) ? 1'b1 : 1'b0;
        // `endif
        `ifdef CAPTURE_SYNC
                start_frame <= ((SCR_X == 9'd383) && (SCR_Y == 9'd8) && (frm_cnt >= 1)) ? 1'b1 : 1'b0; //check one pixel earlier for 0 scanline 9
        `else
                start_frame <= ((SCR_X == 9'd17) && (SCR_Y == 9'd11) && (frm_cnt >= 1)) ? 1'b1 : 1'b0;
        `endif

        `ifdef CAPTURE_SYNC
                end_frame <= ((SCR_X == 9'd382) && (SCR_Y == 9'd8) && (frm_cnt >= 2)) ? 1'b1 : 1'b0; //check one pixel earlier for 383 scanline 8
        `else
                end_frame <= ((SCR_X == 9'd16) && (SCR_Y == 9'd11) && (frm_cnt >= 2)) ? 1'b1 : 1'b0;
        `endif
                RMIXreg <= RMIX;
                GMIXreg <= GMIX;
                BMIXreg <= BMIX;
                if (start_frame) begin
                    indice = frm_cnt;
                    frame_file = $fopen($psprintf("xs_frm_%05d.ppm", indice), "w");
                    $display($psprintf("*** OPEN ID: %d : xs_frm_%05d.ppm\n",frame_file, indice));
                    $fwrite(frame_file,"P3\n");
        `ifdef CAPTURE_SYNC
                    $fwrite(frame_file,"%0d %0d\n",384, 272); //width,height
        `else
                    $fwrite(frame_file,"%0d %0d\n",256, 238); //width,height
        `endif
                    $fwrite(frame_file,"%0d\n",2**8-1);
                    $fwrite(frame_file," %0d %0d %0d \n",int'(RMIXreg),int'(GMIXreg),int'(BMIXreg));
                end 
                else if(end_frame) begin
                    $fwrite(frame_file," %0d %0d %0d \n",int'(RMIXreg),int'(GMIXreg),int'(BMIXreg));
                    $fclose(frame_file);
                    $display($sformatf("*** CLOSE ID: %0d FRM_CNT: %0d\n", frame_file, indice));
                end
                else begin
        `ifdef CAPTURE_SYNC
                    if (frm_cnt >= 2) $fwrite(frame_file," %0d %0d %0d \n",int'(RMIXreg),int'(GMIXreg),int'(BMIXreg));
        `else
                    if (frm_cnt >= 2 && DISP) $fwrite(frame_file," %0d %0d %0d \n",int'(RMIXreg),int'(GMIXreg),int'(BMIXreg));
        `endif
                end
            end
`else
            reg [15:0] frm_cnt=0;
            
            always @(posedge BLK) begin
                frm_cnt <= frm_cnt + 1;
            end
`endif

//Debugging stuff
integer f_frame;
initial begin
f_frame = $fopen("frame02_sync.txt","w");
end

always_ff @(posedge PIX_CLK) begin 
    if (frm_cnt == 2) begin
        $fwrite(f_frame, $psprintf("FRM:%05d Y:%03d X:%03d OBJ:%02h\n",
                           frm_cnt, 
                           XSleenaCore_tb.xlc.xs_clk.VPOS, 
                           {XSleenaCore_tb.xlc.xs_clk.VCUNT,XSleenaCore_tb.xlc.xs_clk.HN},
                           XSleenaCore_tb.xlc.xs_obj.OBJ));
    end
end

	// Proper sequence for the ModelSim reset
    initial begin : init
        RSTn = 1'b0;
        #2000;
        RSTn = 1'b1;
    end : init

`ifdef ICARUS_COMP
    initial $display("*** Using Icarus Verilog compiler/simulator ***");
`elsif QUESTASIM_COMP  
    initial $display("*** Using Questasim compiler/simulator ***");  
`elsif MODELSIM_COMP  
    initial $display("*** Using Modelsim compiler/simulator ***");      
`else 
    initial $display("*** Using Another Verilog compiler/simulator ***");
`endif
	initial 
	begin;
		//$dumpfile("AlphaMissionCore_tb.vcd");
		//$dumpvars(0,AlphaMissionCore_tb);
		//$dumpoff;
		//#START_DUMP_DELTA;
		//$dumpon;
		//#SIMULATION_TIME;
		#40_000_000;
		$finish;
		//$fclose(fsnd);
        $fclose(f_frame);
	end
endmodule
  