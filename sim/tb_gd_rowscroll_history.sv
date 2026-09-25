`timescale 1ns/1ps

module tb_gd_rowscroll_history;
logic clk=0; always #5 clk=~clk;
logic reset=1;
logic ce_pix=0;
logic [8:0] h_count=0;
logic [8:0] v_count=0;
logic capture_enable=1;
logic [8:0] raster_position=0;
logic write=0;
logic [16:0] write_address=0;
logic [15:0] write_data=0;
logic [1:0] write_byte_enable=2'b11;
logic [8:0] lookup_line=0;
logic lookup_valid;
logic [14:0] lookup_record;
logic [15:0] lookup_data;
logic lookup_seed_valid;
logic [15:0] lookup_seed_data;
logic lookup_live_valid;
logic [14:0] lookup_live_record;
logic [15:0] lookup_live_data;

gd_rowscroll_history dut(.*);

task automatic capture(input integer line, input integer address,
	input integer data);
begin
	@(negedge clk);
	raster_position=line;
	write_address=address;
	write_data=data;
	write=1;
	@(negedge clk);
	write=0;
end
endtask

task automatic swap_frame;
begin
	@(negedge clk);
	v_count=232; h_count=0; ce_pix=1;
	@(negedge clk);
	ce_pix=0;
end
endtask

initial begin
	repeat(2) @(negedge clk);
	reset=0;

	// The second line-zero handler replaces the transient first value.
	capture(0, 17'h00042, 16'h7bf2);
	capture(0, 17'h00042, 16'h7bef);
	capture(2, 17'h00042, 16'h7bf9);
	capture(64,17'h0004a, 16'h7b87);
	// A tilemap write at the same raster phase must not replace the packed
	// descriptor's latest word or create a false frozen row entry.
	capture(66,17'h0204e, 16'h6000);
	if (!lookup_live_valid || lookup_live_record != 15'h0012
	    || lookup_live_data != 16'h7b87)
		$fatal(1, "tilemap write displaced the live packed-list scroll");
	swap_frame();
	if (lookup_live_valid)
		$fatal(1, "live raster word survived its frame boundary");

	lookup_line=0; #1;
	if (!lookup_valid || lookup_record != 15'h0010
	    || lookup_data != 16'h7bef)
		$fatal(1, "line zero did not replay the final same-line write");
	if (!lookup_seed_valid || lookup_seed_data != 16'h7bef)
		$fatal(1, "first fire-word seed was not frozen");
	lookup_line=1; #1;
	if (!lookup_valid || lookup_data != 16'h7bef)
		$fatal(1, "odd line did not hold its preceding even-line value");
	lookup_line=2; #1;
	if (!lookup_valid || lookup_data != 16'h7bf9)
		$fatal(1, "line two replay mismatch");
	lookup_line=64; #1;
	if (!lookup_valid || lookup_record != 15'h0012
	    || lookup_data != 16'h7b87)
		$fatal(1, "descriptor-address transition was not preserved");
	lookup_line=66; #1;
	if (lookup_valid)
		$fatal(1, "tilemap write leaked into frozen scroll history");
	// The game briefly clears raster enable between writes. A low enable
	// within an active frame must not hide the frozen preceding-frame trace.
	@(negedge clk);
	capture_enable=0;
	lookup_line=0; #1;
	if (!lookup_valid || lookup_data != 16'h7bef)
		$fatal(1, "momentary raster-disable hid prior-frame history");
	capture_enable=1;

	// Writes collected for the next frame must not race the frozen read bank.
	capture(0, 17'h00042, 16'h7805);
	lookup_line=0; #1;
	if (lookup_data != 16'h7bef)
		$fatal(1, "current-frame capture modified frozen history");
	swap_frame();
	lookup_line=0; #1;
	if (!lookup_valid || lookup_data != 16'h7805)
		$fatal(1, "new history was not published at frame boundary");
	if (!lookup_seed_valid || lookup_seed_data != 16'h7805)
		$fatal(1, "new fire-word seed was not published");
	lookup_line=2; #1;
	if (lookup_valid)
		$fatal(1, "stale validity survived bank reuse");

	// Non-scroll banks and partial words are deliberately ignored.
	capture(4, 17'h00043, 16'h1111);
	write_byte_enable=2'b01;
	capture(6, 17'h00042, 16'h2222);
	write_byte_enable=2'b11;
	swap_frame();
	lookup_line=4; #1;
	if (lookup_valid) $fatal(1, "non-scroll word was captured");
	if (lookup_seed_valid) $fatal(1, "stale fire-word seed survived bank reuse");
	lookup_line=6; #1;
	if (lookup_valid) $fatal(1, "partial scroll word was captured");

	capture_enable=0;
	swap_frame();
	if (dut.raster_seen_this_frame)
		$fatal(1, "raster activity latch survived the frame boundary");
	lookup_line=0; #1;
	if (lookup_valid) $fatal(1, "disabled raster history remained active");

	$display("gd_rowscroll_history: PASS");
	$finish;
end
endmodule
