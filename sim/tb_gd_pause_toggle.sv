`timescale 1ns/1ps

module tb_gd_pause_toggle;
	logic clk = 1'b0;
	logic reset = 1'b1;
	logic button = 1'b0;
	logic paused;

	always #5 clk = ~clk;

	gd_pause_toggle dut
	(
		.clk, .reset, .button, .paused
	);

	task automatic tick;
	begin
		@(posedge clk);
		#1;
	end
	endtask

	initial begin
		repeat (2) tick();
		reset = 1'b0;
		tick();
		if (paused) $fatal(1, "pause did not clear on reset");

		button = 1'b1;
		tick();
		if (!paused) $fatal(1, "first press did not pause");
		repeat (5) tick();
		if (!paused) $fatal(1, "held button retriggered pause");

		button = 1'b0;
		tick();
		button = 1'b1;
		tick();
		if (paused) $fatal(1, "second press did not resume");

		button = 1'b0;
		tick();
		reset = 1'b1;
		tick();
		if (paused) $fatal(1, "reset did not clear pause");

		$display("PASS: controller pause toggles once per press");
		$finish;
	end
endmodule
