// MiSTer MRA cheat-code engine for a 16-bit big-endian CPU bus.
//
// The 16-byte code format and storage model are adapted from Martin Donlon's
// GPL-2.0-or-later Irem M92 cheatengine_32_16, itself based on cheat-code
// handling by Kitrinx. Guardians' TMP68301/68000 data bus is big-endian, so
// byte and long-word lane placement differs from the little-endian M92 core.
//
// Code layout:
//   [127:96] flags, [95:64] address, [63:32] compare, [31:0] replacement
//   flags[0]     compare enable
//   flags[6:4]   width in bytes (1, 2, or 4)
//   flags[9:8]   method (0 replace, 1 OR, 2 AND)
//
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_mra_cheat_engine #(
	parameter integer ADDR_WIDTH = 24,
	parameter integer MAX_CODES = 32
)(
	input  logic                  clk,
	input  logic                  reset,
	input  logic                  enable,
	input  logic          [128:0] code,
	output logic                  available,
	input  logic [ADDR_WIDTH-1:0] addr_in,
	input  logic           [15:0] data_in,
	output logic           [15:0] data_out
);

logic [1:0] methods [0:MAX_CODES-1];
logic [3:0] value_masks [0:MAX_CODES-1];
logic [31:0] compare_masks [0:MAX_CODES-1];
logic [31:0] values [0:MAX_CODES-1];
logic [31:0] compares [0:MAX_CODES-1];
logic [ADDR_WIDTH-1:0] addresses [0:MAX_CODES-1];

wire [ADDR_WIDTH-1:0] code_addr = code[64 +: ADDR_WIDTH];
wire [31:0] code_compare = code[32 +: 32];
wire [31:0] code_data = code[0 +: 32];
wire code_compare_enable = code[96];
wire [2:0] code_width = code[102:100];
wire [1:0] code_method = code[105:104];

localparam integer INDEX_WIDTH = $clog2(MAX_CODES);
logic [INDEX_WIDTH:0] next_index = '0;
logic code_clock_d = 1'b0;
integer reset_index;

always_comb available = |next_index;

always_ff @(posedge clk) begin : load_codes
	logic [3:0] mask;
	logic [31:0] value;
	logic [31:0] compare;

	if (reset) begin
		next_index <= '0;
		code_clock_d <= 1'b0;
		for (reset_index = 0; reset_index < MAX_CODES;
		     reset_index = reset_index + 1)
			value_masks[reset_index] <= 4'd0;
	end
	else begin
		code_clock_d <= code[128];
		if (code[128] && !code_clock_d && (next_index < MAX_CODES)) begin
			mask = 4'd0;
			value = 32'd0;
			compare = 32'd0;

			// addr_in is a byte address aligned to the current 16-bit CPU
			// transfer. Pack the two words in a four-byte group so byte zero
			// occupies the high data lane, as required by the 68000.
			case ({code_addr[1:0], code_width})
				5'b00_001: begin
					mask = 4'b0010;
					value = {16'd0, code_data[7:0], 8'd0};
					compare = {16'd0, code_compare[7:0], 8'd0};
				end
				5'b01_001: begin
					mask = 4'b0001;
					value = {24'd0, code_data[7:0]};
					compare = {24'd0, code_compare[7:0]};
				end
				5'b10_001: begin
					mask = 4'b1000;
					value = {code_data[7:0], 24'd0};
					compare = {code_compare[7:0], 24'd0};
				end
				5'b11_001: begin
					mask = 4'b0100;
					value = {8'd0, code_data[7:0], 16'd0};
					compare = {8'd0, code_compare[7:0], 16'd0};
				end
				5'b00_010: begin
					mask = 4'b0011;
					value = {16'd0, code_data[15:0]};
					compare = {16'd0, code_compare[15:0]};
				end
				5'b10_010: begin
					mask = 4'b1100;
					value = {code_data[15:0], 16'd0};
					compare = {code_compare[15:0], 16'd0};
				end
				5'b00_100: begin
					mask = 4'b1111;
					value = {code_data[15:0], code_data[31:16]};
					compare = {code_compare[15:0], code_compare[31:16]};
				end
				default: begin end
			endcase

			value_masks[next_index[INDEX_WIDTH-1:0]] <= mask;
			compare_masks[next_index[INDEX_WIDTH-1:0]] <=
				code_compare_enable
				? {{8{mask[3]}}, {8{mask[2]}}, {8{mask[1]}}, {8{mask[0]}}}
				: 32'd0;
			addresses[next_index[INDEX_WIDTH-1:0]] <= code_addr;
			values[next_index[INDEX_WIDTH-1:0]] <= value;
			compares[next_index[INDEX_WIDTH-1:0]] <= compare;
			methods[next_index[INDEX_WIDTH-1:0]] <= code_method;
			next_index <= next_index + 1'b1;
		end
	end
end

// Evaluate every code in parallel. A priority loop here creates a chain tens
// of levels deep and cannot meet the core's 68.75-MHz clock. MRA definitions
// must not assign conflicting values to the same byte; non-conflicting codes
// targeting different lanes of one word merge naturally.
wire [31:0] working_input = addr_in[1]
	? {data_in, 16'd0} : {16'd0, data_in};
wire [(MAX_CODES*4)-1:0] lane_matches;
wire [(MAX_CODES*4*8)-1:0] lane_results;

genvar code_slot;
genvar lane;
generate
	for (code_slot = 0; code_slot < MAX_CODES;
	     code_slot = code_slot + 1) begin : parallel_code
		wire [31:0] compare_difference =
			(compares[code_slot] ^ working_input)
			& compare_masks[code_slot];
		wire entry_match = enable
			&& (addresses[code_slot][ADDR_WIDTH-1:2]
				== addr_in[ADDR_WIDTH-1:2])
			&& (~|compare_difference);

		for (lane = 0; lane < 4; lane = lane + 1) begin : parallel_lane
			wire [7:0] source_byte = working_input[lane*8 +: 8];
			wire [7:0] code_byte = values[code_slot][lane*8 +: 8];
			wire [7:0] result_byte = (methods[code_slot] == 2'd1)
				? (source_byte | code_byte)
				: (methods[code_slot] == 2'd2)
					? (source_byte & code_byte) : code_byte;
			assign lane_matches[(code_slot*4)+lane] =
				entry_match && value_masks[code_slot][lane];
			assign lane_results[((code_slot*4+lane)*8) +: 8] = result_byte;
		end
	end
endgenerate

wire [MAX_CODES-1:0] lane_selects [0:3];
wire [MAX_CODES-1:0] result_bits [0:31];
wire [3:0] matched_lanes;
wire [31:0] merged_result;

genvar merge_lane;
genvar merge_slot;
genvar merge_bit;
generate
	for (merge_lane = 0; merge_lane < 4;
	     merge_lane = merge_lane + 1) begin : merge_lane_select
		for (merge_slot = 0; merge_slot < MAX_CODES;
		     merge_slot = merge_slot + 1) begin : collect_lane_select
			assign lane_selects[merge_lane][merge_slot] =
				lane_matches[(merge_slot*4)+merge_lane];
		end
		assign matched_lanes[merge_lane] = |lane_selects[merge_lane];
	end

	for (merge_bit = 0; merge_bit < 32;
	     merge_bit = merge_bit + 1) begin : merge_result_bit
		for (merge_slot = 0; merge_slot < MAX_CODES;
		     merge_slot = merge_slot + 1) begin : collect_result_bit
			assign result_bits[merge_bit][merge_slot] =
				lane_matches[(merge_slot*4)+(merge_bit/8)]
				&& lane_results[((merge_slot*4+(merge_bit/8))*8)
					+ (merge_bit%8)];
		end
		assign merged_result[merge_bit] = |result_bits[merge_bit];
	end
endgenerate

wire [31:0] working_output = {
	matched_lanes[3] ? merged_result[31:24] : working_input[31:24],
	matched_lanes[2] ? merged_result[23:16] : working_input[23:16],
	matched_lanes[1] ? merged_result[15:8]  : working_input[15:8],
	matched_lanes[0] ? merged_result[7:0]   : working_input[7:0]
};

always_comb data_out = addr_in[1]
	? working_output[31:16] : working_output[15:0];

endmodule
