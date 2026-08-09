// Direct MRA-stream loader for the 35 MiB Guardians ROM image.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_rom_loader
(
	input  logic        clk,
	input  logic        reset,
	input  logic        memory_ready,
	input  logic        downloading,
	input  logic        ioctl_wr,
	input  logic [26:0] ioctl_addr,
	input  logic  [7:0] ioctl_data,
	output logic        ioctl_wait,

	output logic        ddr_load_wr,
	output logic [25:0] ddr_load_addr,
	output logic  [7:0] ddr_load_data,
	input  logic        ddr_load_wait,
	input  logic        ddr_load_idle,

	output logic [24:0] gfx_addr,
	output logic [15:0] gfx_din,
	output logic  [1:0] gfx_be,
	output logic        gfx_rnw,
	output logic        gfx_req,
	input  logic        gfx_ack,

	output logic        rom_ready,
	output logic        layout_error,
	output logic [26:0] accepted_bytes,
	output logic  [2:0] regions_seen
);

localparam logic [26:0] PROGRAM_END = 27'h0200000;
localparam logic [26:0] GRAPHICS_END = 27'h2200000;
localparam logic [26:0] IMAGE_END = 27'h2300000;

logic downloading_d;
logic completion_pending;
logic gfx_word_pending;
logic [24:0] gfx_word_address;
logic [7:0] gfx_upper;

wire stream_program = (ioctl_addr < PROGRAM_END);
wire stream_graphics = (ioctl_addr >= PROGRAM_END)
	&& (ioctl_addr < GRAPHICS_END);
wire stream_sample = (ioctl_addr >= GRAPHICS_END)
	&& (ioctl_addr < IMAGE_END);

// Graphics are written a word at a time to the low-latency SDRAM. Program and
// sample bytes continue to use the packed MiSTer DDR transport.
assign ioctl_wait = !memory_ready
	|| (stream_graphics ? gfx_word_pending : ddr_load_wait);

// Present DDR-bound bytes directly to the memory packer. This keeps the
// ready/valid decision in the same cycle as ioctl acceptance; registering a
// one-clock pulse here can otherwise lose the first byte after each 64-bit
// DDR write when waitrequest rises on the following edge.
always_comb begin
	ddr_load_wr = ioctl_wr && !ioctl_wait
		&& (stream_program || stream_sample);
	ddr_load_data = ioctl_data;
	if (stream_sample)
		ddr_load_addr = 26'h0200000 + (ioctl_addr - 27'h2200000);
	else
		ddr_load_addr = ioctl_addr[25:0];
end

always_ff @(posedge clk) begin
	downloading_d <= downloading;

	if (reset) begin
		downloading_d <= 1'b0;
		completion_pending <= 1'b0;
		gfx_word_pending <= 1'b0;
		gfx_word_address <= 25'd0;
		gfx_upper <= 8'd0;
		gfx_addr <= 25'd0;
		gfx_din <= 16'd0;
		gfx_be <= 2'b11;
		gfx_rnw <= 1'b0;
		gfx_req <= 1'b0;
		rom_ready <= 1'b0;
		layout_error <= 1'b0;
		accepted_bytes <= 27'd0;
		regions_seen <= 3'd0;
	end
	else begin
		if (gfx_word_pending && (gfx_ack == gfx_req))
			gfx_word_pending <= 1'b0;

		if (downloading && !downloading_d) begin
			completion_pending <= 1'b0;
			gfx_word_pending <= 1'b0;
			rom_ready <= 1'b0;
			layout_error <= 1'b0;
			accepted_bytes <= 27'd0;
			regions_seen <= 3'd0;
		end

		if (ioctl_wr && !ioctl_wait) begin
			accepted_bytes <= accepted_bytes + 27'd1;
			if (stream_program) begin
				regions_seen[0] <= 1'b1;
			end
			else if (stream_graphics) begin
				regions_seen[1] <= 1'b1;
				if (!ioctl_addr[0]) begin
					gfx_upper <= ioctl_data;
					gfx_word_address <= ioctl_addr - PROGRAM_END;
				end
				else begin
					gfx_addr <= gfx_word_address;
					gfx_din <= {gfx_upper, ioctl_data};
					gfx_be <= 2'b11;
					gfx_rnw <= 1'b0;
					gfx_req <= ~gfx_req;
					gfx_word_pending <= 1'b1;
				end
			end
			else if (stream_sample) begin
				regions_seen[2] <= 1'b1;
			end
			else begin
				layout_error <= 1'b1;
			end
		end

		if (downloading_d && !downloading)
			completion_pending <= 1'b1;

		if (completion_pending && ddr_load_idle && !gfx_word_pending) begin
			rom_ready <= !layout_error && (&regions_seen)
				&& (accepted_bytes == IMAGE_END);
			completion_pending <= 1'b0;
		end
	end
end

endmodule
