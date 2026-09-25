// Convert MiSTer's 16-bit file-transfer words to the byte-oriented ROM loader.
// Low byte is first on the HPS little-endian bus. The adapter holds the
// upstream bus until both bytes are accepted, preserving loader back-pressure.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_wide_rom_adapter
(
	input  logic        clk,
	input  logic        reset,
	input  logic        wide_downloading,
	input  logic        wide_wr,
	input  logic [26:0] wide_addr,
	input  logic [15:0] wide_data,
	output logic        wide_wait,
	output logic        byte_downloading,
	output logic        byte_wr,
	output logic [26:0] byte_addr,
	output logic  [7:0] byte_data,
	input  logic        byte_wait
);

logic        pending;
logic        high_byte;
logic [26:0] held_addr;
logic [15:0] held_data;

always_comb begin
	byte_addr = pending ? held_addr + {26'd0, high_byte} : wide_addr;
	byte_data = high_byte ? held_data[15:8] : held_data[7:0];
	byte_wr = pending;
	byte_downloading = wide_downloading || pending;
	wide_wait = pending || byte_wait;
end

always_ff @(posedge clk) begin
	if (reset) begin
		pending <= 1'b0;
		high_byte <= 1'b0;
		held_addr <= 27'd0;
		held_data <= 16'd0;
	end
	else if (pending) begin
		if (!byte_wait) begin
			if (high_byte) begin
				pending <= 1'b0;
				high_byte <= 1'b0;
			end
			else high_byte <= 1'b1;
		end
	end
	else if (wide_wr && !byte_wait) begin
		pending <= 1'b1;
		high_byte <= 1'b0;
		held_addr <= wide_addr;
		held_data <= wide_data;
	end
end

endmodule
