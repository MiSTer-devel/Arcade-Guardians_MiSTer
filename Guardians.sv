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
	"P1O[2],Diagnostic raster,Off,On;",
	"P1O[3],Test / service mode,Off,On;",
	"P1-;",
	"O46,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"DIP;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Attack,Jump,Special,-,Start,Coin,Service;",
	"jn,A,B,X,Y,Start,Select,R;",
	"v,1.0;",
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
	.diagnostic_grid(!rom_ready | status[2]), .service(status[3]),
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
	.sdram_dma_addr, .sdram_dma_req, .sdram_dma_data, .sdram_dma_ack,
	.ce_pix, .hblank, .hsync, .vblank, .vsync,
	.red, .green, .blue, .audio_left(core_audio_left),
	.audio_right(core_audio_right), .rom_ready, .debug_cpu_address,
	.debug_bus_cycles, .debug_unmapped_cycles
);

wire [2:0] video_fx = status[6:4];
wire scandoubler = forced_scandoubler || (video_fx != 3'd0);
wire [2:0] scanline_level = video_fx ? video_fx - 3'd1 : 3'd0;

assign CLK_VIDEO = clk_sys;
assign VGA_SL = scanline_level[1:0];

// Guardians is a native 15-kHz arcade board. Keep that timing on analog RGB
// by default, but honour MiSTer's forced_scandoubler setting for 31-kHz VGA
// displays. The same framework mixer also gives HDMI and analog output a
// single, well-tested sync/gamma path.
video_mixer #(.LINE_LENGTH(304), .HALF_DEPTH(0), .GAMMA(1)) video_out
(
	.CLK_VIDEO(clk_sys), .CE_PIXEL, .ce_pix,
	.scandoubler, .hq2x(video_fx == 3'd1), .gamma_bus,
	.R(red), .G(green), .B(blue),
	.HSync(hsync), .VSync(vsync), .HBlank(hblank), .VBlank(vblank),
	.HDMI_FREEZE(1'b0), .freeze_sync(),
	.VGA_R, .VGA_G, .VGA_B, .VGA_VS, .VGA_HS, .VGA_DE
);
assign AUDIO_L = core_audio_left;
assign AUDIO_R = core_audio_right;
assign LED_USER = rom_ready;

endmodule
