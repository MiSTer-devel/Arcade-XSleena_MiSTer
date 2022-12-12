//ttl_74112_sync.v
//Dual J-K Negative-Edge-Triggered FF with Preset and Clear
//Author: @RndMnkIII. 08/10/2022.
`default_nettype none
`timescale 1ns/1ps

module ttl_74112_sync #(parameter BLOCKS = 2)
(
  input wire [BLOCKS-1:0] PREn,
  input wire [BLOCKS-1:0] CLRn,
  input wire [BLOCKS-1:0] J,
  input wire [BLOCKS-1:0] K,
  input wire [BLOCKS-1:0] Clk,
  input wire [BLOCKS-1:0] Cen,
  output wire [BLOCKS-1:0] Q,
  output wire [BLOCKS-1:0] Qn
);
reg [BLOCKS-1:0] Q_current;
reg [BLOCKS-1:0] last_cen;

generate
    genvar i;
    for (i = 0; i < BLOCKS; i = i + 1)
    begin: gen_blocks
        initial Q_current[i] = 1'b0;
        always @(posedge Clk[i])

        begin
			last_cen[i] <= Cen[i];
			if (!PREn[i]) begin //pseudo asynchronous preset
				Q_current[i] <= 1'b1; //PRESET
			end
			else if (!CLRn[i]) begin //pseudo asynchronous clear
				Q_current[i] <= 1'b0; //CLEAR
			end
			else if (!Cen[i] && last_cen[i]) begin //detect falling edge of Cen[i]
				if (!J[i] && K[i])
					Q_current[i] <= 1'b0; //set low
				else if (J[i] && K[i])
					Q_current[i] <= ~Q_current[i]; //toggle
				else if (J[i] && ~K[i])
					Q_current[i] <= 1'b1; //set high
				// else J=K=L
				//   Q_current[i] <= Q_current[i]; //hold value
			end
		end

		assign Q[i] = Q_current[i];
		assign Qn[i] = ~Q_current[i];
    end
endgenerate
endmodule