// Copyright (C) XSleenaCore Francisco Javier Fuentes Moreno (@RndMnkIII)
// This file is part of XSleenaCore <https://github.com/RndMnkIII/XSleenaCore_CLK>.
//
// XSleenaCore is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// XSleenaCore is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with XSleenaCore. If not, see <http://www.gnu.org/licenses/>.

//XSleenaCore_CLK.sv
//Author: @RndMnkIII
//Date: 11/10/2022
`default_nettype none
`timescale 1ns/10ps
//in real PCB the CLK is generated using the following circuit:
//              +-----------|[]|-----------+
//              |        12MHz Xtal        |
//              +--v^v^--+        +--v^v^--+ 
//              | 470Ohm |        | 470Ohm |
//              +--->o---+---||---+--->o---+--->o---- CLK
//                 LS04    0.1uF     LS04     LS04   
//
module XSleenaCore_CLK(
  input wire clk, //48MHz
  input wire clk_12_cen,//Clock enable signal
  input wire RSTn,
  input wire P1_P2n,

  //clocks
  //H counter signals
  output logic HCLK, //HCLK
  output logic HCLKn, //HCLK3,HCLK2,HCLK1,HCLK0
  output logic [7:0] HN,
  //output logic M1Hn,
  output logic [1:0] HPOS,
  output logic [5:0] DHPOS,
  output logic DVCUNT,
  output logic VCUNT,
  output logic M4Hn,

  //V counter signals
  output logic VI,
  output logic [7:0] VPOS,
  output logic [7:0] DVPOS,
  output logic IMS,

  //Video signals
  output logic VBLK,
  output logic VBLKn,
  output logic VSYNC,
  output logic HSYNC,
  output logic CSYNC,

  //Others
  output logic T1n,
  output logic T2n,
  output logic T3n,
  output logic T3,
  output logic M0n,
  output logic M1n,
  output logic M2n,
  output logic M3n,
  output logic CLRn,
  output logic BLKn,
  output logic EDIT,
  output logic EDITn,
  output logic OBJCHG,
  output logic OBJCHGn,
  output logic OBJCLRn,
  output logic RAMCLRn,
  output logic OBCH
  );
  //--------- H Counter --------
  logic [3:0] ic29_Q;
  logic ic29_RCO;
  ttl_74163a_sync ic29
    (
        .Clk(clk), //2
        .Clear_bar(1'b1), //1
        // .Load_bar(HLDn), //9
        .Load_bar(1'b1), //HACK
        .ENT(1'b1), //7
        .ENP(1'b1), //10
        .D({4'b0000}), //D 6, C 5, B 4, A 3
        .Cen(clk_12_cen),
        .RCO(ic29_RCO), //15
        .Q(ic29_Q) //QD 11, QC 12, QB 13, QA 14
    );

    //logic ic44_notC;
    //assign #5 ic44_notC = ~ic29_Q[1];

    assign HCLK = ic29_Q[0]; //HCLK
    assign HCLKn = ~ic29_Q[0]; //HCLK3,HCLK2,HCLK1,HCLK0

    logic [3:0] ic27_Q;
    logic ic27_RCO;
    ttl_74163a_sync ic27
    (
        .Clk(clk), //2
        .Clear_bar(1'b1), //1 SYNCHRONOUS RESET
        .Load_bar(1'b1),
        .ENT(ic29_RCO), //7
        .ENP(ic29_RCO), //10
        .D({4'b0000}), //D 6, C 5, B 4, A 3
        .Cen(clk_12_cen),
        .RCO(ic27_RCO), //15
        .Q(ic27_Q) //QD 11, QC 12, QB 13, QA 14
    );

    logic ic27_Q3buf;
    assign ic27_Q3buf = ic27_Q[3]; //used an LS32 as buffer (two inputs common connected)

    logic [3:0] ic42_Q;
    logic ic42_RCO;
    logic ic42_LD;
    ttl_74163a_sync ic42
    (
        .Clk(clk), //2
        .Clear_bar(1'b1), //1 SYNCHRONOUS RESET
        .Load_bar(ic42_LD),
        .ENT(ic29_RCO), //7
        .ENP(ic27_RCO), //10
        .D({4'b0000}), //D 6, C 5, B 4, A 3
        .Cen(clk_12_cen),
        .RCO(), //15
        .Q(ic42_Q) //QD 11, QC 12, QB 13, QA 14
    );
    assign HN = {ic42_Q[0],ic27_Q[3:0], ic29_Q[3:1]};
    assign ic42_LD = ~(ic27_RCO & ic42_Q[1]);

    logic ic44_notB;
    assign ic44_notB = ~ic42_Q[0];

    logic ic44_notF;
    assign ic44_notF = ~ic29_Q[3];

    logic ic43_nandD;
    assign #10 ic43_nandD = ~(ic27_Q3buf & ic42_Q[1]);

    logic ic43_nandC;
    assign ic43_nandC = ~(ic44_notB  & ic43_nandD);

    logic [7:0] xor_hcount;
    assign xor_hcount[0] = P1_P2n ^ ic29_Q[1];
    assign xor_hcount[1] = P1_P2n ^ ic29_Q[2];
    assign xor_hcount[2] = P1_P2n ^ ic44_notF; //~ic29_Q[3]
    assign xor_hcount[3] = P1_P2n ^ ic27_Q[0];
    assign xor_hcount[4] = P1_P2n ^ ic27_Q[1];
    assign xor_hcount[5] = P1_P2n ^ ic27_Q[2];
    assign xor_hcount[6] = P1_P2n ^ ic27_Q3buf; //ic27_Q[3]
    assign xor_hcount[7] = P1_P2n ^ ic43_nandC;

    //Add one master clock delay here:
    logic [7:0] xor_hcount_r;
    always_ff @(posedge clk) begin
      xor_hcount_r <= xor_hcount;
    end

    logic [5:0] ic11_Q;
    ttl_74174_sync ic11
    (
        .Clk(clk),
        .Cen(ic29_Q[3]),
        .Clr_n(1'b1),
        .D({ic42_Q[1],xor_hcount_r[7:3]}), //Add one master clock delay here
        .Q(ic11_Q)
    );

    assign HPOS   = xor_hcount_r[1:0]; //Add one master clock delay here
    assign DHPOS  = {ic11_Q[4:0], xor_hcount_r[2]}; //Add one master clock delay here
    assign DVCUNT = ic11_Q[5];
    assign VCUNT  = ic42_Q[1];
    assign M4Hn    = ic44_notF;

  //--------- V Counter --------
  logic ic44_notA; //Clocking Signal
  assign ic44_notA = ~ic42_Q[1];

  logic ic44_notE;
  assign ic44_notE = ~ic27_Q3buf;

  logic ic43_nandB;
  assign ic43_nandB = ~(ic44_notE & ic27_Q[2]);

  logic ic44_notD;
  assign ic44_notD = ~ic27_Q[1];

  logic ic47B_Q;
  DFF_pseudoAsyncClrPre #(.W(1)) ic47B (
    .clk(clk),
    .din(ic43_nandB),
    .q(ic47B_Q),
    .qn(),
    .set(~ic42_Q[1]),    // active high
    .clr(1'b0),    // active high
    .cen(ic27_Q[1]) // signal whose edge will trigger the FF
  );

  DFF_pseudoAsyncClrPre #(.W(1)) ic47A (
    .clk(clk),
    .din(ic47B_Q),
    .q(),
    .qn(HSYNC),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(ic44_notD) // signal whose edge will trigger the FF
  );

  //Asynchronous reset counter
  logic [3:0] ic45_Q;
  logic ic45_RCO;
  logic ic47_notC;
  ttl_74161_sync ic45
  (
      .Clk(clk), //2
      .Clear_bar(RSTn), //1 ASYNCHRONOUS RESET
      .Load_bar(ic47_notC),
      .ENT(1'b1), //7
      .ENP(1'b1), //10
      .D({4'b1000}), //D 6, C 5, B 4, A 3
      .Cen(ic44_notA),
      .RCO(ic45_RCO), //15
      .Q(ic45_Q) //QD 11, QC 12, QB 13, QA 14
  );

  logic [3:0] ic46_Q;
  logic ic46_RCO;
  logic  ic33A_Qn;
  ttl_74161_sync ic46
  (
      .Clk(clk), //2
      .Clear_bar(RSTn), //1 ASYNCHRONOUS RESET
      .Load_bar(ic47_notC),
      .ENT(ic45_RCO), //7
      .ENP(ic45_RCO), //10
      .D({{3{ic33A_Qn}},1'b0}), //D 6, C 5, B 4, A 3
      .Cen(ic44_notA),
      .RCO(ic46_RCO), //15
      .Q(ic46_Q) //QD 11, QC 12, QB 13, QA 14
  );

  assign ic47_notC = ~ic46_RCO;

  logic ic33A_Q;
  ttl_74112_sync #(.BLOCKS(1)) ic33A
  (
    .PREn(RSTn),
    .CLRn(1'b1),
    .J(ic46_RCO),
    .K(ic46_RCO),
    .Clk(clk),
    .Cen(ic42_Q[1]),
    .Q(ic33A_Q),
    .Qn(ic33A_Qn)
  );
  
  logic ic33B_Qn;
  ttl_74112_sync #(.BLOCKS(1)) ic33B
  (
    .PREn(ic33A_Qn),
    .CLRn(RSTn),
    .J(ic33A_Q),
    .K(ic33A_Qn),
    .Clk(clk),
    .Cen(ic42_Q[1]),
    .Q(),
    .Qn(ic33B_Qn)
  );
  
  logic ic48_notF;
  assign ic48_notF = ~ic46_Q[0];

  logic ic15_nandB; //VSYNC
  assign ic15_nandB = ~(ic48_notF & ic33A_Q);
  assign VSYNC = ic15_nandB;

  logic ic60_xorA;
  assign ic60_xorA = HSYNC ^ VSYNC; //CSYNC
  assign CSYNC = ic60_xorA;

  assign VI = ic45_Q[0];
  logic [7:0] xor_vcount;
  assign xor_vcount[0] = P1_P2n ^ ic45_Q[0];
  assign xor_vcount[1] = P1_P2n ^ ic45_Q[1];
  assign xor_vcount[2] = P1_P2n ^ ic45_Q[2];
  assign xor_vcount[3] = P1_P2n ^ ic45_Q[3];
  assign xor_vcount[4] = P1_P2n ^ ic46_Q[0];
  assign xor_vcount[5] = P1_P2n ^ ic46_Q[1];
  assign xor_vcount[6] = P1_P2n ^ ic46_Q[2];
  assign xor_vcount[7] = P1_P2n ^ ic46_Q[3];

  assign VPOS = xor_vcount; //VPOS

  //Add one master clock delay here:
  logic [7:0] xor_vcount_r;
  always_ff @(posedge clk) begin
    xor_vcount_r <= xor_vcount;
  end

  logic [7:0] ic13_Q;
  ttl_74273_sync ic13(.CLRn(1'b1), .Clk(clk),.Cen(ic44_notA) /* synthesis syn_direct_enable = 1 */, .D(xor_vcount_r), .Q(ic13_Q)); //Add one master clock delay here

  ttl_74273_sync ic14(.CLRn(1'b1), .Clk(clk),.Cen(ic44_notA) /* synthesis syn_direct_enable = 1 */, .D(ic13_Q), .Q(DVPOS));

  logic ic32_nand; //LS30 NAND
  assign ic32_nand = ~(ic45_Q[3] & ic46_Q[0] & ic46_Q[1] & ic46_Q[2] & ic46_Q[3]);

  //add one master clock cycle to ic32_nand to fix VBLK pulse
  logic ic32_nand_r; 
  always_ff @(posedge clk) begin
    ic32_nand_r <= ic32_nand;
  end

  logic ic15_nandC; //VBLK
  //assign ic15_nandC = ~(ic32_nand & ic33B_Qn); 
  assign ic15_nandC = ~(ic32_nand_r & ic33B_Qn); //add one master clock cycle to ic32_nand to fix VBLK pulse

  //*** START OF FIX to offset VLBK,VBLKn after VI signal ***
  //Add one master clock delay
  logic ic15_nandC_dly;
  always_ff @(posedge clk) begin
    ic15_nandC_dly <= ic15_nandC;
  end
  assign VBLK = ic15_nandC_dly;

  logic ic48_notE; //VBLKn
  assign ic48_notE = ~ic15_nandC_dly;
  //*** END OF FIX ***

  // NMI fires on scanline 248 (VBL) and is latched
  // VBLK input bit is held high from scanlines 248-255:
  //           __________________________________      __________________________________________________...  ___________________
  // VBLK ____/                                  \____/                                                                          \_____
  //      ____                                    ____                                                                            _____
  // VBLKn    \__________________________________/    \__________________________________________________... ____________________/
  // VPOS  247| 248| 249| 250| 251| 252| 253| 254| 255| 232| 233| 234| 235| 236| 237| 238| 239| 240| 241|... | 253| 254| 255|   8|   9|
  //             F8                                      E8
  //      __  ___  ___  ___  ___  ___  ___  ___  ___                                           ___  __       ___  ___  ___  ___  ___  _     
  //CSYNC   \/   \/   \/   \/   \/   \/   \/   \/   \/|__/\___/\___/\___/\___/\___/\___/\___/\|   \/  \/|...    \/   \/   \/   \/   \/                    
  assign VBLKn = ic48_notE;

  logic [7:0] V_CNT;

  assign V_CNT = {ic46_Q,ic45_Q};

  // FIRQ (IMS) fires every on every 8th scanline (except 0)
  assign IMS = ic45_Q[3]; //ic46_Q[1]; //Vcnt[3]

  // ----- CLK2 ------
  logic ic64_dum;
  ttl_74139  #(.DELAY(0)) ic64(  .Enable_bar(1'b0), .A_2D(HN[1:0]), .Y_2D({T3n,T2n,T1n,ic64_dum}));

  assign T3 = ~T3n;

  logic ic70_dum0,ic70_dum2,ic70_dum4,ic70_dum6;
  ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic70
  (
    .Enable1_bar(1'b0), //4 G2An
    .Enable2_bar(1'b0), //5 G2Bn
    .Enable3(HN[0]), //6 G1
    .A(HN[3:1]), //3,2,1 C,B,A
    .Y({M3n,ic70_dum6,M2n,ic70_dum4,M1n,ic70_dum2,M0n,ic70_dum0}) //7,9,10,11,12,13,14,15 Y[7:0]
  );

  logic M3; //not gate
  assign M3= ~M3n;

  logic ic74A_Q, ic74A_Qn;
  DFF_pseudoAsyncClrPre #(.W(1)) ic74A (
    .clk(clk),
    .din(VCUNT),
    .q(ic74A_Q),
    .qn(ic74A_Qn),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN[3]) // signal whose edge will trigger the FF
  );
  logic HN3n;
  assign HN3n = ~HN[3];

  logic ic74B_Q;
  DFF_pseudoAsyncClrPre #(.W(1)) ic74B (
    .clk(clk),
    .din(ic74A_Q),
    .q(ic74B_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN3n) // signal whose edge will trigger the FF
  );

  logic ic6A_Q;
  DFF_pseudoAsyncClrPre #(.W(1)) ic6A (
    .clk(clk),
    .din(ic74B_Q),
    .q(ic6A_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HCLKn) // signal whose edge will trigger the FF
  );

  logic ic91_nand3; //LS10
  assign ic91_nand3 = ~(M3 & ic74A_Qn & ic6A_Q);
  assign CLRn = ic91_nand3;

  logic ic73A_Q,ic73A_Qn;
  DFF_pseudoAsyncClrPre #(.W(1)) ic73A (
    .clk(clk),
    .din(VI),
    .q(ic73A_Q),
    .qn(ic73A_Qn),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN3n) // signal whose edge will trigger the FF
  );
  assign EDIT = ic73A_Q;
  assign EDITn = ic73A_Qn;

  logic ic73B_Q;
  DFF_pseudoAsyncClrPre #(.W(1)) ic73B (
    .clk(clk),
    .din(VBLK),
    .q(ic73B_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(VI) // signal whose edge will trigger the FF
  );

  logic ic71B; //nor gate
  assign ic71B = ~(ic6A_Q | ic73B_Q);
  assign BLKn = ic71B;

  logic ic72A_Q,ic72A_Qn;
  DFF_pseudoAsyncClrPre #(.W(1)) ic72A (
    .clk(clk),
    .din(VI),
    .q(ic72A_Q),
    .qn(ic72A_Qn),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN[1]) // signal whose edge will trigger the FF
  );
  assign OBJCHG = ic72A_Q;
  assign OBJCHGn = ic72A_Qn;

  logic ic72B_Q,ic72B_Qn;
  DFF_pseudoAsyncClrPre #(.W(1)) ic72B (
    .clk(clk),
    .din(VCUNT),
    .q(ic72B_Q),
    .qn(ic72B_Qn),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN[1]) // signal whose edge will trigger the FF
  );

  logic ic53A_Q; 
  DFF_pseudoAsyncClrPre #(.W(1)) ic53A (
    .clk(clk),
    .din(ic72B_Q),
    .q(ic53A_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HCLK) // signal whose edge will trigger the FF
  );

  logic ic15A; //nand
  assign ic15A = ~(ic53A_Q & ic72B_Qn); //Schematic ic53A_Qn pin5, FIXED ic53A_Q
  assign OBJCLRn = ic15A;

  logic ic53B_Q; 
  DFF_pseudoAsyncClrPre #(.W(1)) ic53B (
    .clk(clk),
    .din(T2n),
    .q(ic53B_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HCLK) // signal whose edge will trigger the FF
  );

  logic ic38C; //OR gate
  assign ic38C = (ic53B_Q | T3n);
  assign RAMCLRn = ic38C;

  logic ic63A_Q; 
  DFF_pseudoAsyncClrPre #(.W(1)) ic63A (
    .clk(clk),
    .din(VI),
    .q(ic63A_Q),
    .qn(),
    .set(1'b0),    // active high
    .clr(1'b0),    // active high
    .cen(HN[0]) // signal whose edge will trigger the FF
  );
  assign OBCH = ic63A_Q;
endmodule