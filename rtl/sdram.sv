//
// sdram
// Copyright (c) 2015-2019 Sorgelig
//
// Some parts of SDRAM code used from project:
// http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module sdram
(
    input             init,        // reset to initialize RAM
    input             clk,         // clock 64MHz
   
    input             doRefresh,

    inout  reg [15:0] SDRAM_DQ,    // 16 bit bidirectional data bus
    output reg [12:0] SDRAM_A,     // 13 bit multiplexed address bus
    output            SDRAM_DQML,  // two byte masks
    output            SDRAM_DQMH,  // 
    output reg  [1:0] SDRAM_BA,    // two banks
    output            SDRAM_nCS,   // a single chip select
    output            SDRAM_nWE,   // write enable
    output            SDRAM_nRAS,  // row address select
    output            SDRAM_nCAS,  // columns address select
    output            SDRAM_CKE,   // clock enable
    output            SDRAM_CLK,   // clock for chip

    input      [26:1] ch0a_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    output reg [15:0] ch0a_dout,    // data output to cpu
    input             ch0a_req,     // request
    output reg        ch0a_ready,

    input      [26:1] ch0b_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    output reg [15:0] ch0b_dout,    // data output to cpu
    input             ch0b_req,     // request
    output reg        ch0b_ready,

    input      [26:1] ch1_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    output reg [15:0] ch1_dout,    // data output to cpu
    input             ch1_req,     // request
    output reg        ch1_ready,
    
    input      [26:1] ch2_addr,    
    output reg [15:0] ch2_dout,    
    input             ch2_req,     
    output reg        ch2_ready,

    // input      [26:1] ch4_addr,    
    // output reg [15:0] ch4_dout,    
    // input             ch4_req,     
    // output reg        ch4_ready,

    input      [26:1] ch3_addr,
    output reg [15:0] ch3_dout,
    input      [15:0] ch3_din,
    input      [ 1:0] ch3_be,
    input             ch3_req,
    input             ch3_rnw,     // 1 - read, 0 - write
    output reg        ch3_ready
);

assign SDRAM_nCS  = chip;
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE  = command[0];
assign SDRAM_CKE  = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];


// Burst length = 4
localparam BURST_LENGTH        = 1; //RndMnkIII
localparam BURST_CODE          = (BURST_LENGTH == 8) ? 3'b011 : (BURST_LENGTH == 4) ? 3'b010 : (BURST_LENGTH == 2) ? 3'b001 : 3'b000;  // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE         = 1'b0;     // 0=sequential, 1=interleaved
localparam CAS_LATENCY         = 3'd3;     // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE             = 2'b00;    // only 00 (standard operation) allowed
localparam NO_WRITE_BURST      = 1'b1;     // 0= write burst enabled, 1=only single access write
localparam MODE                = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_CODE};

localparam sdram_startup_cycles= 14'd12100;// 100us, plus a little more, @ 100MHz
localparam cycles_per_refresh  = 14'd500;  // (64000*64)/8192-1 Calc'd as (64ms @ 64MHz)/8192 rose
localparam startup_refresh_max = 14'b11111111111111;

// SDRAM commands
wire [2:0] CMD_NOP             = 3'b111;
wire [2:0] CMD_ACTIVE          = 3'b011;
wire [2:0] CMD_READ            = 3'b101;
wire [2:0] CMD_WRITE           = 3'b100;
wire [2:0] CMD_PRECHARGE       = 3'b010;
wire [2:0] CMD_AUTO_REFRESH    = 3'b001;
wire [2:0] CMD_LOAD_MODE       = 3'b000;

reg [13:0] refresh_count = startup_refresh_max - sdram_startup_cycles;
reg  [2:0] command;
reg        chip;

localparam STATE_STARTUP = 0;
localparam STATE_WAIT    = 1;
localparam STATE_RW1     = 2;
localparam STATE_IDLE    = 4;
localparam STATE_IDLE_1  = 5;
localparam STATE_IDLE_2  = 6;
localparam STATE_IDLE_3  = 7;
localparam STATE_IDLE_4  = 8;
localparam STATE_IDLE_5  = 9;
localparam STATE_RFSH    = 10;


always @(posedge clk) begin
    reg [CAS_LATENCY+BURST_LENGTH+1:0] data_ready_delay0a, data_ready_delay0b, data_ready_delay1, data_ready_delay2, data_ready_delay3; //, data_ready_delay4;

    reg        saved_wr;
    reg [12:0] cas_addr;
    reg [15:0] saved_data;
    reg [15:0] dq_reg;
    reg  [3:0] state = STATE_STARTUP;

    reg       ch0a_req_1, ch0b_req_1, ch1_req_1, ch2_req_1, ch3_req_1; //, ch4_req_1;
    reg       ch0a_rq, ch0b_rq, ch1_rq, ch2_rq, ch3_rq; //, ch4_rq;
    reg [2:0] ch;

    reg        ch3_rnw_1;
    reg [26:1] ch3_addr_1;
    reg [15:0] ch3_din_1;
    reg [ 1:0] ch3_be_1;
    
    reg        doRefresh_1;
    
    ch0a_req_1 <= ch0a_req;
    ch0b_req_1 <= ch0b_req;
    ch1_req_1 <= ch1_req;
    ch2_req_1 <= ch2_req;
    ch3_req_1 <= ch3_req;
    //ch4_req_1 <= ch4_req;
    
    ch3_rnw_1  <= ch3_rnw;
    ch3_addr_1 <= ch3_addr;
    ch3_din_1  <= ch3_din;
    ch3_be_1   <= ch3_be;
    
    doRefresh_1 <= doRefresh;

    if (ch0a_req & ~ch0a_req_1) ch0a_rq <= 1;
    if (ch0b_req & ~ch0b_req_1) ch0b_rq <= 1;
    if (ch1_req & ~ch1_req_1) ch1_rq <= 1;
    if (ch2_req & ~ch2_req_1) ch2_rq <= 1;
    if (ch3_req & ~ch3_req_1) ch3_rq <= 1;
    //if (ch4_req & ~ch4_req_1) ch4_rq <= 1;

    ch0a_ready <= 0;
    ch0b_ready <= 0;
    ch1_ready <= 0;
    ch2_ready <= 0;
    ch3_ready <= 0;
    //ch4_ready <= 0;

    refresh_count <= refresh_count+1'b1;

    data_ready_delay0a <= data_ready_delay0a>>1;
    data_ready_delay0b <= data_ready_delay0b>>1;
    data_ready_delay1 <= data_ready_delay1>>1;
    data_ready_delay2 <= data_ready_delay2>>1;
    data_ready_delay3 <= data_ready_delay3>>1;
    //data_ready_delay4 <= data_ready_delay4>>1;

    dq_reg <= SDRAM_DQ;

    // if(data_ready_delay1[4]) ch1_dout[15:00] <= dq_reg;
    // if(data_ready_delay1[3]) ch1_dout[31:16] <= dq_reg;
    // if(data_ready_delay1[3]) ch1_ready <= 1;

    // if(data_ready_delay2[4]) ch2_dout[15:00] <= dq_reg;
    // if(data_ready_delay2[3]) ch2_dout[31:16] <= dq_reg;
    // if(data_ready_delay2[2]) ch2_dout[47:32] <= dq_reg;
    // if(data_ready_delay2[1]) ch2_dout[63:48] <= dq_reg;
    // if(data_ready_delay2[1]) ch2_ready <= 1;

    // if(data_ready_delay3[4]) ch3_dout[15:00] <= dq_reg;
    // if(data_ready_delay3[4]) ch3_ready <= 1;

    //RndMnkIII
    //1 + BURST_LENGTH - CHANNEL_LENGTH
    if(data_ready_delay0a[1]) ch0a_dout[15:0] <= dq_reg;
    if(data_ready_delay0a[1]) ch0a_ready <= 1;
    if(data_ready_delay0b[1]) ch0b_dout[15:0] <= dq_reg;
    if(data_ready_delay0b[1]) ch0b_ready <= 1;
    if(data_ready_delay1[1]) ch1_dout[15:0] <= dq_reg;
    if(data_ready_delay1[1]) ch1_ready <= 1;
    if(data_ready_delay2[1]) ch2_dout[15:0] <= dq_reg;
    if(data_ready_delay2[1]) ch2_ready <= 1;
    if(data_ready_delay3[1]) ch3_dout[15:0] <= dq_reg;
    if(data_ready_delay3[1]) ch3_ready <= 1;
    // if(data_ready_delay4[1]) ch4_dout[15:0] <= dq_reg;
    // if(data_ready_delay4[1]) ch4_ready <= 1;

    SDRAM_DQ <= 16'bZ;

    command <= CMD_NOP;
    case (state)
        STATE_STARTUP: begin
            SDRAM_A    <= 0;
            SDRAM_BA   <= 0;

            if (refresh_count == (startup_refresh_max-64)) chip <= 0;
            if (refresh_count == (startup_refresh_max-32)) chip <= 1;

            // All the commands during the startup are NOPS, except these
            if (refresh_count == startup_refresh_max-63 || refresh_count == startup_refresh_max-31) begin
                // ensure all rows are closed
                command     <= CMD_PRECHARGE;
                SDRAM_A[10] <= 1;  // all banks
                SDRAM_BA    <= 2'b00;
            end
            if (refresh_count == startup_refresh_max-55 || refresh_count == startup_refresh_max-23) begin
                // these refreshes need to be at least tREF (66ns) apart
                command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-47 || refresh_count == startup_refresh_max-15) begin
                command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-39 || refresh_count == startup_refresh_max-7) begin
                // Now load the mode register
                command     <= CMD_LOAD_MODE;
                SDRAM_A     <= MODE;
            end

            if (!refresh_count) begin
                state   <= STATE_IDLE;
                refresh_count <= 0;
            end
        end

        STATE_IDLE_5: state <= STATE_IDLE_4;
        STATE_IDLE_4: state <= STATE_IDLE_3;
        STATE_IDLE_3: state <= STATE_IDLE_2;
        STATE_IDLE_2: state <= STATE_IDLE_1;
        STATE_IDLE_1: state <= STATE_IDLE;

        STATE_RFSH: begin
            state    <= STATE_IDLE_5;
            command  <= CMD_AUTO_REFRESH;
            chip     <= 1;
        end

        STATE_IDLE: begin
            if (refresh_count > cycles_per_refresh) begin // emergency refresh, mainly for downloading rom/paused core
                state         <= STATE_RFSH;
                command       <= CMD_AUTO_REFRESH;
                refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
                chip          <= 0;
            end 
            else if(ch0a_rq) begin
                {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch0a_addr[25:1]};
                chip       <= ch0a_addr[26];
                saved_wr   <= 0;
                ch         <= 0;
                ch0a_rq     <= 0;
                command    <= CMD_ACTIVE;
                state      <= STATE_WAIT;
            end
            else if(ch0b_rq) begin
                {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch0b_addr[25:1]};
                chip       <= ch0b_addr[26];
                saved_wr   <= 0;
                ch         <= 1;
                ch0b_rq     <= 0;
                command    <= CMD_ACTIVE;
                state      <= STATE_WAIT;
            end
            else if(ch1_rq) begin
                {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch1_addr[25:1]};
                chip       <= ch1_addr[26];
                saved_wr   <= 0;
                ch         <= 2;
                ch1_rq     <= 0;
                command    <= CMD_ACTIVE;
                state      <= STATE_WAIT;
            end
            else if(ch2_rq) begin
                {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch2_addr[25:1]};
                chip       <= ch2_addr[26];
                saved_wr   <= 0;
                ch         <= 3;
                ch2_rq     <= 0;
                command    <= CMD_ACTIVE;
                state      <= STATE_WAIT;
            end
            else if(ch3_rq) begin
                chip       <= ch3_addr_1[26];
                saved_data <= ch3_din_1;
                saved_wr   <= ~ch3_rnw_1;
                ch         <= 4;
                ch3_rq     <= 0;
                if (ch3_rnw_1) 
                    {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch3_addr_1[25:1]};
                else
                    {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch3_be_1, 1'b1, ch3_addr_1[25:1]};
                command    <= CMD_ACTIVE;
                state      <= STATE_WAIT;
            end
            // else if(ch4_rq) begin
            //     {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch4_addr[25:1]};
            //     chip       <= ch4_addr[26];
            //     saved_wr   <= 0;
            //     ch         <= 5;
            //     ch4_rq     <= 0;
            //     command    <= CMD_ACTIVE;
            //     state      <= STATE_WAIT;
            // end
            else if (doRefresh_1) begin
                state         <= STATE_RFSH;
                command       <= CMD_AUTO_REFRESH;
                refresh_count <= 0;
                chip          <= 0;
            end
        end

        STATE_WAIT: state <= STATE_RW1;
        STATE_RW1: begin
            SDRAM_A <= cas_addr;
            if(saved_wr) begin
                command  <= CMD_WRITE;
                SDRAM_DQ <= saved_data;
                if(ch == 0) ch0a_ready  <= 1;
                if(ch == 1) ch0b_ready  <= 1;
                if(ch == 2) ch1_ready   <= 1;
                if(ch == 3) ch2_ready   <= 1;
                if(ch == 4) ch3_ready   <= 1;
                // if(ch == 5) ch4_ready   <= 1;
                state <= STATE_IDLE_2;
            end
            else begin
                command <= CMD_READ;
                state   <= STATE_IDLE_5;
                     if(ch == 0) data_ready_delay0a[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                else if(ch == 1) data_ready_delay0b[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                else if(ch == 2) data_ready_delay1[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                else if(ch == 3) data_ready_delay2[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                // else if(ch == 4) data_ready_delay3[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                else             data_ready_delay3[CAS_LATENCY+BURST_LENGTH+1] <= 1;
                // else             data_ready_delay4[CAS_LATENCY+BURST_LENGTH+1] <= 1;
            end
        end
      
    endcase

    if (init) begin
        state <= STATE_STARTUP;
        refresh_count <= startup_refresh_max - sdram_startup_cycles;
    end
end

//180degrees external SDRAM clk shift
altddio_out
#(
    .extend_oe_disable("OFF"),
    .intended_device_family("Cyclone V"),
    .invert_output("OFF"),
    .lpm_hint("UNUSED"),
    .lpm_type("altddio_out"),
    .oe_reg("UNREGISTERED"),
    .power_up_high("OFF"),
    .width(1) //Specify the width of the data buses.
)
sdramclk_ddr
(
    .datain_h(1'b0), //Input data for rising edge of outclock port. Input port WIDTH wide.
    .datain_l(1'b1), //Input data for falling edge of outclock port. Input port WIDTH wide.
    .outclock(clk), //Clock signal to register data output. dataout port outputs DDR data on each level of outclock signal.
    .dataout(SDRAM_CLK), //	DDR output data port. Output port WIDTH wide. dataout port should directly feed an output pin in top-level design.
    .aclr(1'b0),
    .aset(1'b0),
    .oe(1'b1), //Output enable for the dataout port. Active-high signal. You can add an inverter if you need an active-low oe.
    .outclocken(1'b1), //	Clock enable for outclock port.
    .sclr(1'b0),
    .sset(1'b0)
);

//USE ODDR in Xilinx part?
// ODDR: Output Double Data Rate Output Register with Set, Reset
//       and Clock Enable.
//       7 Series
// Xilinx HDL Language Template, version 2021.2

// ODDR #(
//    .DDR_CLK_EDGE("SAME_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE"
//    .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
//    .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC"
// ) ODDR_inst (
//    .Q(Q),   // 1-bit DDR output-> SDRAM_CLK
//    .C(C),   // 1-bit clock input -> clk
//    .CE(CE), // 1-bit clock enable input -> 1'b1
//    .D1(D1), // 1-bit data input (positive edge) -> datain_h
//    .D2(D2), // 1-bit data input (negative edge) -> datain_l
//    .R(R),   // 1-bit reset 1'b0
//    .S(S)    // 1-bit set 1'b0
// );

// End of ODDR_inst instantiation
endmodule
