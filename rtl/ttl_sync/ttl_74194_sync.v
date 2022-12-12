//ttl_74194.v
//4-Bit Bidirectional Universal Shift Register
//@RndMnkIII. 20/10/2022
`default_nettype none
`timescale 1ns/100ps

module ttl_74194_sync
(
  input wire clk,
  input wire cen, //CP
  input wire CR_n,
  input wire S0,S1,
  input wire Dsl,Dsr,
  input wire D0,D1,D2,D3,
  output wire Q0,Q1,Q2,Q3
);
 
	reg [3:0] q_reg;
	wire [1:0] s_reg;
	reg last_cen;

	initial q_reg = 4'h0;
    initial last_cen = 1'b1;

	assign s_reg={S1,S0};

	always @(posedge clk) begin
        last_cen <= cen;

		if (!CR_n) begin
			q_reg<=4'b0000;
		end else if (cen && !last_cen) begin  //detect rising edge of Cen
			case (s_reg)
				2'b00 :q_reg<=q_reg;
				2'b01 :q_reg<={q_reg[2:0],Dsr}; //Shift right
				2'b10 :q_reg<={Dsl,q_reg[3:1]}; //Shift left
				2'b11 :q_reg<={D3,D2,D1,D0};
				default:q_reg<=4'b0000;
			endcase
		end
	end
	
	assign  Q0=q_reg[0];
	assign  Q1=q_reg[1];
	assign  Q2=q_reg[2];
	assign  Q3=q_reg[3];
endmodule