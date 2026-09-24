`timescale 1ns/1ps
module tb_gd_dx101_video;
logic clk=0; always #5 clk=~clk;
logic reset=1;
logic sprite_copy_busy=0;
logic ce_pix=0;
logic [8:0] h_count=0;
logic [8:0] v_count=0;
logic hblank=0;
logic vblank=0;
logic raster_active=1;
logic rowscroll_override_valid=0;
logic [14:0] rowscroll_override_record=0;
logic [15:0] rowscroll_override_data=0;
logic [15:0] video_control=0;
logic rotate_180=0;
logic [26:0] video_x_offset=0;
logic [26:0] video_x_zoom=27'h0010000;
logic [26:0] video_y_offset=0;
logic [26:0] video_y_zoom=0;
logic [16:0] sprite_address;
logic [63:0] sprite_q=0;
logic [14:0] palette_address;
logic [15:0] palette_q=0;
logic [24:0] gfx_addr;
logic gfx_req;
logic [24:0] gfx_prefetch_addr;
logic gfx_prefetch_valid;
logic [63:0] gfx_dout=0;
logic gfx_ack=0;
logic [7:0] red,green,blue;
logic busy;
logic line_done;
logic [15:0] missed_lines;
logic [8:0] rowscroll_lookup_line;

gd_dx101_video #(.AHEAD_RENDER(1'b1)) dut(.*);
logic [15:0] sprite_memory [0:131071];
logic gfx_req_d=0;

function automatic [14:0] line_buffer0_at(input integer pixel);
	case (pixel & 7)
		0: line_buffer0_at = dut.line_buffer_bank0[pixel >> 3];
		1: line_buffer0_at = dut.line_buffer_bank1[pixel >> 3];
		2: line_buffer0_at = dut.line_buffer_bank2[pixel >> 3];
		3: line_buffer0_at = dut.line_buffer_bank3[pixel >> 3];
		4: line_buffer0_at = dut.line_buffer_bank4[pixel >> 3];
		5: line_buffer0_at = dut.line_buffer_bank5[pixel >> 3];
		6: line_buffer0_at = dut.line_buffer_bank6[pixel >> 3];
		default: line_buffer0_at = dut.line_buffer_bank7[pixel >> 3];
	endcase
endfunction

function automatic [14:0] line_buffer1_at(input integer pixel);
	case (pixel & 7)
		0: line_buffer1_at = dut.line_buffer_bank0[38 + (pixel >> 3)];
		1: line_buffer1_at = dut.line_buffer_bank1[38 + (pixel >> 3)];
		2: line_buffer1_at = dut.line_buffer_bank2[38 + (pixel >> 3)];
		3: line_buffer1_at = dut.line_buffer_bank3[38 + (pixel >> 3)];
		4: line_buffer1_at = dut.line_buffer_bank4[38 + (pixel >> 3)];
		5: line_buffer1_at = dut.line_buffer_bank5[38 + (pixel >> 3)];
		6: line_buffer1_at = dut.line_buffer_bank6[38 + (pixel >> 3)];
		default: line_buffer1_at = dut.line_buffer_bank7[38 + (pixel >> 3)];
	endcase
endfunction

always_ff @(posedge clk) begin
	sprite_q <= {
		sprite_memory[{sprite_address[16:2], 2'b11}],
		sprite_memory[{sprite_address[16:2], 2'b10}],
		sprite_memory[{sprite_address[16:2], 2'b01}],
		sprite_memory[{sprite_address[16:2], 2'b00}]
	};
	gfx_req_d <= gfx_req;
	gfx_ack <= gfx_req_d;
	// Eight planes encode displayed pixel pens 1 through 8.
	gfx_dout <= 64'h0000_0000_1e01_aa66;
	palette_q <= {1'b0,palette_address};
end

integer i;
integer scheduler_line;
integer scheduler_x;
integer retained_bank;
logic [8:0] retained_line;
integer retained_work_bank;
logic retained_work_valid;
initial begin
	for(i=0;i<131072;i=i+1) sprite_memory[i]=0;
	// The stage-map/loading screen uses inverted -2.0 Y zoom and a phase of
	// three source rows. Physical line 10 must therefore fetch source line 23;
	// normal gameplay's -1.0 setting remains line+128.
	if (dut.global_source_line(9'd10, 27'h7fc0000, 27'h7fe0000)
	    !== 11'd23)
		$fatal(1, "loading-screen Y zoom did not advance two source rows");
	if (dut.global_source_line(9'd10, 27'h77f0000, 27'h7ff0000)
	    !== 11'd138)
		$fatal(1, "unit inverted Y zoom changed gameplay line mapping");
	if (dut.global_source_line(9'd10, 27'd0, 27'h0010000)
	    !== 11'd10)
		$fatal(1, "non-inverted Y mode did not bypass global transform");
	if (!dut.sprite_intersects_line(16'h8000, 16'h0000, 16'h0000,
	        16'h0100, 16'h0000, 16'h0014, 9'd9,
	        27'h7fc0000, 27'h7fe0000)
	    || dut.sprite_intersects_line(16'h8000, 16'h0000, 16'h0000,
	        16'h0100, 16'h0000, 16'h0014, 9'd4,
	        27'h7fc0000, 27'h7fe0000))
		$fatal(1, "active-list filter ignored loading-screen Y zoom");

	// +2.0 X zoom produces a reciprocal half-pixel output step. Adjacent
	// source pixels collapse in pairs, while fixed-position header bit 14
	// keeps the loading-screen frame at native size.
	force dut.tile_screen_x = 12'sd10;
	force dut.flip_x = 1'b0;
	force dut.h0 = 16'h0000;
	video_x_zoom = 27'h0020000;
	#1;
	if ((dut.draw_pixel_x[0] !== 5) || (dut.draw_pixel_x[1] !== 5)
	    || (dut.draw_pixel_x[2] !== 6) || (dut.draw_pixel_x[7] !== 8))
		$fatal(1, "loading-screen X zoom did not shrink source pixels by half");
	force dut.h0 = 16'h4000;
	#1;
	if ((dut.draw_pixel_x[0] !== 10) || (dut.draw_pixel_x[7] !== 17))
		$fatal(1, "fixed-position header was incorrectly globally zoomed");
	video_x_zoom = 27'h0010000;
	release dut.tile_screen_x;
	release dut.flip_x;
	release dut.h0;
	// A recorded raster scroll word replaces only the matching packed
	// descriptor's word 2 before it enters the active scanline list.
	force dut.scan_record_q = 64'h1234_5678_9abc_def0;
	force dut.sprite_pointer = {15'h0010, 2'b00};
	force dut.h3 = 16'h8000;
	force dut.header_index = 9'd3;
	rowscroll_override_valid = 1'b1;
	rowscroll_override_record = 15'h0010;
	rowscroll_override_data = 16'h7bf2;
	#1;
	if (dut.scan_s2 !== 16'h7bf2)
		$fatal(1, "matching rowscroll history did not override descriptor");
	rowscroll_override_record = 15'h0011;
	#1;
	if (dut.scan_s2 !== 16'h5678)
		$fatal(1, "rowscroll history changed a different descriptor");
	// The same record address may be reused by a normal/foreground header.
	// Rowscroll must remain confined to floating background layers.
	rowscroll_override_record = 15'h0010;
	force dut.h3 = 16'h0000;
	#1;
	if (dut.scan_s2 !== 16'h5678)
		$fatal(1, "rowscroll leaked into a foreground layer");
	force dut.h3 = 16'h8000;
	force dut.header_index = 9'd1;
	#1;
	if (dut.scan_s2 !== 16'h7bf2)
		$fatal(1, "rowscroll incorrectly depended on mutable header order");
	// A different floating foreground descriptor must remain rigid even when
	// it occupies the list slot formerly used by the heat background.
	force dut.sprite_pointer = {15'h0011, 2'b00};
	force dut.header_index = 9'd3;
	#1;
	if (dut.scan_s2 !== 16'h5678)
		$fatal(1, "rowscroll leaked into a floating foreground descriptor");
	// Sharing a floating page is not sufficient identity. Stage 1 uses two
	// adjacent chunks on the same page and raster-scrolls only one at a time.
	force dut.scan_record_q = 64'h1234_7a10_9abc_def0;
	#1;
	if (dut.scan_s2 !== 16'h7a10)
		$fatal(1, "rowscroll matched a different record by page alone");
	force dut.scan_record_q = 64'h1234_5678_9abc_def0;
	rowscroll_override_valid = 1'b0;
	release dut.scan_record_q;
	release dut.sprite_pointer;
	release dut.h3;
	release dut.header_index;
	// The heat descriptor must not overwrite an actor pixel beyond X=63. This
	// also catches the former six-bit shift truncation in the occupancy lookup.
	if (dut.physical_draw_address(6'd25, 3'd2) !== 9'd202)
		$fatal(1, "foreground occupancy address aliased X=202");
	if (dut.heat_write_enable(1'b1, 1'b1, 1'b1) !== 1'b0)
		$fatal(1, "heat layer overwrote an occupied foreground pixel");
	if (dut.heat_write_enable(1'b1, 1'b0, 1'b1) !== 1'b1)
		$fatal(1, "ordinary layer was incorrectly blocked by occupancy mask");
	// Raster activity used to collapse the line queue to exactly one row,
	// exposing busy tilemap lines as stale full-scanline repeats through actors.
	// Frozen scroll history permits twelve-line look-ahead during the effect.
	v_count = 9'd10;
	force dut.next_render_line = 9'd22;
	#1;
	if (!dut.lookahead_ready)
		$fatal(1, "raster activity disabled bounded line look-ahead");
	force dut.next_render_line = 9'd23;
	#1;
	if (dut.lookahead_ready)
		$fatal(1, "line reservoir rendered beyond its twelve free banks");
	if (dut.packed_line_address(4'd12, 6'd37) !== 9'd493)
		$fatal(1, "thirteenth packed line bank did not end at address 493");
	release dut.next_render_line;
	// Exact-line display selection needs enough initial lead for a cold row to
	// complete. Check both the normal seed and native-raster wraparound.
	v_count = 9'd10; #1;
	if (dut.recovery_render_line !== 9'd22)
		$fatal(1, "line scheduler did not seed twelve rows ahead");
	v_count = 9'd250; #1;
	if (dut.recovery_render_line !== 9'd4)
		$fatal(1, "twelve-row recovery lead did not wrap at line 258");
	// The output prefetch and line scheduler must wrap at the native
	// 410x258 raster, not the old synthetic 512x256 MAME geometry.
	h_count=9'd408; v_count=9'd257; #1;
	if (dut.prefetch_x !== 9'd0 || dut.physical_next_line !== 9'd0)
		$fatal(1,"native raster wrap prefetch=%0d next=%0d",
			dut.prefetch_x,dut.physical_next_line);
	h_count=9'd409; #1;
	if (dut.prefetch_x !== 9'd1)
		$fatal(1,"native prefetch wrap second pixel=%0d",dut.prefetch_x);
	// Rotation changes only the renderer's source coordinates. The physical
	// 410x258 scheduler and sync raster must remain untouched.
	force dut.target_line = 9'd0;
	rotate_180=1'b1; h_count=9'd0; #1;
	if (dut.logical_target_line !== 9'd231
	    || dut.display_x !== 9'd301
	    || rowscroll_lookup_line !== 9'd231)
		$fatal(1,"180-degree origin mapping line=%0d x=%0d scroll=%0d",
			dut.logical_target_line,dut.display_x,rowscroll_lookup_line);
	h_count=9'd301; #1;
	if (dut.prefetch_x !== 9'd303 || dut.display_x !== 9'd0)
		$fatal(1,"180-degree right-edge mapping prefetch=%0d x=%0d",
			dut.prefetch_x,dut.display_x);
	rotate_180=1'b0; h_count=9'd409;
	release dut.target_line;
	if (!dut.wrapped_span_contains(508,16,-510)
	    || dut.wrapped_span_contains(508,16,-490))
		$fatal(1,"signed 10-bit wrapped span comparison failed");
	// DX-101 vertical displacement wraps at 0x200. This is the multi-header
	// boundary used by the intro pictures and floating backgrounds.
	if (!dut.wrapped_vertical_y_contains(252,16,-252)
	    || dut.wrapped_vertical_y_contains(252,16,-236)
	    || !dut.wrapped_vertical_y_contains(-225,49,287))
		$fatal(1,"signed 9-bit normal-sprite Y comparison failed");
	// Header Y=0x1fa (-6 on the normal-sprite ring) plus local Y=8
	// starts at line 2. A 10-bit interpretation instead places it at -510.
	if (!dut.sprite_intersects_line(16'h8000,16'h0000,16'h01fa,
	        16'h0100,16'h0000,16'h0008,9'd2,27'd0,27'd0)
	    || dut.sprite_intersects_line(16'h8000,16'h0000,16'h01fa,
	        16'h0100,16'h0000,16'h0008,9'd10,27'd0,27'd0))
		$fatal(1,"normal-sprite header Y did not wrap at 0x200");
	// The gameplay background uses 0x1f9 -> 0x039 for consecutive
	// floating-tilemap chunks across the same vertical boundary.
	if (!dut.sprite_intersects_line(16'h0400,16'h0000,16'h0080,
	        16'h8100,16'h5000,16'h0df9,9'd0,
	        27'h77f0000,27'h7ff0000)
	    || dut.sprite_intersects_line(16'h0400,16'h0000,16'h0080,
	        16'h8100,16'h5000,16'h0df9,9'd57,
	        27'h77f0000,27'h7ff0000))
		$fatal(1,"floating background Y did not wrap at 0x200");
	h_count=0; v_count=0;
	// One final list header pointing to one 8x8 normal sprite.
	sprite_memory[17'h01800]=16'h8000;
	sprite_memory[17'h01801]=16'h0000;
	sprite_memory[17'h01802]=16'h0000;
	sprite_memory[17'h01803]=16'h0100;
	sprite_memory[17'h00400]=16'h000a;
	sprite_memory[17'h00401]=16'h0001;
	sprite_memory[17'h00402]=16'h0020;
	sprite_memory[17'h00403]=16'h0000;
	repeat(5) @(posedge clk); reset<=0;
	// Current line 253 wraps the twelve-line recovery target to line 7, which
	// remains inside this fixture's eight-line normal sprite.
	@(posedge clk); ce_pix<=1; h_count<=0; v_count<=253;
	@(posedge clk); ce_pix<=0; h_count<=1;
	wait(busy);
	wait(!busy && dut.state==dut.R_IDLE);
	@(posedge clk);
	for(i=0;i<8;i=i+1)
		if(line_buffer1_at(10+i) !== (15'h0011+i))
			$fatal(1,"pixel %0d=%h",i,line_buffer1_at(10+i));

	// Replace it with a 16-pixel-wide floating tilemap window. A -16
	// scroll value cancels the controller's documented +0x10 origin.
	sprite_memory[17'h01803]=16'h8100;
	sprite_memory[17'h00400]=16'h040a;
	sprite_memory[17'h00401]=16'h0001;
	sprite_memory[17'h00402]=16'h03f0;
	sprite_memory[17'h00403]=16'h0000;
	sprite_memory[17'h00f80]=16'h0040;
	sprite_memory[17'h00f81]=16'h0001;
	sprite_memory[17'h00f82]=16'h0040;
	sprite_memory[17'h00f83]=16'h0001;
	// A real list replacement asserts sprite_buffer_busy into the renderer's
	// reset input. Model that boundary here; otherwise look-ahead has correctly
	// rendered line two before this testbench's artificial live RAM edits.
	reset<=1;
	repeat(3) @(posedge clk);
	reset<=0;
	// Current line 248 wraps the twelve-line recovery target to line 2, keeping
	// this fixture on the same floating-tilemap source row it validates.
	@(posedge clk); ce_pix<=1; h_count<=0; v_count<=248;
	@(posedge clk); ce_pix<=0; h_count<=1;
	wait(busy);
	wait(!busy && dut.state==dut.R_IDLE);
	@(posedge clk);
	for(i=0;i<8;i=i+1)
		if(line_buffer1_at(10+i) !== (15'h0021+i))
			$fatal(1,"floating pixel %0d=%h",i,line_buffer1_at(10+i));

	// Exercise the complete raster scheduler, not just its combinational lead
	// calculation. An invisible one-record list renders quickly enough to fill
	// the twelve-row reservoir during the initial display line. The exact-line
	// selector must acquire line 12 and remain locked thereafter; the previous
	// startup policy stayed permanently behind and repeated one horizontal row
	// over the full screen.
	sprite_memory[17'h00401]=16'h0100;
	reset<=1;
	repeat(3) @(posedge clk);
	reset<=0;
	for (scheduler_line=0; scheduler_line<25;
	     scheduler_line=scheduler_line+1) begin
		for (scheduler_x=0; scheduler_x<410;
		     scheduler_x=scheduler_x+1) begin
			@(negedge clk);
			ce_pix=1'b1;
			h_count=scheduler_x;
			v_count=scheduler_line;
			@(negedge clk);
			ce_pix=1'b0;
			if ((scheduler_x == 0) && (scheduler_line >= 12)) begin
				#1;
				if (!dut.bank_valid[dut.display_bank]
				    || (dut.bank_line[dut.display_bank] != scheduler_line))
					$fatal(1,
						"exact-line scheduler lost lock at raster %0d (bank=%0d tag=%0d valid=%b)",
						scheduler_line, dut.display_bank,
						dut.bank_line[dut.display_bank],
						dut.bank_valid[dut.display_bank]);
			end
			repeat(3) @(negedge clk);
		end
	end
	// A frame-boundary sprite copy must not flush a completed HUD/playfield
	// row. Only the row under construction can be discarded and retried.
	retained_bank = dut.display_bank;
	retained_line = dut.bank_line[retained_bank];
	retained_work_bank = dut.work_bank;
	retained_work_valid = dut.bank_valid[retained_work_bank] && !busy;
	if (!dut.bank_valid[retained_bank])
		$fatal(1, "no completed row available before sprite copy");
	sprite_copy_busy = 1'b1;
	repeat (3) @(posedge clk);
	#1;
	if (!dut.scheduler_started || !dut.bank_valid[retained_bank]
	    || dut.bank_line[retained_bank] != retained_line
	    || (retained_work_valid && !dut.bank_valid[retained_work_bank])
	    || busy || dut.state != dut.R_IDLE)
		$fatal(1, "sprite copy discarded a completed raster row");
	sprite_copy_busy = 1'b0;
	// The packed-list buffer ends before record 0x600. A saturated private
	// header pointer must not make the renderer interpret base headers as
	// descriptor data when the original list overloads that buffer.
	sprite_memory[17'h01803]=16'h8600;
	reset<=1;
	repeat(3) @(posedge clk);
	reset<=0;
	@(posedge clk); ce_pix<=1; h_count<=0; v_count<=248;
	@(posedge clk); ce_pix<=0; h_count<=1;
	wait(busy);
	while(busy) begin
		@(posedge clk);
		if (dut.state == dut.R_SPRITE_WAIT)
			$fatal(1,"invalid packed pointer entered sprite scan");
	end
	$display("PASS gd_dx101_video drew normal and floating-tilemap 8bpp rows");
	$finish;
end
initial begin
	#1000000;
	$display("timeout state=%0d busy=%b float_x=%0d sprite_addr=%h gfx_req=%b gfx_ack=%b target=%0d",
		dut.state, busy, dut.float_x, sprite_address, gfx_req, gfx_ack,
		dut.target_line);
	$fatal(1,"timeout");
end
endmodule
