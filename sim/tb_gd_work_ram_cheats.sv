`timescale 1ns/1ps

module tb_gd_work_ram_cheats;
logic [23:0] address = 0;
logic [15:0] ram_q = 16'h1234;
logic [15:0] cpu_write_data = 16'h5678;
logic [1:0] cpu_write_be = 2'b11;
logic [11:0] cheats = 12'd0;
logic [15:0] cpu_read_data;
logic [15:0] ram_write_data;

gd_work_ram_cheats dut(.*);

task automatic check_word(
	input [23:0] test_address,
	input integer cheat_bit,
	input [15:0] expected
);
	begin
		address = test_address;
		cheats = 12'd0;
		cheats[cheat_bit] = 1'b1;
		cpu_write_be = 2'b11;
		#1;
		if (cpu_read_data !== expected || ram_write_data !== expected)
			$fatal(1, "word clamp address=%h read=%h write=%h expected=%h",
			       address, cpu_read_data, ram_write_data, expected);
	end
endtask

task automatic check_low_byte(
	input [23:0] test_address,
	input integer cheat_bit,
	input [7:0] expected
);
	begin
		address = test_address;
		cheats = 12'd0;
		cheats[cheat_bit] = 1'b1;
		cpu_write_be = 2'b11;
		#1;
		if (cpu_read_data !== {8'h12, expected}
		    || ram_write_data !== {8'h56, expected})
			$fatal(1, "low-byte clamp address=%h read=%h write=%h",
			       address, cpu_read_data, ram_write_data);
	end
endtask

initial begin
	#1;
	if (cpu_read_data !== ram_q || ram_write_data !== cpu_write_data)
		$fatal(1, "disabled cheats changed ordinary work RAM");

	check_low_byte(24'h2014f0, 0, 8'h09);

	address = 24'h201312;
	cheats = 12'd0;
	cheats[1] = 1'b1;
	#1;
	if (cpu_read_data !== 16'h9a34 || ram_write_data !== 16'h9a78)
		$fatal(1, "even-byte time clamp mismatch");

	check_low_byte(24'h201628, 2, 8'h0a);
	check_word(24'h203142, 3, 16'h02c0);
	check_word(24'h203144, 3, 16'h02c0);
	check_word(24'h203146, 4, 16'h02c0);
	check_word(24'h203148, 4, 16'h02c0);
	check_low_byte(24'h20308e, 5, 8'h02);
	check_word(24'h20314e, 6, 16'hffff);
	check_low_byte(24'h2016a8, 7, 8'h04);
	check_word(24'h203342, 8, 16'h02c0);
	check_word(24'h203344, 8, 16'h02c0);
	check_word(24'h203346, 9, 16'h02c0);
	check_word(24'h203348, 9, 16'h02c0);
	check_low_byte(24'h20328e, 10, 8'h02);
	check_word(24'h20334e, 11, 16'hffff);

	// Never alter a disabled lane on a partial write.
	address = 24'h2014f0;
	cheats = 12'b0000_0000_0001;
	cpu_write_data = 16'habcd;
	cpu_write_be = 2'b10;
	#1;
	if (ram_write_data !== 16'habcd)
		$fatal(1, "credit cheat altered a disabled low-byte lane");

	$display("PASS gd_work_ram_cheats all 12 native OSD clamps");
	$finish;
end
endmodule
