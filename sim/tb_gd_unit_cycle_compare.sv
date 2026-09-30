// Compile the comparison side with an unchanged GitHub-head renderer,
// renamed gd_dx101_video_reference. No ROMs or MAME-rendered pixels required.
`timescale 1ns/1ps
module tb_gd_unit_cycle_compare;
logic clk=0; always #5 clk=~clk;
logic reset=1, ce_pix=0;
logic [8:0] h_count=0,v_count=0;
logic [16:0] address_a,address_b;
logic [63:0] sprite_q=0;
logic [14:0] palette_a,palette_b;
logic [15:0] palette_q=0;
logic [24:0] gfx_a,gfx_b;
logic req_a,req_b,ack=0,req_d=0;
logic [7:0] red_a,green_a,blue_a,red_b,green_b,blue_b;
logic busy_a,busy_b,done_a,done_b;
logic [15:0] missed_a,missed_b;
logic [8:0] lookup_a,lookup_b;
logic [15:0] ram [0:131071];
gd_dx101_video #(.AHEAD_RENDER(1'b1)) candidate(
	.clk(clk),.reset(reset),.ce_pix(ce_pix),.h_count(h_count),.v_count(v_count),
	.hblank(h_count>=304),.vblank(v_count>=232),.raster_active(1'b0),
	.rowscroll_override_valid(1'b0),.rowscroll_override_record(15'd0),
	.rowscroll_override_data(16'd0),.rowscroll_seed_valid(1'b0),
	.rowscroll_seed_data(16'd0),.rowscroll_live_valid(1'b0),
	.rowscroll_live_record(15'd0),.rowscroll_live_data(16'd0),
	.video_control(16'd0),.rotate_180(1'b0),.video_x_offset(27'h0080000),
	.video_x_zoom(27'h0010000),.video_y_offset(27'h77f0000),
	.video_y_zoom(27'h7ff0000),.sprite_address(address_a),.sprite_q(sprite_q),
	.sprite_seed_q(16'd0),
	.palette_address(palette_a),.palette_q(palette_q),.gfx_addr(gfx_a),
	.gfx_req(req_a),.gfx_dout(64'h0000_0000_1e01_aa66),.gfx_ack(ack),
	.red(red_a),.green(green_a),.blue(blue_a),.busy(busy_a),.line_done(done_a),
	.missed_lines(missed_a),.rowscroll_lookup_line(lookup_a)
);
gd_dx101_video_reference #(.AHEAD_RENDER(1'b1)) baseline(
	.clk(clk),.reset(reset),.ce_pix(ce_pix),.h_count(h_count),.v_count(v_count),
	.hblank(h_count>=304),.vblank(v_count>=232),.raster_active(1'b0),
	.rowscroll_override_valid(1'b0),.rowscroll_override_record(15'd0),
	.rowscroll_override_data(16'd0),.rowscroll_seed_valid(1'b0),
	.rowscroll_seed_data(16'd0),.rowscroll_live_valid(1'b0),
	.rowscroll_live_record(15'd0),.rowscroll_live_data(16'd0),
	.video_control(16'd0),.rotate_180(1'b0),.video_x_offset(27'h0080000),
	.video_x_zoom(27'h0010000),.video_y_offset(27'h77f0000),
	.video_y_zoom(27'h7ff0000),.sprite_address(address_b),.sprite_q(sprite_q),
	.palette_address(palette_b),.palette_q(palette_q),.gfx_addr(gfx_b),
	.gfx_req(req_b),.gfx_dout(64'h0000_0000_1e01_aa66),.gfx_ack(ack),
	.red(red_b),.green(green_b),.blue(blue_b),.busy(busy_b),.line_done(done_b),
	.missed_lines(missed_b),.rowscroll_lookup_line(lookup_b)
);
always @(posedge clk) begin
	sprite_q <= {ram[{address_a[16:2],2'b11}],ram[{address_a[16:2],2'b10}],
		ram[{address_a[16:2],2'b01}],ram[{address_a[16:2],2'b00}]};
	palette_q <= {1'b0,palette_a};
	req_d<=req_a; ack<=req_d;
end
integer checked_cycles=0,completed_lines=0,lane;
always @(negedge clk) if (!reset) begin
	checked_cycles=checked_cycles+1;
	if ({address_a,palette_a,gfx_a,req_a,busy_a,done_a,missed_a,lookup_a}
	    !== {address_b,palette_b,gfx_b,req_b,busy_b,done_b,missed_b,lookup_b})
		$fatal(1,"unit-mode timing diverged at cycle %0d states %0d/%0d",
			checked_cycles,candidate.state,baseline.state);
	if ({red_a,green_a,blue_a} !== {red_b,green_b,blue_b})
		$fatal(1,"unit-mode output diverged at cycle %0d",checked_cycles);
	if (candidate.line_write_enable !== baseline.line_write_enable)
		$fatal(1,"unit-mode write enable diverged");
	for (lane=0;lane<8;lane=lane+1) if (candidate.line_write_enable[lane])
		if ({candidate.line_write_row[lane],candidate.line_write_data[lane]}
		    !== {baseline.line_write_row[lane],baseline.line_write_data[lane]})
			$fatal(1,"unit-mode pixel write diverged lane=%0d",lane);
	if (done_a) completed_lines=completed_lines+1;
end
integer i,header,record,child,row,x;
initial begin
	for(i=0;i<131072;i=i+1) ram[i]=0;
	for(header=0;header<44;header=header+1) begin
		ram['h1800+header*4] = ((header==43) ? 'h8000:0)
			| ((header%8)<<8) | ((header%3==0) ? 'h2000:0)
			| ((header%5==0) ? 'h4000:0) | 3;
		ram['h1801+header*4]='h80;
		ram['h1802+header*4]='h80;
		ram['h1803+header*4]=((header<4) ? 'h8000:0)+header*4;
		for(child=0;child<4;child=child+1) begin
			record=header*4+child;
			if (header<4) begin
				ram[record*4]='h5000;
				ram[record*4+1]='hc00+child*64;
				ram[record*4+2]=((18+header)<<10)+'h3f0;
				ram[record*4+3]=0;
			end else begin
				ram[record*4]='h800+(header*27+child*11)%304;
				ram[record*4+1]='hc00+(header%8)*24;
				ram[record*4+2]=(header<<5)|((child&1)<<4)|((child&2)<<2);
				ram[record*4+3]=record;
			end
		end
	end
	for(i='h12000;i<'h16000;i=i+2) begin
		ram[i]='h20;ram[i+1]=1;
	end
	repeat(3) @(negedge clk);
	reset=0;
	for(row=0;row<40;row=row+1) begin
		for(x=0;x<410;x=x+1) begin
			@(posedge clk); #1;
			ce_pix=1;h_count=x;v_count=row;
			@(posedge clk); #1;
			ce_pix=0;
			repeat(9) @(posedge clk);
		end
	end
	if (completed_lines<20) $fatal(1,"comparison did not render enough rows");
	$display("PASS unit mode matches GitHub head cycle-for-cycle: %0d clocks, %0d completed rows",
		checked_cycles,completed_lines);
	$finish;
end
initial begin #5000000; $fatal(1,"unit comparison timeout"); end
endmodule
