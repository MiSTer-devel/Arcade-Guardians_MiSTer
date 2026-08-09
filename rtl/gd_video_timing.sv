// Guardians native raster timing. The DX-101 renders into a 512x256 raster;
// the P-FG01-1 board exposes 304x232 pixels.
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

// MAME models this board as a 512x256 raster at exactly 60 Hz. The system PLL
// runs at the PLL's nearest legal eightfold multiple (7.864583 MHz pixels,
// 60.002 Hz). A fixed clock
// enable avoids the alternating seven/eight-cycle cadence that can violate
// assumptions in MiSTer's input video pipeline on non-integer HDMI scaling.
logic [2:0] pixel_divider;
assign ce_pix = (pixel_divider == 3'd0);

always_ff @(posedge clk) begin
	frame_tick <= 1'b0;
	if (reset) begin
		pixel_divider <= 3'd0;
		h_count <= 9'd0;
		v_count <= 9'd0;
	end
	else begin
		pixel_divider <= pixel_divider + 3'd1;
		if (ce_pix) begin
			if (h_count == 9'd511) begin
				h_count <= 9'd0;
				if (v_count == 9'd255) begin
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
	hsync  = !((h_count >= 9'd384) && (h_count < 9'd432));
	vsync  = !((v_count >= 9'd240) && (v_count < 9'd244));
end

endmodule
