`timescale 1ns/1ps
module tb_gd_dx101_map_draw;
logic clk=0; always #5 clk=~clk;
logic reset=1,ce_pix=0;
logic [8:0] h_count=0,v_count=0;
logic [26:0] x_zoom=27'h0018000;
logic [16:0] sprite_address;
logic [63:0] sprite_q=0;
logic [15:0] ram [0:131071];
logic gfx_req,gfx_req_d=0,gfx_ack=0;
logic line_done,busy;
gd_dx101_video #(.AHEAD_RENDER(1'b1)) dut(
	.clk(clk),.reset(reset),.ce_pix(ce_pix),.h_count(h_count),.v_count(v_count),
	.hblank(1'b0),.vblank(1'b0),.raster_active(1'b0),
	.rowscroll_override_valid(1'b0),.rowscroll_override_record(15'd0),
	.rowscroll_override_data(16'd0),.rowscroll_seed_valid(1'b0),
	.rowscroll_seed_data(16'd0),.rowscroll_live_valid(1'b0),
	.rowscroll_live_record(15'd0),.rowscroll_live_data(16'd0),
	.video_control(16'd0),.rotate_180(1'b0),.video_x_offset(27'd0),
	.video_x_zoom(x_zoom),.video_y_offset(27'h7fc0000),
	.video_y_zoom(27'h7fe8000),.sprite_address(sprite_address),.sprite_q(sprite_q),
	.sprite_seed_q(16'd0),
	.palette_q(16'd0),.gfx_req(gfx_req),.gfx_ack(gfx_ack),
	.gfx_dout(64'h0000_0000_1e01_aa66),.busy(busy),.line_done(line_done)
);
always @(posedge clk) begin
	sprite_q <= {ram[{sprite_address[16:2],2'b11}],ram[{sprite_address[16:2],2'b10}],
		ram[{sprite_address[16:2],2'b01}],ram[{sprite_address[16:2],2'b00}]};
	gfx_req_d<=gfx_req; gfx_ack<=gfx_req_d;
end
function automatic [14:0] pixel_at(input integer x);
	case (x&7)
		0: pixel_at=dut.line_buffer_bank0[38+(x>>3)];
		1: pixel_at=dut.line_buffer_bank1[38+(x>>3)];
		2: pixel_at=dut.line_buffer_bank2[38+(x>>3)];
		3: pixel_at=dut.line_buffer_bank3[38+(x>>3)];
		4: pixel_at=dut.line_buffer_bank4[38+(x>>3)];
		5: pixel_at=dut.line_buffer_bank5[38+(x>>3)];
		6: pixel_at=dut.line_buffer_bank6[38+(x>>3)];
		7: pixel_at=dut.line_buffer_bank7[38+(x>>3)];
	endcase
endfunction
logic [14:0] expected [0:303];
integer i,scale,flip,source_pixel,position,reciprocal;
initial begin
	for(i=0;i<131072;i=i+1) ram[i]=0;
	ram['h1800]='h8000; ram['h1803]='h0100;
	ram['h400]='h0418; ram['h401]=0; ram['h403]=0;
	for(scale=33;scale<64;scale=scale+1) begin
		for(flip=0;flip<2;flip=flip+1) begin
			x_zoom=scale*2048;
			ram['h402]='h0020|(flip<<4);
			for(i=0;i<304;i=i+1) expected[i]=0;
			reciprocal=2097152/scale;
			for(source_pixel=0;source_pixel<16;source_pixel=source_pixel+1) begin
				position=((24+(source_pixel&~7)+(flip ? 7-(source_pixel&7):source_pixel&7))
					*reciprocal) >>> 16;
				expected[position]='h0011+(source_pixel&7);
			end
			@(negedge clk); reset=1; ce_pix=0;
			repeat(3) @(negedge clk);
			reset=0;
			@(negedge clk); ce_pix=1;h_count=0;v_count=248;
			@(negedge clk); ce_pix=0;h_count=1;
			wait(busy); wait(line_done);
			@(negedge clk);
			if (dut.zoomed_target_line!==11'd6 || dut.tile_line!==3'd6)
				$fatal(1,"fractional Y source did not reach tile fetch");
			for(i=0;i<304;i=i+1) if(pixel_at(i)!==expected[i])
				$fatal(1,"map tile draw mismatch scale=%0d flip=%0d x=%0d got=%h expected=%h",
					scale,flip,i,pixel_at(i),expected[i]);
		end
	end
	$display("PASS complete fractional-map tile draws: 31 scales, both flips, consecutive tiles");
	$finish;
end
initial begin #5000000; $fatal(1,"map draw test timeout"); end
endmodule
