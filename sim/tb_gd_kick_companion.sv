// Native-trace regression, with synthetic ROM rows (no copyrighted ROM data).
// Exercise actual DMA seeds, synchronous descriptor scan and completed pixels.
`timescale 1ns/1ps
module tb_gd_kick_companion #(parameter bit USE_BUFFERED_SEED=1'b1);
logic clk=0; always #5 clk=~clk;
logic ram_reset=1, reset=1, buffer_trigger=0, write=0, ce_pix=0;
logic [16:0] address=0, sprite_address;
logic [15:0] data=0, cpu_q, sprite_seed_q;
logic [63:0] sprite_q, gfx_dout=0;
logic buffer_busy, gfx_req, gfx_req_d=0, gfx_ack=0, busy, line_done;
logic [24:0] gfx_addr;
logic [8:0] h_count=0,v_count=0;
integer bank,index,chunk,tile,physical_row,reference_cycles,render_cycles;

gd_sprite_ram memory(
	.clk,.reset(ram_reset),.buffer_trigger,.address,.data,
	.byte_enable(2'b11),.write,.q(cpu_q),.video_clk(clk),
	.video_address(sprite_address),.video_q(sprite_q),.video_seed_q(sprite_seed_q),
	.buffer_busy
);
gd_dx101_video #(.AHEAD_RENDER(1'b1)) video(
	.clk,.reset,.ce_pix,.h_count,.v_count,.hblank(1'b0),.vblank(1'b0),
	.raster_active(1'b0),.rowscroll_override_valid(1'b0),
	.rowscroll_override_record(15'd0),.rowscroll_override_data(16'd0),
	.rowscroll_seed_valid(1'b0),.rowscroll_seed_data(16'd0),
	.rowscroll_live_valid(1'b0),.rowscroll_live_record(15'd0),
	.rowscroll_live_data(16'd0),.video_control(16'd0),.rotate_180(1'b0),
	.video_x_offset(27'h0800000),.video_x_zoom(27'h0010000),
	.video_y_offset(27'h77f0000),.video_y_zoom(27'h7ff0000),
	.sprite_address,.sprite_q,
	.sprite_seed_q(USE_BUFFERED_SEED ? sprite_seed_q : 16'd0),.palette_q(16'd0),
	.gfx_addr,.gfx_req,.gfx_dout,.gfx_ack,.busy,.line_done
);
always @(posedge clk) begin
	gfx_req_d<=gfx_req; gfx_ack<=gfx_req_d;
	// Tile 1: upper pen 1, lower pen 8 (the bad frame's teal-capable plane).
	// Tile 2: lower pen 1 on alternating columns, otherwise transparent.
	gfx_dout <= (gfx_addr[24:6]==19'd1)
		? 64'h0000_ff00_00ff_0000 : 64'h0000_0000_0000_5500;
end
task automatic write_word(input [16:0] a,input [15:0] value);
	begin
		@(negedge clk); address=a;data=value;write=1;
		@(negedge clk); write=0;
	end
endtask
task automatic copy_list;
	begin
		@(negedge clk); buffer_trigger=1;
		@(negedge clk); buffer_trigger=0;
		wait(buffer_busy);wait(!buffer_busy);
		repeat(2) @(negedge clk);
	end
endtask
function automatic [14:0] pixel_at(input integer x);
	case(x&7)
		0: pixel_at=video.line_buffer_bank0[38+(x>>3)];
		1: pixel_at=video.line_buffer_bank1[38+(x>>3)];
		2: pixel_at=video.line_buffer_bank2[38+(x>>3)];
		3: pixel_at=video.line_buffer_bank3[38+(x>>3)];
		4: pixel_at=video.line_buffer_bank4[38+(x>>3)];
		5: pixel_at=video.line_buffer_bank5[38+(x>>3)];
		6: pixel_at=video.line_buffer_bank6[38+(x>>3)];
		7: pixel_at=video.line_buffer_bank7[38+(x>>3)];
	endcase
endfunction
task automatic render_row(input integer row,input bit fire_only);
	integer x;
	logic [14:0] expected;
	begin
		@(negedge clk);reset=1;ce_pix=0;
		repeat(3) @(negedge clk);
		reset=0;
		@(negedge clk);ce_pix=1;h_count=0;v_count=(row+246)%258;
		@(negedge clk);ce_pix=0;h_count=1;
		render_cycles=0;
		while(!line_done) begin @(negedge clk);render_cycles=render_cycles+1;end
		if(video.target_line!==row)
			$fatal(1,"test rendered the wrong physical row");
		for(x=0;x<304;x=x+1) begin
			expected=(!fire_only && (x&1)) ? 15'd2049 : 15'd3905;
			if(pixel_at(x)!==expected)
				$fatal(1,"kick companion row=%0d x=%0d got=%h expected=%h",
					row,x,pixel_at(x),expected);
		end
		reset=1;
	end
endtask
initial begin
	for(bank=0;bank<4;bank=bank+1)
		for(index=0;index<32768;index=index+1) memory.bank_memory[bank][index]=0;
	// Synthetic page-30 fire and page-31 transparent companion maps.
	for(tile=0;tile<2048;tile=tile+1) begin
		index=(30<<12)+(tile<<1);
		memory.bank_memory[index&3][index>>2]=16'd7808; // palette 244
		memory.bank_memory[(index+1)&3][(index+1)>>2]=16'd1;
		index=(31<<12)+(tile<<1);
		memory.bank_memory[index&3][index>>2]=16'd4096; // palette 128
		memory.bank_memory[(index+1)&3][(index+1)>>2]=16'd2;
	end
	repeat(3) @(negedge clk);ram_reset=0;
	write_word('h1800,'h0503);write_word('h1801,'h0070);
	write_word('h1802,'h0080);write_word('h1803,'h8800);
	write_word('h1804,'h8403);write_word('h1805,'h0070);
	write_word('h1806,'h0080);write_word('h1807,'h8810);
	for(chunk=0;chunk<4;chunk=chunk+1) begin
		write_word('h2000+chunk*4,'h5000);
		write_word('h2001+chunk*4,'h0c00+chunk*64);
		write_word('h2002+chunk*4,'h7800);
		write_word('h2003+chunk*4,'h0080);
		write_word('h2040+chunk*4,'h5000);
		write_word('h2041+chunk*4,'h0c00+chunk*64);
		write_word('h2042+chunk*4,'h7c00);
		write_word('h2043+chunk*4,'h0080);
	end
	copy_list();
	render_row(0,0);reference_cycles=render_cycles;
	// The live packed words acquire the new upper-bitplane fire before the
	// next buffer trigger, but the private last header is still lower 4-bpp.
	for(chunk=0;chunk<4;chunk=chunk+1) write_word(16+chunk*4+2,'h7800);
	for(physical_row=0;physical_row<232;physical_row=physical_row+64) begin
		render_row(physical_row,0);
		if(render_cycles!=reference_cycles)
			$fatal(1,"companion protection inserted renderer cycles");
	end
	// Next DMA publishes the new 5-bpp header and refreshes the seeds.
	write_word('h1804,'h8503);
	for(chunk=0;chunk<4;chunk=chunk+1) write_word('h2042+chunk*4,'h7800);
	copy_list();
	render_row(0,1);
	$display("PASS actual kick DMA/scan/pixels: all four chunks, unchanged cycles, next generation");
	$finish;
end
initial begin #5000000; $fatal(1,"kick companion test timeout");end
endmodule
