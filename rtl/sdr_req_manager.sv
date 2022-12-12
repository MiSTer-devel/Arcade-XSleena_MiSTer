//@RndMnkIII. 22/11/2022
//sdr_req_manager.sv
//based on Irem M72 for MiSTer FPGA - Background layer SDRAM interface
//Copyright (C) 2022 Martin Donlon
module sdr_req_manager(
    input wire clk,
    input wire clk_ram,

    input wire [24:0] rom_addr_a,
    output logic [15:0] rom_data_a,
    input wire rom_req_a,
    output logic rom_rdy_a,

    input wire [24:0] rom_addr_b,
    output logic [15:0] rom_data_b,
    input wire rom_req_b,
    output logic rom_rdy_b,

    output logic [24:0] sdr_addr,
    input wire [15:0] sdr_data,
    output logic sdr_req,
    input wire sdr_rdy
);
	reg [1:0] active = 0;

	reg active_rq = 1'b0;
	reg active_ack = 1'b0;
	reg [15:0] active_data;

	reg rom_req_a2 = 1'b0;
	reg rom_req_b2 = 1'b0;
	reg [24:0] rom_addr_a2,rom_addr_b2;

	always @(posedge clk) begin
		sdr_req <= 1'b0;
		rom_rdy_a <= 1'b0;
		rom_rdy_b <= 1'b0;

		if (rom_req_a & ~rom_req_a2) begin
			rom_req_a2 <= 1'b1;
			rom_addr_a2 <= rom_addr_a;
		end

		if (rom_req_b & ~rom_req_b2) begin
			rom_req_b2 <= 1'b1;
			rom_addr_b2 <= rom_addr_b;
		end

		if (active) begin
			if (active_ack == active_rq) begin
				active <= 2'd0;
				if (active == 2'd1) begin
					rom_data_a <= active_data;
					rom_rdy_a <= 1;
            	end

				if (active == 2'd2) begin
					rom_data_b <= active_data;
					rom_rdy_b <= 1;
            	end
			end
		end else begin
			if (rom_req_a2) begin
				sdr_addr <= rom_addr_a2;
				sdr_req <= 1'b1;
				active_rq <= ~active_rq;
				active <= 2'd1;
				rom_req_a2 <= 1'b0;
			end else if (rom_req_b2) begin
				sdr_addr <= rom_addr_b2;
				sdr_req <= 1'b1;
				active_rq <= ~active_rq;
				active <= 2'd2;
				rom_req_b2 <= 1'b0;
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