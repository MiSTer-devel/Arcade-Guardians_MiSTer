// Guardians native raster timing. The P-FG01-1 program configures the DX-101
// for a 410x258 CRT raster and exposes 304x232 pixels.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_video_timing
(
	input  logic       clk,
	input  logic       reset,
	output logic       ce_pix,
	output logic [8:0] h_count,
	output logic [8:0] v_count,
	output logic       hblank,
	output logic       vblank,
	output logic       hsync,
	output logic       vsync,
	output logic       frame_tick
);

// The game programs horizontal sync/display start/display end/total as
// 002e/0059/0188/019a and the vertical equivalents as
// 0003/0014/00fe/0102. The DX-101's 50 MHz clock is divided by eight for a
// 6.25 MHz dot clock. MAME deliberately substitutes 512x256 at exactly 60 Hz;
// use the programmed board timing here for correct native analog RGB:
// approximately 15.244 kHz horizontal and 59.085 Hz vertical.
//
// clk_sys is 62.5 MHz, so a fixed divide-by-ten pixel enable also gives the
// renderer 4100 clocks per line (essentially the same budget as v1.0's
// synthetic 512*8 timing).
logic [3:0] pixel_divider;
assign ce_pix = (pixel_divider == 4'd0);

always_ff @(posedge clk) begin
	frame_tick <= 1'b0;
	if (reset) begin
		pixel_divider <= 4'd0;
		h_count <= 9'd0;
		v_count <= 9'd0;
	end
	else begin
		if (pixel_divider == 4'd9)
			pixel_divider <= 4'd0;
		else
			pixel_divider <= pixel_divider + 4'd1;
		if (ce_pix) begin
			if (h_count == 9'd409) begin
				h_count <= 9'd0;
				if (v_count == 9'd257) begin
					v_count <= 9'd0;
					frame_tick <= 1'b1;
				end
				else
					v_count <= v_count + 9'd1;
			end
			else
				h_count <= h_count + 9'd1;
		end
	end
end

always_comb begin
	hblank = (h_count >= 9'd304);
	vblank = (v_count >= 9'd232);
	// Rebase the board's display-start counter to visible pixel zero. The
	// programmed H sync occupies original counters 0..45 and V sync 0..2.
	hsync  = !((h_count >= 9'd321) && (h_count < 9'd367));
	vsync  = !((v_count >= 9'd238) && (v_count < 9'd241));
end

endmodule
