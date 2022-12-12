// Dual D flip-flop with set; positive-edge-triggered

// Note: Preset_bar is asynchronous as specified in datasheet for this device,
//ignored Clear_bar, for implementations that don't use the Clear input
`default_nettype none
`timescale 1ns/1ns


module ttl_7474 #(parameter BLOCKS = 2, DELAY_RISE = 0, DELAY_FALL = 0)
(
  input wire [BLOCKS-1:0] Clear_bar,
  input wire [BLOCKS-1:0] Preset_bar,
  input wire [BLOCKS-1:0] D,
  input wire [BLOCKS-1:0] Clk,
  output wire [BLOCKS-1:0] Q,
  output wire [BLOCKS-1:0] Q_bar
);

//------------------------------------------------//
reg [BLOCKS-1:0] Q_current = 0;

generate
  genvar i;
  for (i = 0; i < BLOCKS; i = i + 1)
  begin: gen_blocks
    //initial Q_current[i] = 1'b0; //supposition
    always @(posedge Clk[i] or negedge Clear_bar or negedge Preset_bar[i])
    begin
      if (!Clear_bar[i])
        Q_current[i] <= 1'b0;
      else if (!Preset_bar[i])
        Q_current[i] <= 1'b1;
      else
      begin
        Q_current[i] <= D[i];
      end
    end
  end
endgenerate
//------------------------------------------------//

assign #(DELAY_RISE, DELAY_FALL) Q = Q_current;
assign #(DELAY_RISE, DELAY_FALL) Q_bar = ~Q_current;

endmodule