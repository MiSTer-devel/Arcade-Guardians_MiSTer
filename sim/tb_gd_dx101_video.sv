`timescale 1ns/1ps
module tb_gd_dx101_video;
logic clk=0; always #5 clk=~clk;
logic reset=1;
logic ce_pix=0;
logic [8:0] h_count=0;
logic [8:0] v_count=0;
logic hblank=0;
logic vblank=0;
logic [15:0] video_control=0;
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

gd_dx101_video #(.AHEAD_RENDER(1'b0)) dut(.*);
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
initial begin
	for(i=0;i<131072;i=i+1) sprite_memory[i]=0;
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
	@(posedge clk); ce_pix<=1; h_count<=0; v_count<=0;
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
	@(posedge clk); ce_pix<=1; h_count<=0; v_count<=1;
	@(posedge clk); ce_pix<=0; h_count<=1;
	wait(busy);
	wait(!busy && dut.state==dut.R_IDLE);
	@(posedge clk);
	for(i=0;i<8;i=i+1)
		if(line_buffer0_at(10+i) !== (15'h0021+i))
			$fatal(1,"floating pixel %0d=%h",i,line_buffer0_at(10+i));
	$display("PASS gd_dx101_video drew normal and floating-tilemap 8bpp rows");
	$finish;
end
initial begin
	#200000;
	$display("timeout state=%0d busy=%b float_x=%0d sprite_addr=%h gfx_req=%b gfx_ack=%b target=%0d",
		dut.state, busy, dut.float_x, sprite_address, gfx_req, gfx_ack,
		dut.target_line);
	$fatal(1,"timeout");
end
endmodule
