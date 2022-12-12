//XSleenaCore_IO.sv
//Author: @RndMnkIII
//Date: 11/10/2022
`default_nettype none
`timescale 1ns/100ps
`define ASYNC_SIMU
//`define FIXED_P1P2_VALUE

module XSleenaCore_IO (
	input wire clk,
	input wire RSTn, //HACK
	input wire [3:0] AB,
	input wire IOn,
	input wire RW,
	input wire VBLK,
	input wire [7:0] DB_in,
	output logic [7:0] DB_out,
	input wire [7:0] PLAYER1, //{2P,1P,1PSW2,1PSW1,1PD,1PU,1PL,1PR}
	input wire [7:0] PLAYER2, //{COIN2,COIN1,2PSW2,2PSW1,2PD,2PU,2PL,2PR}
	input wire SERVICE,
	input wire [7:0] DSW1,
	input wire [7:0] DSW2,
	input wire JAMMA_24, //Unknow Conn J3X2 D2 1S953, R32 1K, R35 100, 0.01uF
	input wire JAMMA_b,  //Unknow Conn J3X2 D3 1S953, R   1K, R   100, 0.01uF

	//only for MCU protected versions
	input wire P5READn,
	input wire P5ACCEPTn,

	//Outputs and register map
	output logic R3A04n, //MCU data read
	output logic R3A06n, //MCU reset
	output logic W3A08n, //Sound latch
	output logic W3A09n, //maincpu NMI clear
	output logic W3A0An, //maincpu FIRQ clear
	output logic W3A0Bn, //maincpu IRQ clear
	output logic W3A0Cn, //subcpu IRQ assert
	output logic W3A0En, //MCU data write
	output logic [3:0] IOWDn,
	output logic W3A04n,
	output logic W3A05n,
	output logic W3A06n,
	output logic W3A07n,
	output logic CUNT1, //to coin counter 1
	output logic CUNT2, //to coin counter 2
	output logic P1_P2n,
	output logic P1_P2,
	output logic [2:0] PRI, //Layer priority register
	output logic BSL //maincpu ROM bank switch
);

	logic W3A0Dn, W3A0Fn;

	logic [7:0] ic91_Y; //3-8 Decoder
	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic91
	(
		.Enable1_bar(IOn), //4 G2An
		.Enable2_bar(IOn), //5 G2Bn
		.Enable3(RW), //6 G1
		.A(AB[2:0]), //3,2,1 C,B,A
		.Y(ic91_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	assign R3A04n = ic91_Y[4];
	assign R3A06n = ic91_Y[6];

	logic [7:0] ic92_Y; //3-8 Decoder
	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic92
	(
		.Enable1_bar(IOn), //4 G2An
		.Enable2_bar(RW), //5 G2Bn
		.Enable3(AB[3]), //6 G1
		.A(AB[2:0]), //3,2,1 C,B,A
		.Y(ic92_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	assign W3A08n = ic92_Y[0];
	assign W3A09n = ic92_Y[1];
	assign W3A0An = ic92_Y[2];
	assign W3A0Bn = ic92_Y[3];
	assign W3A0Cn = ic92_Y[4];
	assign W3A0Dn = ic92_Y[5]; //internal routing
	assign W3A0En = ic92_Y[6];
	assign W3A0Fn = ic92_Y[7]; //internal routing

	logic ic69c; //NOT gate
	assign #5 ic69c = ~AB[3];

	logic [7:0] ic90_Y; //3-8 Decoder
	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic90
	(
		.Enable1_bar(IOn), //4 G2An
		.Enable2_bar(RW), //5 G2Bn
		.Enable3(ic69c), //6 G1
		.A(AB[2:0]), //3,2,1 C,B,A
		.Y(ic90_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	assign IOWDn  = ic90_Y[3:0];
	assign W3A04n = ic90_Y[4];
	assign W3A05n = ic90_Y[5];
	assign W3A06n = ic90_Y[6];
	assign W3A07n = ic90_Y[7];

	//This replaces logic of TTL LS244 ICs: ic107, ic104, ic105, ic106, ic103 
	//ADDs one master clock period delay
	always_ff @(posedge clk) begin
		if (!ic91_Y[0]) begin //*3A00R START2, START1, 1P Controls
			DB_out <= PLAYER1;
		end
		else if (!ic91_Y[1]) begin //*3A01R COIN2, COIN1, 2P Controls
			DB_out <= PLAYER2;
		end
		else if (!ic91_Y[2]) begin //*3A02R DSW1
			DB_out <= DSW1;
		end
		else if (!ic91_Y[3]) begin //*3A03R DSW2
			DB_out <= DSW2;
		end
		else if (!ic91_Y[5]) begin //*3A05R JAMMA24, JAMMAb, SERVICE, *P5READ, *P5ACCEPT, VBLK
			DB_out <= {2'b11,VBLK,P5ACCEPTn,P5READn,SERVICE,JAMMA_b,JAMMA_24};
		end
		else
			DB_out <= 8'hFF;
	end

	logic ic76e; //NOT gate 
	assign ic76e = ~PLAYER1[7]; //COIN1
	assign CUNT1 = ic76e; //r52 1K, tr1 2SC1096, c121 0.01uF

	logic ic76c; //NOT gate
	assign ic76c = ~PLAYER2[7]; //COIN2
	assign CUNT2 = ic76c; //r53 1K, tr2 2SC1096, c122 0.01uF

	//Register 3A0D
	logic ic56a_Q, ic56a_Qn;
	DFF_pseudoAsyncClrPre #(.W(1)) ic56a (
		.clk(clk),
		.din(DB_in[0]),
		.q(ic56a_Q),
		.qn(ic56a_Qn),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(W3A0Dn) // signal whose edge will trigger the FF
  	);


`ifdef FIXED_P1P2_VALUE
	assign P1_P2n = 1'b0;
	assign P1_P2  = ~P1_P2n;
`else
	assign P1_P2n = ic56a_Q;
	assign P1_P2  = ic56a_Qn;
`endif	

	//Register 3A0F
	logic [3:0] ic79_Q;
	ttl_74174_sync #(.BLOCKS(4)) ic79
    (
        .Clk(clk),
        .Cen(W3A0Fn),
        .Clr_n(1'b1),
        .D(DB_in[3:0]), //Add one master clock delay here
        .Q(ic79_Q)
    );

	assign PRI = ic79_Q[2:0];
	assign BSL = ic79_Q[3];
endmodule