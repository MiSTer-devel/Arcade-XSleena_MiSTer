//ttl_74194.v
//4-Bit Bidirectional Universal Shift Register
`default_nettype none
`timescale 1ns/1ns

module ttl_74194 #(parameter DELAY_RISE = 12, DELAY_FALL = 15)
(
  input wire CR_n,
  input wire CP,
  input wire S0,S1,
  input wire Dsl,Dsr,
  input wire D0,D1,D2,D3,
  output wire Q0,Q1,Q2,Q3
);
 
	reg [0:3] q_reg=4'b0000;
	wire [1:0] s_reg;
	assign s_reg={S1,S0};
	always @(posedge CP or negedge CR_n) begin //WARNING: changing from posedge CR_n
		if (!CR_n) begin
			q_reg<=4'b0000;
		end else begin
			case (s_reg)
				2'b00 :q_reg<=q_reg;
				2'b01 :q_reg<={Dsr,q_reg[0:2]}; //Shift right
				2'b10 :q_reg<={q_reg[1:3],Dsl}; //Shift left
				2'b11 :q_reg<={D0,D1,D2,D3};
				default:q_reg<=4'b0000;
			endcase
		end
	end
	
	assign #(DELAY_RISE, DELAY_FALL) Q0=q_reg[0];
	assign #(DELAY_RISE, DELAY_FALL) Q1=q_reg[1];
	assign #(DELAY_RISE, DELAY_FALL) Q2=q_reg[2];
	assign #(DELAY_RISE, DELAY_FALL) Q3=q_reg[3];
endmodule