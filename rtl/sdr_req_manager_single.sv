//@RndMnkIII. 21/11/2022
//sdr_req_manager_single.sv
module sdr_req_manager_single(
    input wire clk,
    input wire clk_ram,

    input wire [24:0] rom_addr,
    output logic [15:0] rom_data,
    input wire rom_req,
    output logic rom_rdy,

    output logic [24:0] sdr_addr,
    input wire [15:0] sdr_data,
    output logic sdr_req,
    input wire sdr_rdy
);
	reg active = 1'b0;

	reg active_rq = 1'b0;
	reg active_ack = 1'b0;
	reg [15:0] active_data;

	reg rom_req2 = 1'b0;
	reg [24:0] rom_addr2;

	always @(posedge clk) begin
		sdr_req <= 1'b0;
		rom_rdy <= 1'b0;

		if (rom_req & ~rom_req2) begin
			rom_req2 <= 1'b1;
			rom_addr2 <= rom_addr;
		end

		if (active) begin
			if (active_ack == active_rq) begin
				active <= 1'b0;
				rom_data <= active_data;
				rom_rdy <= 1'b1;
			end
		end else begin
			if (rom_req2) begin
				sdr_addr <= rom_addr2;
				sdr_req <= 1'b1;
				active_rq <= ~active_rq;
				active <= 1'b1;
				rom_req2 <= 1'b0;
			end
		end
	end

	always @(posedge clk_ram) begin
		if (sdr_rdy) begin
			active_ack <= active_rq;
			active_data <= sdr_data;
		end
	end
endmodule