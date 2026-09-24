`timescale 1ns/1ps

module tb_gd_rom_loader;
logic clk = 1'b0;
logic reset = 1'b1;
logic memory_ready = 1'b1;
logic downloading = 1'b0;
logic ioctl_wr = 1'b0;
logic [26:0] ioctl_addr = 27'd0;
logic [7:0] ioctl_data = 8'd0;
logic ioctl_wait;
logic ddr_load_wr;
logic [25:0] ddr_load_addr;
logic [7:0] ddr_load_data;
logic ddr_load_wait = 1'b0;
logic ddr_load_idle = 1'b1;
logic [24:0] gfx_addr;
logic [15:0] gfx_din;
logic [1:0] gfx_be;
logic gfx_burst;
logic [63:0] gfx_burst_data;
logic gfx_rnw;
logic gfx_req;
logic gfx_ack = 1'b0;
logic rom_ready;
logic layout_error;
logic [26:0] accepted_bytes;
logic [2:0] regions_seen;

always #5 clk = ~clk;
gd_rom_loader dut(.*);

task automatic send_graphics_byte(input [26:0] address, input [7:0] data);
	begin
		@(negedge clk);
		ioctl_addr = address;
		ioctl_data = data;
		while (ioctl_wait) @(negedge clk);
		ioctl_wr = 1'b1;
		@(negedge clk);
		ioctl_wr = 1'b0;
	end
endtask

function automatic [63:0] expected_block(input integer block_number);
	logic [7:0] b;
	begin
		b = block_number * 8;
		expected_block = {8'(b+6), 8'(b+7), 8'(b+4), 8'(b+5),
		                  8'(b+2), 8'(b+3), b, 8'(b+1)};
	end
endfunction

integer i;
integer block_number;
logic first_req;
initial begin
	repeat (3) @(posedge clk);
	reset = 1'b0;
	downloading = 1'b1;
	repeat (2) @(posedge clk);
	first_req = gfx_req;

	for (i = 0; i < 7; i = i + 1) begin
		send_graphics_byte(27'h0200000 + i, i[7:0]);
		if (gfx_req !== first_req)
			$fatal(1, "graphics request issued before eight-byte block");
	end
	send_graphics_byte(27'h0200007, 8'h07);
	@(posedge clk);
	#1;
	if (gfx_req === first_req || ioctl_wait)
		$fatal(1, "first block did not start while host remained ready");
	if (!gfx_burst || gfx_rnw || gfx_be !== 2'b11 || gfx_addr !== 25'd0)
		$fatal(1, "graphics request controls mismatch");
	if (gfx_burst_data !== expected_block(0))
		$fatal(1, "first packed graphics block=%h", gfx_burst_data);
	if (gfx_din !== 16'h0001)
		$fatal(1, "compatibility first word=%h", gfx_din);

	// Keep SDRAM busy for eight more blocks. A queue of eight full blocks
	// must accept all 72 bytes without stalling the HPS transfer.
	for (i = 8; i < 72; i = i + 1) begin
		send_graphics_byte(27'h0200000 + i, i[7:0]);
		if (i[2:0] == 3'd7 && i < 71 && ioctl_wait)
			$fatal(1, "host stalled before the graphics queue filled");
	end
	if (gfx_addr !== 25'd0 || gfx_burst_data !== expected_block(0))
		$fatal(1, "active SDRAM payload changed while later blocks arrived");

	// Even at full capacity, packing the first seven bytes of the next block
	// is safe. The eighth byte must wait until SDRAM frees one queue slot.
	for (i = 72; i < 79; i = i + 1)
		send_graphics_byte(27'h0200000 + i, i[7:0]);
	ioctl_addr = 27'h020004f;
	ioctl_data = 8'd79;
	#1;
	if (!ioctl_wait) $fatal(1, "full queue did not back-pressure block end");
	if (accepted_bytes !== 27'd79)
		$fatal(1, "blocked byte was counted before acceptance");

	@(negedge clk);
	gfx_ack = gfx_req;
	@(posedge clk);
	#1;
	if (ioctl_wait || gfx_addr !== 25'd8
	    || gfx_burst_data !== expected_block(1))
		$fatal(1, "queue did not release and dispatch the second block");
	send_graphics_byte(27'h020004f, 8'd79);
	if (accepted_bytes !== 27'd80 || regions_seen !== 3'b010)
		$fatal(1, "loader accounting bytes=%0d regions=%b",
		       accepted_bytes, regions_seen);

	for (block_number = 1; block_number < 10; block_number = block_number + 1) begin
		if (gfx_addr !== block_number * 8
		    || gfx_burst_data !== expected_block(block_number))
			$fatal(1, "queued block %0d address=%h data=%h",
			       block_number, gfx_addr, gfx_burst_data);
		@(negedge clk);
		gfx_ack = gfx_req;
		@(posedge clk);
		#1;
	end
	if (gfx_req !== gfx_ack || dut.gfx_queue_count !== 0)
		$fatal(1, "graphics queue did not drain after final acknowledge");
	$display("PASS gd_rom_loader streams ahead through queued SDRAM writes");
	$finish;
end
endmodule
