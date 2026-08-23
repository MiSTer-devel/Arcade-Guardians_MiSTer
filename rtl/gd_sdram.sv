// Single-port SDR SDRAM controller for the MiSTer 32 MiB module.
//
// The interface uses a toggle request/acknowledge handshake. Address, data,
// byte enables, and direction must remain stable until mem_ack equals mem_req.
//
// Copyright (C) 2026
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_sdram
(
	input  logic        clk,
	input  logic        reset,

	inout  wire  [15:0] SDRAM_DQ,
	output logic [12:0] SDRAM_A,
	output logic  [1:0] SDRAM_BA,
	output wire         SDRAM_CLK,
	output wire         SDRAM_CKE,
	output logic        SDRAM_DQML,
	output logic        SDRAM_DQMH,
	output wire         SDRAM_nCS,
	output wire         SDRAM_nWE,
	output wire         SDRAM_nCAS,
	output wire         SDRAM_nRAS,

	input  logic [24:0] mem_addr,
	input  logic [15:0] mem_din,
	input  logic  [1:0] mem_be,
	input  logic        mem_burst,
	input  logic [63:0] mem_burst_data,
	input  logic        mem_rnw,
	input  logic        mem_req,
	output logic [15:0] mem_dout,
	output logic        mem_ack,

	// Four-word graphics-row DMA. The renderer consumes one eight-byte planar
	// row at a time; fetching only that critical row keeps first-use latency
	// low enough to finish a scanline even when the scene changes completely.
	input  logic        video_dma_req,
	input  logic [24:0] video_dma_addr,
	output logic        video_dma_ack,
	output logic [63:0] video_dma_data,

	output logic        ready
);

localparam logic [2:0] CMD_LOAD_MODE = 3'b000;
localparam logic [2:0] CMD_REFRESH   = 3'b001;
localparam logic [2:0] CMD_PRECHARGE = 3'b010;
localparam logic [2:0] CMD_ACTIVE    = 3'b011;
localparam logic [2:0] CMD_WRITE     = 3'b100;
localparam logic [2:0] CMD_READ      = 3'b101;
localparam logic [2:0] CMD_NOP       = 3'b111;

// Burst length 4, sequential access, CAS 3, single-location write burst.
// Graphics reads still return one complete eight-byte row per command, while
// loader writes use the proven one-word transaction path.
localparam logic [12:0] MODE_REGISTER = 13'h232;

// The production core runs this controller at 68.75 MHz. The initialization
// delay exceeds 100 us and the refresh cadence is below the required 7.8 us.
localparam logic [15:0] INIT_DELAY_CYCLES = 16'd24000;
localparam logic [15:0] REFRESH_CYCLES    = 16'd400;

typedef enum logic [3:0]
{
	ST_INIT_WAIT,
	ST_INIT_TRP,
	ST_INIT_RFC1,
	ST_INIT_RFC2,
	ST_INIT_MRD,
	ST_IDLE,
	ST_ACTIVATE,
	ST_READ_WAIT,
	ST_WRITE_WAIT,
	ST_BURST_WRITE,
	ST_REFRESH_WAIT,
	ST_DMA_RCD,
	ST_DMA_STREAM,
	ST_DMA_TRP
} state_t;

state_t state;
logic [15:0] delay_count;
logic [15:0] refresh_count;
logic  [2:0] command;
logic [24:0] latched_addr;
logic [15:0] latched_din;
logic  [1:0] latched_be;
logic        latched_rnw;
logic        latched_req;
logic        latched_burst;
logic [63:0] latched_burst_data;
logic [2:0]  burst_write_word;
logic [15:0] dq_out;
logic        dq_oe = 1'b0;
// Keep one fixed capture register between the SDRAM pins and all controller
// clients. This is the same structure used by established MiSTer SDRAM
// controllers and lets Quartus place all sixteen bits in their input I/O
// cells. Writing SDRAM_DQ directly into a variable burst slice can leave
// three of the four row words captured in core logic instead.
logic [15:0] dq_capture;

// The core, loader, graphics arbiter and this controller all use clk_sys.
// Keep the toggle payload direct; the previous two-stage synchronizer was a
// leftover from an abandoned double-rate SDRAM clock and consumed two clocks
// from every scanline-critical row fetch.
wire [24:0] mem_addr_sdr = mem_addr;
wire [15:0] mem_din_sdr = mem_din;
wire  [1:0] mem_be_sdr = mem_be;
wire        mem_burst_sdr = mem_burst;
wire [63:0] mem_burst_data_sdr = mem_burst_data;
wire        mem_rnw_sdr = mem_rnw;
wire        mem_req_sdr = mem_req;
wire        video_dma_req_sdr = video_dma_req;
wire [24:0] video_dma_addr_sdr = video_dma_addr;

logic  [5:0] dma_issued;
logic  [5:0] dma_captured;
logic [24:0] dma_address;
logic  [4:0] dma_valid_pipe;
logic        dma_burst_active;

assign SDRAM_DQ = dq_oe ? dq_out : 16'hzzzz;
assign SDRAM_CKE = 1'b1;
assign SDRAM_nCS = 1'b0;
assign {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} = command;

// The SDRAM clock is phase-aligned with the registered command outputs.
// A DDR output primitive gives a clean forwarded clock on hardware while
// retaining a simple clock assignment for RTL simulation.
`ifdef SYNTHESIS
altddio_out
#(
	.extend_oe_disable("OFF"),
	.intended_device_family("Cyclone V"),
	.invert_output("OFF"),
	.lpm_hint("UNUSED"),
	.lpm_type("altddio_out"),
	.oe_reg("UNREGISTERED"),
	.power_up_high("OFF"),
	.width(1)
)
sdram_clock_out
(
	.datain_h(1'b0),
	.datain_l(1'b1),
	.outclock(clk),
	.dataout(SDRAM_CLK),
	.aclr(1'b0),
	.aset(1'b0),
	.oe(1'b1),
	.outclocken(1'b1),
	.sclr(1'b0),
	.sset(1'b0)
);
`else
// The synthesized ALTDDIO instance forwards an inverted clock: commands and
// DQ change on clk's rising edge, then the SDRAM samples them half a cycle
// later on SDRAM_CLK's rising edge.
assign SDRAM_CLK = ~clk;
`endif

// Keep the shared DQ output enable as a simple, always-loaded register. This
// allows Quartus to duplicate it into the sixteen I/O cells instead of
// implementing a synchronous-clear/load combination in core logic.
always_ff @(posedge clk) begin
	dq_oe <= !reset
	      && (((state == ST_ACTIVATE) && (delay_count == 16'd0)
	           && !latched_rnw)
	          || (state == ST_BURST_WRITE));
end

always_ff @(posedge clk) begin
	if (reset)
		dq_capture <= 16'd0;
	else
		dq_capture <= SDRAM_DQ;
end

always_ff @(posedge clk) begin
	command    <= CMD_NOP;
	SDRAM_DQML <= 1'b1;
	SDRAM_DQMH <= 1'b1;

	if (reset) begin
		state         <= ST_INIT_WAIT;
		delay_count   <= INIT_DELAY_CYCLES;
		refresh_count <= 16'd0;
		SDRAM_A       <= 13'd0;
		SDRAM_BA      <= 2'd0;
		mem_dout      <= 16'd0;
		mem_ack       <= 1'b0;
		video_dma_ack <= 1'b0;
		video_dma_data <= 64'd0;
		ready         <= 1'b0;
		latched_addr  <= 25'd0;
		latched_din   <= 16'd0;
		latched_be    <= 2'd0;
		latched_rnw   <= 1'b1;
		latched_req   <= 1'b0;
		latched_burst <= 1'b0;
		latched_burst_data <= 64'd0;
		burst_write_word <= 3'd0;
		dma_issued    <= 6'd0;
		dma_captured  <= 6'd0;
		dma_address   <= 25'd0;
		dma_valid_pipe <= 5'd0;
		dma_burst_active <= 1'b0;
	end
	else begin
		if (ready && (refresh_count != 16'hffff))
			refresh_count <= refresh_count + 16'd1;

		case (state)
			ST_INIT_WAIT: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_A       <= 13'd0;
					SDRAM_A[10]   <= 1'b1;
					SDRAM_BA      <= 2'd0;
					command        <= CMD_PRECHARGE;
					delay_count    <= 16'd3;
					state          <= ST_INIT_TRP;
				end
			end

			ST_INIT_TRP: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					command      <= CMD_REFRESH;
					delay_count  <= 16'd10;
					state        <= ST_INIT_RFC1;
				end
			end

			ST_INIT_RFC1: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					command      <= CMD_REFRESH;
					delay_count  <= 16'd10;
					state        <= ST_INIT_RFC2;
				end
			end

			ST_INIT_RFC2: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_A      <= MODE_REGISTER;
					SDRAM_BA     <= 2'd0;
					command      <= CMD_LOAD_MODE;
					delay_count  <= 16'd3;
					state        <= ST_INIT_MRD;
				end
			end

			ST_INIT_MRD: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					ready         <= 1'b1;
					refresh_count <= 16'd0;
					state         <= ST_IDLE;
				end
			end

			ST_IDLE: begin
				// Address is don't-care for REFRESH and NOP. Select a pending
				// request address independently of refresh priority so the
				// refresh counter is not on the timing path to every SDRAM_A
				// I/O register.
				if (video_dma_req_sdr != video_dma_ack) begin
					SDRAM_BA <= video_dma_addr_sdr[24:23];
					SDRAM_A  <= video_dma_addr_sdr[22:10];
				end
				else if (mem_req_sdr != mem_ack) begin
					SDRAM_BA <= mem_addr_sdr[24:23];
					SDRAM_A  <= mem_addr_sdr[22:10];
				end
				else begin
					SDRAM_BA <= 2'd0;
					SDRAM_A  <= 13'd0;
				end

				if (refresh_count >= REFRESH_CYCLES) begin
					command       <= CMD_REFRESH;
					refresh_count <= 16'd0;
					delay_count   <= 16'd10;
					state         <= ST_REFRESH_WAIT;
				end
				else if (video_dma_req_sdr != video_dma_ack) begin
					dma_address <= video_dma_addr_sdr;
					dma_valid_pipe <= 5'd0;
					dma_burst_active <= 1'b0;
					command <= CMD_ACTIVE;
					// Keep the conservative hardware-proven ACTIVE-to-READ
					// guard. Shorter nominally legal delays are not reliable on
					// all MiSTer SDRAM modules at this controller phase.
					delay_count <= 16'd3;
					state <= ST_DMA_RCD;
				end
				else if (mem_req_sdr != mem_ack) begin
					latched_addr <= mem_addr_sdr;
					latched_din  <= mem_din_sdr;
					latched_be   <= mem_be_sdr;
					latched_rnw  <= mem_rnw_sdr;
					latched_req  <= mem_req_sdr;
					latched_burst <= mem_burst_sdr;
					latched_burst_data <= mem_burst_data_sdr;

					// 32 MiB linear byte address:
					// bank[1:0], row[12:0], column[8:0], byte lane.
					command      <= CMD_ACTIVE;
					delay_count  <= 16'd3;
					state        <= ST_ACTIVATE;
				end
			end

			ST_ACTIVATE: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					SDRAM_BA       <= latched_addr[24:23];
					SDRAM_A        <= 13'd0;
					SDRAM_A[10]    <= 1'b1; // auto-precharge
					SDRAM_A[8:0]   <= latched_addr[9:1];
					SDRAM_DQML     <= ~latched_be[0];
					SDRAM_DQMH     <= ~latched_be[1];

					if (latched_rnw) begin
						command      <= CMD_READ;
						// CAS latency is three. Capture midway through the
						// single data cycle, three clk rising edges after the
						// SDRAM samples this command.
						delay_count  <= 16'd4;
						state        <= ST_READ_WAIT;
					end
					else begin
						command      <= CMD_WRITE;
						dq_out <= latched_burst ? latched_burst_data[15:0]
						                              : latched_din;
						if (latched_burst) begin
							// BL4 write: one WRITE command and four consecutive
							// data words while keeping the row open.
							SDRAM_A[10] <= 1'b0;
							burst_write_word <= 3'd1;
							state <= ST_BURST_WRITE;
						end
						else begin
							delay_count <= 16'd5;
							state <= ST_WRITE_WAIT;
						end
					end
				end
			end

			ST_BURST_WRITE: begin
				SDRAM_BA <= latched_addr[24:23];
				SDRAM_A <= 13'd0;
				SDRAM_DQML <= 1'b0;
				SDRAM_DQMH <= 1'b0;
				case (burst_write_word)
					3'd1: dq_out <= latched_burst_data[31:16];
					3'd2: dq_out <= latched_burst_data[47:32];
					default: dq_out <= latched_burst_data[63:48];
				endcase
				if (burst_write_word == 3'd3) begin
					command <= CMD_PRECHARGE;
					SDRAM_A[10] <= 1'b1;
					delay_count <= 16'd3;
					state <= ST_WRITE_WAIT;
				end
				else burst_write_word <= burst_write_word + 3'd1;
			end

			ST_READ_WAIT: begin
				// SDR SDRAM read DQM has pipeline latency. Keep both lanes
				// unmasked until the returned word has been captured.
				SDRAM_DQML <= 1'b0;
				SDRAM_DQMH <= 1'b0;
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					mem_dout <= dq_capture;
					mem_ack  <= latched_req;
					state    <= ST_IDLE;
				end
			end

			ST_WRITE_WAIT: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					mem_ack <= latched_req;
					state   <= ST_IDLE;
				end
			end

			ST_REFRESH_WAIT: begin
				if (delay_count != 16'd0)
					delay_count <= delay_count - 16'd1;
				else
					state <= ST_IDLE;
			end

			ST_DMA_RCD: begin
				// DQM must already be low before the first CAS-latency data
				// word. Leaving the top-level default high here tri-states DQ.
				SDRAM_DQML <= 1'b0;
				SDRAM_DQMH <= 1'b0;
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					dma_issued   <= 6'd0;
					dma_captured <= 6'd0;
					dma_valid_pipe <= 5'd0;
					state <= ST_DMA_STREAM;
				end
			end

			ST_DMA_STREAM: begin
				SDRAM_DQML <= 1'b0;
				SDRAM_DQMH <= 1'b0;
				dma_valid_pipe <= {dma_valid_pipe[3:0],
				                   (dma_issued == 6'd0)};

				SDRAM_BA <= dma_address[24:23];
				SDRAM_A <= 13'd0;
				SDRAM_A[8:0] <= dma_address[9:1];
				if (dma_issued == 6'd0) begin
					SDRAM_A[10] <= 1'b1;
					command <= CMD_READ;
					dma_issued <= 6'd1;
				end

				if (dma_valid_pipe[4] || dma_burst_active) begin
					video_dma_data[dma_captured[1:0] * 16 +: 16]
						<= dq_capture;
					if (dma_captured == 6'd3) begin
						dma_burst_active <= 1'b0;
						delay_count <= 16'd3;
						state <= ST_DMA_TRP;
					end
					else begin
						dma_burst_active <= 1'b1;
						dma_captured <= dma_captured + 6'd1;
					end
				end
			end

			ST_DMA_TRP: begin
				if (delay_count != 16'd0) begin
					delay_count <= delay_count - 16'd1;
				end
				else begin
					video_dma_ack <= video_dma_req_sdr;
					state <= ST_IDLE;
				end
			end

			default: state <= ST_INIT_WAIT;
		endcase
	end
end

endmodule
