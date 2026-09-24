`timescale 1ns/1ps

module tb_gd_cpu_ram_scrub;
logic clk = 1'b0;
logic reset = 1'b1;
always #5 clk = ~clk;

gd_cpu_subsystem dut(
	.clk, .reset, .pause(1'b0), .vblank(1'b0),
	.raster_irq(1'b0), .dip_switches(16'hffff),
	.joystick_p1(32'd0), .joystick_p2(32'd0),
	.service(1'b0), .turbo(1'b0),
	.cheat_reset(1'b1), .cheat_code(129'd0),
	.rom_dout(16'h4e71), .rom_ack(1'b0),
	.ram_dout(16'd0), .ram_ack(1'b0),
	.sprite_video_address(17'd0),
	.palette_video_address(15'd0),
	.video_reg_address(5'd0),
	.x1_q(16'd0)
);

task automatic verify_scrub;
	begin
		// Exactly 32K + 24K words must be written before the 68000 runs.
		repeat (57343) @(posedge clk);
		#1;
		if (!dut.scrub_active || !dut.system_reset)
			$fatal(1, "CPU released before the final RAM word");
		@(posedge clk);
		#1;
		if (dut.scrub_active || dut.system_reset
		    || dut.work_ram.memory[0] !== 16'd0
		    || dut.work_ram.memory[32767] !== 16'd0
		    || dut.aux_ram.memory[0] !== 16'd0
		    || dut.aux_ram.memory[24575] !== 16'd0)
			$fatal(1, "RAM scrub left data behind or held the CPU");
	end
endtask

initial begin
	dut.work_ram.memory[0] = 16'hffff;
	dut.work_ram.memory[32767] = 16'hffff;
	dut.aux_ram.memory[0] = 16'hffff;
	dut.aux_ram.memory[24575] = 16'hffff;
	repeat (3) @(negedge clk);
	reset = 1'b0;
	verify_scrub();

	// A warm reset must clear game-written RAM just as cold boot does.
	dut.work_ram.memory[0] = 16'h1234;
	dut.work_ram.memory[32767] = 16'h5678;
	dut.aux_ram.memory[0] = 16'h9abc;
	dut.aux_ram.memory[24575] = 16'hdef0;
	reset = 1'b1;
	repeat (3) @(negedge clk);
	reset = 1'b0;
	verify_scrub();
	$display("PASS gd_cpu_subsystem scrubs work/aux RAM on cold and warm reset");
	$finish;
end

initial begin
	#1200000;
	$fatal(1, "RAM scrub timed out");
end
endmodule
