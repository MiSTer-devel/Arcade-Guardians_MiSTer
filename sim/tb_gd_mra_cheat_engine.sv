`timescale 1ns/1ps

module tb_gd_mra_cheat_engine;
logic clk = 1'b0;
logic reset = 1'b0;
logic enable = 1'b1;
logic [128:0] code = '0;
logic [23:0] addr_in = 24'd0;
logic [15:0] data_in = 16'h1234;
logic [15:0] data_out;
logic available;

always #5 clk = ~clk;

gd_mra_cheat_engine #(.ADDR_WIDTH(24), .MAX_CODES(16)) dut(.*);

task automatic reset_codes;
	begin
		@(negedge clk);
		reset = 1'b1;
		@(negedge clk);
		reset = 1'b0;
		#1;
	end
endtask

task automatic load_code(
	input [31:0] flags,
	input [31:0] address,
	input [31:0] compare,
	input [31:0] replacement
);
	begin
		@(negedge clk);
		code[127:0] = {flags, address, compare, replacement};
		code[128] = 1'b1;
		@(negedge clk);
		code[128] = 1'b0;
		@(negedge clk);
	end
endtask

task automatic check_read(
	input [23:0] address,
	input [15:0] original,
	input [15:0] expected
);
	begin
		addr_in = address;
		data_in = original;
		#1;
		if (data_out !== expected)
			$fatal(1, "address=%h input=%h output=%h expected=%h",
			       address, original, data_out, expected);
	end
endtask

initial begin
	reset_codes();
	if (available) $fatal(1, "empty cheat engine reported codes available");
	check_read(24'h2014f0, 16'h1234, 16'h1234);

	// Exact byte addresses from the MAME definitions must land on the
	// corresponding big-endian 68000 lanes.
	load_code(32'h00000010, 32'h002014f1, 32'd0, 32'h00000009);
	load_code(32'h00000010, 32'h00201312, 32'd0, 32'h0000009a);
	check_read(24'h2014f0, 16'h1234, 16'h1209);
	check_read(24'h201312, 16'h1234, 16'h9a34);

	// A 16-bit code replaces one aligned word.
	load_code(32'h00000020, 32'h00203142, 32'd0, 32'h000002c0);
	check_read(24'h203142, 16'habcd, 16'h02c0);
	check_read(24'h203140, 16'habcd, 16'habcd);

	// A 32-bit code is returned high-word first on the 68000 bus.
	load_code(32'h00000040, 32'h00204000, 32'd0, 32'h11223344);
	check_read(24'h204000, 16'haaaa, 16'h1122);
	check_read(24'h204002, 16'hbbbb, 16'h3344);

	// Compare and Boolean methods follow the standard MRA flags.
	load_code(32'h00000011, 32'h00205001, 32'h00000034, 32'h00000077);
	check_read(24'h205000, 16'h1234, 16'h1277);
	check_read(24'h205000, 16'h1256, 16'h1256);
	load_code(32'h00000110, 32'h00205003, 32'd0, 32'h0000000f);
	check_read(24'h205002, 16'h12f0, 16'h12ff);
	load_code(32'h00000210, 32'h00205002, 32'd0, 32'h0000003f);
	check_read(24'h205002, 16'hf0ff, 16'h30ff);

	enable = 1'b0;
	check_read(24'h2014f0, 16'h1234, 16'h1234);
	enable = 1'b1;
	reset_codes();
	if (available) $fatal(1, "reset did not clear downloaded MRA codes");
	check_read(24'h2014f0, 16'h1234, 16'h1234);

	$display("PASS gd_mra_cheat_engine MRA format and 68000 byte lanes");
	$finish;
end
endmodule
