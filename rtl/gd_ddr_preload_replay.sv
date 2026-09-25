// Replay a MiSTer direct-to-DDR MRA download through the existing ROM loader.
// A normal ioctl byte stream remains a pass-through fallback. Inspired by
// Martin Donlon's GPL-3.0 Arcade-IGSPGM_MiSTer ddr_rom_loader_adaptor.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_ddr_preload_replay #(
	parameter logic [26:0] IMAGE_BYTES = 27'h2300000
)
(
	input  logic        clk,
	input  logic        reset,
	input  logic        hps_downloading,
	input  logic        hps_wr,
	input  logic [26:0] hps_addr,
	input  logic  [7:0] hps_data,
	output logic        hps_wait,
	output logic        loader_downloading,
	output logic        loader_wr,
	output logic [26:0] loader_addr,
	output logic  [7:0] loader_data,
	input  logic        loader_wait,
	output logic [25:0] preload_addr,
	output logic        preload_req,
	input  logic [63:0] preload_data,
	input  logic        preload_ack
);

typedef enum logic [1:0] {
	IDLE, REQUEST, WAIT_DATA, EMIT
} replay_state_t;
replay_state_t state;
logic hps_downloading_d;
logic saw_stream_write;
logic [26:0] offset;
logic [63:0] line;

assign hps_wait = (state == IDLE) ? loader_wait : 1'b1;
assign loader_downloading = hps_downloading || (state != IDLE)
	|| (hps_downloading_d && !saw_stream_write);
assign loader_wr = (state == IDLE) ? hps_wr : (state == EMIT);
assign loader_addr = (state == IDLE) ? hps_addr : offset;
assign loader_data = (state == IDLE) ? hps_data
	: line[{offset[2:0], 3'b000} +: 8];

always_ff @(posedge clk) begin
	hps_downloading_d <= hps_downloading;
	if (reset) begin
		state <= IDLE;
		hps_downloading_d <= 1'b0;
		saw_stream_write <= 1'b0;
		offset <= 27'd0;
		line <= 64'd0;
		preload_addr <= 26'd0;
		preload_req <= 1'b0;
	end
	else begin
		if (hps_downloading && !hps_downloading_d)
			saw_stream_write <= hps_wr;
		else if (hps_downloading && hps_wr)
			saw_stream_write <= 1'b1;

		case (state)
			IDLE: if (hps_downloading_d && !hps_downloading
			           && !saw_stream_write) begin
				offset <= 27'd0;
				state <= REQUEST;
			end
			REQUEST: begin
				preload_addr <= offset[25:0];
				preload_req <= ~preload_req;
				state <= WAIT_DATA;
			end
			WAIT_DATA: if (preload_ack == preload_req) begin
				line <= preload_data;
				state <= EMIT;
			end
			EMIT: if (!loader_wait) begin
				if (offset == IMAGE_BYTES - 27'd1)
					state <= IDLE;
				else begin
					offset <= offset + 27'd1;
					if (&offset[2:0]) state <= REQUEST;
				end
			end
			default: state <= IDLE;
		endcase
	end
end

endmodule
