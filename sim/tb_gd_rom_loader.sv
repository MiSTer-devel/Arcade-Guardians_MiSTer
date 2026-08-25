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
		while (ioctl_wait) @(posedge clk);
		@(negedge clk);
		ioctl_addr = address;
		ioctl_data = data;
		ioctl_wr = 1'b1;
		@(negedge clk);
		ioctl_wr = 1'b0;
	end
endtask

integer i;
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
	#1;
	if (gfx_req === first_req || !ioctl_wait)
		$fatal(1, "graphics block did not enter pending state");
	if (!gfx_burst || gfx_rnw || gfx_be !== 2'b11 || gfx_addr !== 25'd0)
		$fatal(1, "graphics request controls mismatch");
	if (gfx_burst_data !== 64'h0607_0405_0203_0001)
		$fatal(1, "first packed graphics block=%h", gfx_burst_data);
	if (gfx_din !== 16'h0001)
		$fatal(1, "compatibility first word=%h", gfx_din);

	gfx_ack = gfx_req;
	@(posedge clk);
	#1;
	if (ioctl_wait) $fatal(1, "graphics wait did not clear after acknowledge");
	first_req = gfx_req;

	for (i = 8; i < 16; i = i + 1)
		send_graphics_byte(27'h0200000 + i, i[7:0]);
	#1;
	if (gfx_req === first_req || gfx_addr !== 25'd8)
		$fatal(1, "second graphics block address/request mismatch");
	if (gfx_burst_data !== 64'h0e0f_0c0d_0a0b_0809)
		$fatal(1, "second packed graphics block=%h", gfx_burst_data);
	if (accepted_bytes !== 27'd16 || regions_seen !== 3'b010)
		$fatal(1, "loader accounting bytes=%0d regions=%b",
		       accepted_bytes, regions_seen);

	$display("PASS gd_rom_loader packs four graphics words per SDRAM handshake");
	$finish;
end
endmodule
