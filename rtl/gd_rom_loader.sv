// Direct MRA-stream loader for the 35 MiB Guardians ROM image.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_rom_loader #(
	parameter integer GFX_QUEUE_DEPTH = 8
)
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
	output logic        gfx_burst,
	output logic [63:0] gfx_burst_data,
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
logic [24:0] gfx_block_address;
logic [55:0] gfx_pack_data;

// MiSTer transfers a byte at a time, while SDRAM commits eight bytes per
// request. Queue complete blocks so the HPS does not pause for every SDRAM
// ACTIVE/WRITE/precharge sequence. The active bus payload is separate from
// the packer and remains stable until the SDRAM acknowledge arrives.
localparam integer GFX_QUEUE_BITS = $clog2(GFX_QUEUE_DEPTH);
logic [24:0] gfx_queue_addr [0:GFX_QUEUE_DEPTH-1];
logic [63:0] gfx_queue_data [0:GFX_QUEUE_DEPTH-1];
logic [GFX_QUEUE_BITS-1:0] gfx_queue_write;
logic [GFX_QUEUE_BITS-1:0] gfx_queue_read;
logic [GFX_QUEUE_BITS:0] gfx_queue_count;

wire stream_program = (ioctl_addr < PROGRAM_END);
wire stream_graphics = (ioctl_addr >= PROGRAM_END)
	&& (ioctl_addr < GRAPHICS_END);
wire stream_sample = (ioctl_addr >= GRAPHICS_END)
	&& (ioctl_addr < IMAGE_END);

// A full queue only pauses the final byte of a graphics block. The first
// seven bytes can still be packed while the oldest queued block is written.
// Program and sample bytes use the existing packed MiSTer DDR transport.
assign ioctl_wait = !memory_ready
	|| (stream_graphics
		? ((gfx_queue_count == GFX_QUEUE_DEPTH)
		   && (ioctl_addr[2:0] == 3'd7))
		: ddr_load_wait);

wire gfx_enqueue = ioctl_wr && !ioctl_wait && stream_graphics
	&& (ioctl_addr[2:0] == 3'd7);
wire gfx_dequeue = (gfx_queue_count != 0) && (gfx_req == gfx_ack)
	&& !(downloading && !downloading_d);

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
		gfx_block_address <= 25'd0;
		gfx_pack_data <= 56'd0;
		gfx_queue_write <= '0;
		gfx_queue_read <= '0;
		gfx_queue_count <= '0;
		gfx_addr <= 25'd0;
		gfx_din <= 16'd0;
		gfx_be <= 2'b11;
		gfx_burst <= 1'b0;
		gfx_burst_data <= 64'd0;
		gfx_rnw <= 1'b0;
		gfx_req <= 1'b0;
		rom_ready <= 1'b0;
		layout_error <= 1'b0;
		accepted_bytes <= 27'd0;
		regions_seen <= 3'd0;
	end
	else begin
		if (downloading && !downloading_d) begin
			completion_pending <= 1'b0;
			gfx_queue_write <= '0;
			gfx_queue_read <= '0;
			gfx_queue_count <= '0;
			rom_ready <= 1'b0;
			layout_error <= 1'b0;
			accepted_bytes <= 27'd0;
			regions_seen <= 3'd0;
		end
		else begin
			if (gfx_enqueue) gfx_queue_write <= gfx_queue_write + 1'b1;
			if (gfx_dequeue) gfx_queue_read <= gfx_queue_read + 1'b1;
			case ({gfx_enqueue, gfx_dequeue})
				2'b10: gfx_queue_count <= gfx_queue_count + 1'b1;
				2'b01: gfx_queue_count <= gfx_queue_count - 1'b1;
				default: ;
			endcase
		end

		if (gfx_dequeue) begin
			gfx_addr <= gfx_queue_addr[gfx_queue_read];
			gfx_burst_data <= gfx_queue_data[gfx_queue_read];
			gfx_be <= 2'b11;
			gfx_burst <= 1'b1;
			gfx_rnw <= 1'b0;
			gfx_req <= ~gfx_req;
		end

		if (ioctl_wr && !ioctl_wait) begin
			accepted_bytes <= accepted_bytes + 27'd1;
			if (stream_program) begin
				regions_seen[0] <= 1'b1;
			end
			else if (stream_graphics) begin
				regions_seen[1] <= 1'b1;
				case (ioctl_addr[2:0])
					3'd0: begin
						gfx_block_address <= ioctl_addr - PROGRAM_END;
						gfx_pack_data[15:8] <= ioctl_data;
					end
					3'd1: begin
						gfx_pack_data[7:0] <= ioctl_data;
						gfx_din <= {gfx_pack_data[15:8], ioctl_data};
					end
					3'd2: gfx_pack_data[31:24] <= ioctl_data;
					3'd3: gfx_pack_data[23:16] <= ioctl_data;
					3'd4: gfx_pack_data[47:40] <= ioctl_data;
					3'd5: gfx_pack_data[39:32] <= ioctl_data;
					3'd6: gfx_pack_data[55:48] <= ioctl_data;
					default: begin
						gfx_queue_addr[gfx_queue_write] <= gfx_block_address;
						gfx_queue_data[gfx_queue_write]
							<= {gfx_pack_data[55:48], ioctl_data,
							    gfx_pack_data[47:0]};
					end
				endcase
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

		if (completion_pending && ddr_load_idle
		    && (gfx_queue_count == 0) && (gfx_req == gfx_ack)) begin
			rom_ready <= !layout_error && (&regions_seen)
				&& (accepted_bytes == IMAGE_END);
			completion_pending <= 1'b0;
		end
	end
end

endmodule
