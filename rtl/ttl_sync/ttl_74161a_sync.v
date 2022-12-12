//ttl_74161a_sync.v
//@RndMnkIII. 14/10/2022
// 4-bit modulo 16 binary counter with parallel load, 
//Asynchronous Master Reset (MRn) ->161A
//<START_TEMPLATE>
//ttl_74161a #(.DELAY_RISE(20), .DELAY_FALL(25)) <NAME> (.Clear_bar(), .Load_bar(), .ENT(), .ENP(), .D(), .Clk(), .RCO(), .Q());
//<END_TEMPLATE>
//
//tP_clk2tc = 19ns min, 25ns max
//tP_clk2q =  15ns min, 25ns max
//20,25
`default_nettype none
`timescale 1ns/1ns

module ttl_74161a_sync #(parameter WIDTH = 4)
(
  input wire Clk,
  input wire Cen,
  input wire Clear_bar, //1
  input wire Load_bar, //9
  input wire ENT, //7
  input wire ENP, //10
  input wire [WIDTH-1:0] D, //D 6, C 5, B 4, A 3
  output wire RCO, //15
  output wire [WIDTH-1:0] Q //QD 11, QC 12, QB 13, QA 14
);

//------------------------------------------------//
wire RCO_current;
reg [WIDTH-1:0] Q_current;
wire [WIDTH-1:0] Q_next;
reg last_cen;

initial last_cen = 1'b1;

initial Q_current = {WIDTH{1'b0}};

assign Q_next = Q_current + {{(WIDTH-1){1'b0}},1'b1};

always @(posedge Clk) begin
	last_cen <= Cen;

	if (!Clear_bar)
	begin
		Q_current <= {WIDTH{1'b0}};
	end
	else if (Cen && !last_cen) //detect rising edge of Cen
	begin
		if (!Load_bar)
		begin
		Q_current <= D;
		end

		if (Load_bar && ENT && ENP)
		begin
		Q_current <= Q_next;
		end
	end
end

assign RCO_current = ENT && (&Q_current);

// output
assign RCO = RCO_current;
assign Q = Q_current;

endmodule