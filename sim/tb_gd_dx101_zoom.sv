`timescale 1ns/1ps
module tb_gd_dx101_zoom;
logic clk=0; always #5 clk=~clk;
logic reset=1;
logic [26:0] x_zoom=27'h0010000;
gd_dx101_video dut(
	.clk(clk), .reset(reset), .ce_pix(1'b0),
	.h_count(9'd0), .v_count(9'd0), .hblank(1'b0), .vblank(1'b0),
	.raster_active(1'b0), .rowscroll_override_valid(1'b0),
	.rowscroll_override_record(15'd0), .rowscroll_override_data(16'd0),
	.rowscroll_seed_valid(1'b0), .rowscroll_seed_data(16'd0),
	.rowscroll_live_valid(1'b0), .rowscroll_live_record(15'd0),
	.rowscroll_live_data(16'd0), .video_control(16'd0), .rotate_180(1'b0),
	.video_x_offset(27'd0), .video_x_zoom(x_zoom),
	.video_y_offset(27'd0), .video_y_zoom(27'd0),
	.sprite_q(64'd0), .sprite_seed_q(16'd0),
	.palette_q(16'd0), .gfx_dout(64'd0), .gfx_ack(1'b0)
);
integer step, y, offset_case, source_x, column, flip;
integer expected, reciprocal;
logic [26:0] offset_value, inverted_step;
logic [26:0] expected_phase;
logic signed [30:0] fixture_base;
logic [16:0] fixture_step;
logic fixture_flip;
initial begin
	// Full 27-bit phase, including fractional carry and wrap at both ends.
	for (step=32; step<=64; step=step+1) begin
		inverted_step = 27'd0 - step * 2048;
		for (offset_case=0; offset_case<4; offset_case=offset_case+1) begin
			case (offset_case)
				0: offset_value=27'h77f0000;
				1: offset_value=27'h7fc0000;
				2: offset_value=27'h7fc8000;
				3: offset_value=27'h000ffff;
			endcase
			for (y=0; y<258; y=y+1) begin
				expected_phase = y * step * 2048 + (27'h7ffffff-offset_value);
				if (dut.global_source_line(y, offset_value, inverted_step)
				    !== expected_phase[26:16])
					$fatal(1,"Y phase mismatch step=%0d row=%0d offset=%h",
						step,y,offset_value);
			end
		end
		if (dut.map_x_reciprocal(step * 2048) !== (2097152 / step))
			$fatal(1,"reciprocal mismatch step=%0d",step);
	end
	// Retain the published unit and exact-half-scale coordinate paths.
	force dut.tile_screen_x = 12'sd10;
	force dut.h0 = 16'h0000;
	force dut.flip_x = 1'b0;
	x_zoom=27'h0010000; #1;
	if (dut.draw_pixel_x[0]!==10 || dut.draw_pixel_x[7]!==17)
		$fatal(1,"unit path changed");
	x_zoom=27'h0020000; #1;
	if (dut.draw_pixel_x[0]!==5 || dut.draw_pixel_x[7]!==8)
		$fatal(1,"half-scale path changed");
	force dut.h0 = 16'h4000; #1;
	if (dut.draw_pixel_x[0]!==10 || dut.draw_pixel_x[7]!==17)
		$fatal(1,"fixed header was scaled");
	force dut.h0 = 16'h0000;
	repeat(2) @(negedge clk);
	reset=0;
	force dut.state = dut.R_GFX_WAIT;
	for (step=33; step<64; step=step+1) begin
		x_zoom=step*2048;
		reciprocal=2097152/step;
		fixture_step=reciprocal;
		force dut.map_x_step=fixture_step;
		for (source_x=-24; source_x<=624; source_x=source_x+8) begin
			fixture_base=source_x*reciprocal;
			force dut.map_tile_base=fixture_base;
			for (flip=0; flip<2; flip=flip+1) begin
				fixture_flip=flip;
				force dut.flip_x=fixture_flip;
				@(posedge clk); #1;
				for (column=0; column<8; column=column+1) begin
					expected=((source_x+(flip ? 7-column : column))*reciprocal) >>> 16;
					if (dut.draw_pixel_x[column]!==expected)
						$fatal(1,"X phase mismatch step=%0d x=%0d flip=%0d col=%0d got=%0d expected=%0d",
							step,source_x,flip,column,dut.draw_pixel_x[column],expected);
				end
				@(negedge clk);
			end
		end
	end
	// A transparent second source pixel must not erase the first opaque
	// pixel when shrinking maps both into the same output position.
	x_zoom=27'h001f800;
	fixture_step=33288; fixture_base=0; fixture_flip=0;
	force dut.map_x_step=fixture_step;
	force dut.map_tile_base=fixture_base;
	force dut.flip_x=fixture_flip;
	force dut.gfx_line=64'h0000_0000_0000_8000;
	force dut.bpp_mode=3'd0;
	force dut.opaque=1'b0;
	force dut.color_code=11'd1;
	@(posedge clk); #1;
	if (!dut.draw_write_enable[0] || dut.draw_write_data[0]!==15'h0011)
		$fatal(1,"collapsed transparent pixel erased opaque source");
	// Cache acknowledgement still goes directly to DRAW in one clock.
	// There must not be a per-tile preparation state slowing the intro.
	force dut.gfx_req=1'b0;
	release dut.state;
	@(posedge clk); #1;
	if (dut.state!==dut.R_GFX_DRAW)
		$fatal(1,"cache-to-draw latency increased");
	$display("PASS DX101 all 33 map steps, fixed headers, transparent collapse, and unchanged tile latency");
	$finish;
end
initial begin
	#1000000;
	$fatal(1,"zoom test timeout");
end
endmodule
