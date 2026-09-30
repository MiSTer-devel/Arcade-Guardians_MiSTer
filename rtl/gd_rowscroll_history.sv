// DX-101 raster rowscroll write history.
//
// Guardians rewrites word 2 of one packed floating-tilemap descriptor at
// every even raster position.  A software renderer can draw completed rows
// immediately, but this FPGA renderer must prepare a row before it is sent to
// the monitor.  Preserve the complete preceding frame of raster writes and
// replay the matching scroll word while that row's descriptor is scanned.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_rowscroll_history
(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_pix,
	input  logic  [8:0] h_count,
	input  logic  [8:0] v_count,
	input  logic        capture_enable,
	input  logic  [8:0] raster_position,
	input  logic        write,
	input  logic [16:0] write_address,
	input  logic [15:0] write_data,
	input  logic  [1:0] write_byte_enable,
	input  logic  [8:0] lookup_line,
	output logic        lookup_valid,
	output logic [14:0] lookup_record,
	output logic [15:0] lookup_data,
	output logic        lookup_seed_valid,
	output logic [15:0] lookup_seed_data,
	output logic        lookup_live_valid,
	output logic [14:0] lookup_live_record,
	output logic [15:0] lookup_live_data
);

// Raster positions are programmed 0, 2, ... 230, and each scroll word is
// held for the corresponding pair of output lines.
(* ramstyle = "MLAB" *) logic [14:0] record_bank0 [0:115];
(* ramstyle = "MLAB" *) logic [14:0] record_bank1 [0:115];
(* ramstyle = "MLAB" *) logic [15:0] data_bank0 [0:115];
(* ramstyle = "MLAB" *) logic [15:0] data_bank1 [0:115];
logic [115:0] valid_bank0;
logic [115:0] valid_bank1;
logic seed_valid_bank0;
logic seed_valid_bank1;
logic [15:0] seed_data_bank0;
logic [15:0] seed_data_bank1;
logic write_bank;
logic read_bank;
logic raster_seen_this_frame;
// Stage 1's two 16x16 fire-background chunks are packed at records 2/3,
// logical page 51 (page 19 plus the tile-size bit). Their IRQ scroll write
// takes effect on the following pair. At IRQ 62 the newly selected record 3
// must not replace its packed seed on rows 62/63; it starts on rows 64/65.
// Indexing the capture at its display phase preserves one read port and
// leaves the intro's page-30 raster replay entirely unchanged.
wire stage1_pair_delay = (write_data[15:10] == 6'd51)
	&& ((write_address[16:2] == 15'd2) || (write_address[16:2] == 15'd3));
wire [6:0] write_index = raster_position[7:1]
	+ (stage1_pair_delay ? 7'd1 : 7'd0);
wire [6:0] read_index = lookup_line[7:1];

// Packed descriptors are four 16-bit words.  Only word 2 is the floating
// tilemap X-scroll/page word changed by Guardians' raster handler.
wire capture_write = capture_enable && write
	// Only the packed display list occupies word addresses below 0x1800.
	// Tilemap RAM also receives word-2 writes during raster mode; recording
	// those as scrolls overwrites both the live word and frozen row history.
	&& (write_address < 17'h01800)
	&& (write_address[1:0] == 2'd2)
	&& (write_byte_enable == 2'b11)
	&& !raster_position[0] && (raster_position < 9'd232);

always_ff @(posedge clk) begin
	if (reset) begin
		valid_bank0 <= 116'd0;
		valid_bank1 <= 116'd0;
		seed_valid_bank0 <= 1'b0;
		seed_valid_bank1 <= 1'b0;
		seed_data_bank0 <= 16'd0;
		seed_data_bank1 <= 16'd0;
		lookup_live_valid <= 1'b0;
		lookup_live_record <= 15'd0;
		lookup_live_data <= 16'd0;
		write_bank <= 1'b0;
		read_bank <= 1'b1;
		raster_seen_this_frame <= 1'b0;
	end
	else begin
		// The handler clears and re-enables the raster IRQ between successive
		// writes. Keep the frozen history readable between those brief pulses;
		// otherwise speculative rows can fall back to a stale packed page.
		if (capture_enable)
			raster_seen_this_frame <= 1'b1;
		if (capture_write) begin
			lookup_live_valid <= 1'b1;
			lookup_live_record <= write_address[16:2];
			lookup_live_data <= write_data;
			if (!write_bank && (write_index < 7'd116)) begin
				record_bank0[write_index] <= write_address[16:2];
				data_bank0[write_index] <= write_data;
				valid_bank0[write_index] <= 1'b1;
				if (write_index == 7'd0) begin
					seed_valid_bank0 <= 1'b1;
					seed_data_bank0 <= write_data;
				end
			end
			else if (write_bank && (write_index < 7'd116)) begin
				record_bank1[write_index] <= write_address[16:2];
				data_bank1[write_index] <= write_data;
				valid_bank1[write_index] <= 1'b1;
				if (write_index == 7'd0) begin
					seed_valid_bank1 <= 1'b1;
					seed_data_bank1 <= write_data;
				end
			end
		end

		// Freeze the just-completed history at the start of vertical blank.
		// The other bank is then collected without racing the video scanner.
		if (ce_pix && (h_count == 9'd0) && (v_count == 9'd232)) begin
			read_bank <= write_bank;
			write_bank <= ~write_bank;
			raster_seen_this_frame <= 1'b0;
			lookup_live_valid <= 1'b0;
			if (write_bank) begin
				valid_bank0 <= 116'd0;
				seed_valid_bank0 <= 1'b0;
			end
			else begin
				valid_bank1 <= 116'd0;
				seed_valid_bank1 <= 1'b0;
			end
		end
	end
end

always_comb begin
	lookup_valid = 1'b0;
	lookup_record = 15'd0;
	lookup_data = 16'd0;
	lookup_seed_valid = 1'b0;
	lookup_seed_data = 16'd0;
	if (!read_bank) begin
		lookup_seed_valid = seed_valid_bank0;
		lookup_seed_data = seed_data_bank0;
	end
	else begin
		lookup_seed_valid = seed_valid_bank1;
		lookup_seed_data = seed_data_bank1;
	end
	if ((capture_enable || raster_seen_this_frame)
	    && (lookup_line < 9'd232)) begin
		if (!read_bank) begin
			lookup_valid = valid_bank0[read_index];
			lookup_record = record_bank0[read_index];
			lookup_data = data_bank0[read_index];
		end
		else begin
			lookup_valid = valid_bank1[read_index];
			lookup_record = record_bank1[read_index];
			lookup_data = data_bank1[read_index];
		end
	end
end

endmodule
