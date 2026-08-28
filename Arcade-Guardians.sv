//============================================================================
//
// Guardians / Denjin Makai II MiSTer FPGA core
//
// SPDX-License-Identifier: GPL-3.0-or-later
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 3'b000;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1 = 1'b0;
assign VGA_SCALER = 1'b0;
assign VGA_DISABLE = 1'b0;
assign HDMI_FREEZE = 1'b0;
assign HDMI_BLACKOUT = 1'b0;
assign HDMI_BOB_DEINT = 1'b0;
assign AUDIO_S = 1'b1;
assign AUDIO_MIX = 2'b00;
assign LED_DISK = 2'b00;
assign LED_POWER = 2'b00;
assign BUTTONS = 2'b00;
assign VIDEO_ARX = 13'd4;
assign VIDEO_ARY = 13'd3;

`include "build_id.v"
localparam CONF_STR = {
	"Guardians;;",
	"-;",
	"P1,Hardware;",
	"P1O[3],Test / service mode,Off,On;",
	"P1O[26],Turbo CPU (+50%),Off,On;",
	"P1-;",
	"O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P2,CRT Geometry;",
	"P2O[7],CRT Geometry,Off,On;",
	"P2O[11:8],H Size,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P2O[43:39],H Shift,0,+2,+4,+6,+8,+10,+12,+14,+16,+18,+20,+22,+24,+26,+28,+30,-32,-30,-28,-26,-24,-22,-20,-18,-16,-14,-12,-10,-8,-6,-4,-2;",
	"P2O[18:16],V Size,0,+1,+2,+3,-3,-2,-1;",
	"P2O[23:20],V Shift,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P2O[24],V Size Mode,Cabinet (Stable),PVM (Retimed);",
	"P2O[25],Rotation,Normal,180 deg;",
	"P3,Cheats - General;",
	"P3O[27],Infinite Credits,Off,On;",
	"P3O[28],Infinite Time,Off,On;",
	"P4,Cheats - Player 1;",
	"P4O[29],Infinite Lives,Off,On;",
	"P4O[30],Infinite Energy,Off,On;",
	"P4O[31],Infinite Power,Off,On;",
	"P4O[32],Invincibility,Off,On;",
	"P4O[33],Always Special,Off,On;",
	"P5,Cheats - Player 2;",
	"P5O[34],Infinite Lives,Off,On;",
	"P5O[35],Infinite Energy,Off,On;",
	"P5O[36],Infinite Power,Off,On;",
	"P5O[37],Invincibility,Off,On;",
	"P5O[38],Always Special,Off,On;",
	"DIP;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Attack,Jump,Special,Pause,Start,Coin,Service;",
	"jn,A,B,X,Y,Start,Select,R;",
	"v,1.2.1;",
	"V,v",`BUILD_DATE
};

wire forced_scandoubler;
wire [21:0] gamma_bus;
wire [1:0] buttons;
wire [127:0] status;
wire ioctl_download;
wire ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_dout;
wire [15:0] ioctl_index;
wire ioctl_wait;
wire [31:0] joystick_0;
wire [31:0] joystick_1;
wire [15:0] joystick_l_analog_0;
wire [15:0] joystick_l_analog_1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .EXT_BUS(), .gamma_bus,
	.forced_scandoubler, .buttons, .status, .ioctl_download,
	.ioctl_wr, .ioctl_addr, .ioctl_dout, .ioctl_index, .ioctl_wait,
	.joystick_0, .joystick_1, .joystick_l_analog_0,
	.joystick_l_analog_1
);

wire [31:0] joystick_p1;
wire [31:0] joystick_p2;

gd_analog_to_digital analog_p1
(
	.digital_in(joystick_0), .analog_xy(joystick_l_analog_0),
	.joystick_out(joystick_p1)
);

gd_analog_to_digital analog_p2
(
	.digital_in(joystick_1), .analog_xy(joystick_l_analog_1),
	.joystick_out(joystick_p2)
);

wire clk_sys;
wire pll_locked;
pll pll
(
	.refclk(CLK_50M), .rst(1'b0), .outclk_0(),
	.outclk_1(clk_sys), .locked(pll_locked)
);

wire cold_reset = ~pll_locked;
wire reset = RESET | status[0] | buttons[1] | cold_reset;

wire paused;
gd_pause_toggle pause_control
(
	.clk(clk_sys), .reset,
	.button(joystick_p1[7] | joystick_p2[7]), .paused
);

logic [15:0] dip_switches = 16'hffff;
always_ff @(posedge clk_sys) begin
	if (ioctl_wr && (ioctl_index == 16'd254)) begin
		if (ioctl_addr == 27'd0) dip_switches[7:0] <= ioctl_dout;
		if (ioctl_addr == 27'd1) dip_switches[15:8] <= ioctl_dout;
	end
end

// The immutable 32 MiB graphics region lives in the low-latency SDRAM. This
// keeps live tile/sprite traffic off the DDR3 interface used by MiSTer's HDMI
// scaler. Program ROM, samples and work RAM remain on DDR3.
wire sdram_ready;
wire [24:0] sdram_mem_addr;
wire [15:0] sdram_mem_din;
wire [1:0] sdram_mem_be;
wire sdram_mem_burst;
wire [63:0] sdram_mem_burst_data;
wire sdram_mem_rnw;
wire sdram_mem_req;
wire [15:0] sdram_mem_dout;
wire sdram_mem_ack;
wire [24:0] sdram_dma_addr;
wire sdram_dma_req;
wire [63:0] sdram_dma_data;
wire sdram_dma_ack;

gd_sdram graphics_sdram
(
	.clk(clk_sys), .reset(cold_reset), .SDRAM_DQ, .SDRAM_A, .SDRAM_BA,
	.SDRAM_CLK, .SDRAM_CKE, .SDRAM_DQML, .SDRAM_DQMH, .SDRAM_nCS,
	.SDRAM_nWE, .SDRAM_nCAS, .SDRAM_nRAS,
	.mem_addr(sdram_mem_addr), .mem_din(sdram_mem_din),
	.mem_be(sdram_mem_be), .mem_rnw(sdram_mem_rnw),
	.mem_burst(sdram_mem_burst), .mem_burst_data(sdram_mem_burst_data),
	.mem_req(sdram_mem_req), .mem_dout(sdram_mem_dout),
	.mem_ack(sdram_mem_ack), .video_dma_req(sdram_dma_req),
	.video_dma_addr(sdram_dma_addr), .video_dma_ack(sdram_dma_ack),
	.video_dma_data(sdram_dma_data), .ready(sdram_ready)
);

wire memory_ready_sys = pll_locked && sdram_ready;

wire ce_pix;
wire hblank;
wire hsync;
wire vblank;
wire vsync;
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire signed [15:0] core_audio_left;
wire signed [15:0] core_audio_right;
wire rom_ready;
wire [23:0] debug_cpu_address;
wire [31:0] debug_bus_cycles;
wire [15:0] debug_unmapped_cycles;

gd_core core
(
	.clk(clk_sys), .cold_reset, .reset,
	.memory_ready(memory_ready_sys),
	.diagnostic_grid(1'b0), .service(status[3]), .turbo(status[26]), .pause(paused),
	.rotate_180(status[25]),
	.cheats(status[38:27]),
	.dip_switches, .joystick_p1, .joystick_p2,
	.rom_downloading(ioctl_download && (ioctl_index == 16'd0)),
	.rom_wr(ioctl_wr && (ioctl_index == 16'd0)),
	.rom_addr(ioctl_addr), .rom_data(ioctl_dout), .rom_wait(ioctl_wait),
	.ddr_clk(DDRAM_CLK), .ddr_busy(DDRAM_BUSY),
	.ddr_burstcount(DDRAM_BURSTCNT), .ddr_addr(DDRAM_ADDR),
	.ddr_dout(DDRAM_DOUT), .ddr_dout_ready(DDRAM_DOUT_READY),
	.ddr_rd(DDRAM_RD), .ddr_din(DDRAM_DIN), .ddr_be(DDRAM_BE),
	.ddr_we(DDRAM_WE), .sdram_mem_addr, .sdram_mem_din, .sdram_mem_be,
	.sdram_mem_rnw, .sdram_mem_req, .sdram_mem_dout, .sdram_mem_ack,
	.sdram_mem_burst, .sdram_mem_burst_data,
	.sdram_dma_addr, .sdram_dma_req, .sdram_dma_data, .sdram_dma_ack,
	.ce_pix, .hblank, .hsync, .vblank, .vsync,
	.red, .green, .blue, .audio_left(core_audio_left),
	.audio_right(core_audio_right), .rom_ready, .debug_cpu_address,
	.debug_bus_cycles, .debug_unmapped_cycles
);

wire [2:0] video_fx = status[6:4];

// CRT geometry is deliberately outside the native game timing domain. The
// game, raster IRQs and sound continue at board speed while the completed
// video stream is resized/repositioned for an analog monitor. Geometry Off is
// a registered pure passthrough through both stages.
wire crt_geometry = status[7];
// MiSTer's scandoubler/HQ2x engine requires the native, uniformly clocked
// pixel stream. Geometry is an analog-monitor adjustment and must not retime
// that source. This also gives Geometry Off a literal zero-processing bypass.
wire crt_geometry_active = crt_geometry && (video_fx == 3'd0)
	&& !forced_scandoubler;
wire signed [4:0] crt_hsize = {{1{status[11]}}, status[11:8]};
wire signed [5:0] crt_hshift_step = {{1{status[43]}}, status[43:39]};
wire signed [8:0] crt_hshift = $signed(crt_hshift_step) <<< 1;
wire signed [5:0] crt_vshift = {{2{status[23]}}, status[23:20]};
wire signed [3:0] crt_vsize_step = (status[18:16] <= 3'd3)
	? $signed({1'b0, status[18:16]})
	: $signed({1'b0, status[18:16]}) - 4'sd7;
wire signed [5:0] crt_vsize_scaled_step =
	{{2{crt_vsize_step[3]}}, crt_vsize_step};
wire signed [5:0] crt_vsize = -(crt_vsize_scaled_step
	+ (crt_vsize_scaled_step <<< 1));

wire [7:0] crt_vz_red;
wire [7:0] crt_vz_green;
wire [7:0] crt_vz_blue;
wire crt_vz_hsync;
wire crt_vz_vsync;
wire crt_vz_de;
wire crt_vz_vblank;
wire crt_vz_ce;

// PVM mode changes line cadence while preserving one unique source line per
// output line. Cabinet mode keeps native sync and performs photometric vertical
// scaling for monitors with a narrow horizontal-lock range.
crt_vsize #(.RING_LINES(22), .LINE_PX(304)) crt_vertical
(
	.clk(clk_sys), .pxl_cen(ce_pix), .active(crt_geometry_active),
	.tube_mode(~status[24]), .vsize(crt_vsize),
	.r_in(red), .g_in(green), .b_in(blue),
	// crt_vsize measures and synthesizes positive sync pulses. Guardians'
	// native raster is negative-sync, so normalize at this boundary and
	// convert back before feeding crt_adjust. The zero-size bypass therefore
	// remains electrically identical while nonzero V Size sees the polarity
	// its measurement and retiming logic expects.
	.hs_in(~hsync), .vs_in(~vsync), .de_in(~(hblank | vblank)),
	.vb_in(vblank), .r_out(crt_vz_red), .g_out(crt_vz_green),
	.b_out(crt_vz_blue), .hs_out(crt_vz_hsync),
	.vs_out(crt_vz_vsync), .de_out(crt_vz_de),
	.vb_out(crt_vz_vblank), .ce_out(crt_vz_ce)
);

wire crt_hs_reference;
logic crt_hs_reference_d;
logic [7:0] crt_read_accumulator;
wire crt_hs_reference_rise = crt_hs_reference
	&& !crt_hs_reference_d;
// clk_sys / native pixel clock = 11. Express the period in quarter-clocks so
// one signed OSD step changes horizontal size by approximately 2.3 percent.
wire [7:0] crt_read_period = 8'd44
	+ {{3{crt_hsize[4]}}, crt_hsize};
wire [8:0] crt_read_sum = {1'b0, crt_read_accumulator} + 9'd4;
wire crt_read_tick = (crt_read_sum >= {1'b0, crt_read_period});

always_ff @(posedge clk_sys) begin
	crt_hs_reference_d <= crt_hs_reference;
	if (reset || crt_hs_reference_rise)
		crt_read_accumulator <= 8'd0;
	else if (crt_read_tick)
		crt_read_accumulator <= crt_read_sum[7:0] - crt_read_period;
	else
		crt_read_accumulator <= crt_read_sum[7:0];
end

wire [7:0] crt_out_red;
wire [7:0] crt_out_green;
wire [7:0] crt_out_blue;
wire crt_out_hsync;
wire crt_out_vsync;
wire crt_out_hblank;
wire crt_out_vblank;

crt_adjust #(
	.VTOTAL(258), .HTOTAL(410), .HPOS_MODE(0)
) crt_horizontal (
	.clk(clk_sys), .pxl_cen(crt_vz_ce), .pxl2_cen(crt_read_tick),
	.active(crt_geometry_active), .hsize(crt_hsize), .hoffset(crt_hshift),
	.voffset(crt_vshift), .r_in(crt_vz_red), .g_in(crt_vz_green),
	.b_in(crt_vz_blue), .hs_in(~crt_vz_hsync), .vs_in(~crt_vz_vsync),
	.hb_in(~crt_vz_de), .vb_in(crt_vz_vblank), .r_out(crt_out_red),
	.g_out(crt_out_green), .b_out(crt_out_blue),
	.hs_out(crt_out_hsync), .vs_out(crt_out_vsync),
	.hb_out(crt_out_hblank), .vb_out(crt_out_vblank),
	.hs_ref_out(crt_hs_reference)
);

wire video_ce = crt_geometry_active ? crt_read_tick : ce_pix;
wire [7:0] video_red = crt_geometry_active ? crt_out_red : red;
wire [7:0] video_green = crt_geometry_active ? crt_out_green : green;
wire [7:0] video_blue = crt_geometry_active ? crt_out_blue : blue;
wire video_hsync = crt_geometry_active ? crt_out_hsync : hsync;
wire video_vsync = crt_geometry_active ? crt_out_vsync : vsync;
wire video_hblank = crt_geometry_active ? crt_out_hblank : hblank;
wire video_vblank = crt_geometry_active ? crt_out_vblank : vblank;

// Align sync, blanking and RGB on pixel boundaries before MiSTer's HDMI/VGA
// scaler captures them. Feeding the raw VBlank transition straight into
// video_mixer leaves its registered DE high for the first blank line and low
// for the first visible line. Raw core screenshots do not expose that fault,
// but the scaler-backed analog output can show displaced horizontal slices.
// arcade_video also supplies video_mixer's required WIDTH+4 line-store stride.
arcade_video #(.WIDTH(304), .DW(24), .GAMMA(1)) video_out
(
	.clk_video(clk_sys), .ce_pix(video_ce),
	.RGB_in({video_red, video_green, video_blue}),
	.HBlank(video_hblank), .VBlank(video_vblank),
	.HSync(video_hsync), .VSync(video_vsync),
	.CLK_VIDEO, .CE_PIXEL, .VGA_R, .VGA_G, .VGA_B,
	.VGA_HS, .VGA_VS, .VGA_DE, .VGA_SL,
	.fx(video_fx), .forced_scandoubler, .gamma_bus
);
assign AUDIO_L = core_audio_left;
assign AUDIO_R = core_audio_right;
assign LED_USER = rom_ready;

endmodule
