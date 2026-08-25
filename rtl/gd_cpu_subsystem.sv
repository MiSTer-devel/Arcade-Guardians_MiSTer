// Guardians / Denjin Makai II TMP68301 main CPU subsystem.
// Implements the board address map around the fx68k 68000 core.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_cpu_subsystem
(
	input  logic        clk,
	input  logic        reset,
	input  logic        vblank,
	input  logic        raster_irq,
	input  logic [15:0] dip_switches,
	input  logic [31:0] joystick_p1,
	input  logic [31:0] joystick_p2,
	input  logic        service,
	input  logic        turbo,
	input  logic [11:0] cheats,

	output logic [20:0] rom_addr,
	output logic        rom_req,
	input  logic [15:0] rom_dout,
	input  logic        rom_ack,
	output logic [16:0] ram_addr,
	output logic        ram_req,
	output logic        ram_write,
	output logic [15:0] ram_data,
	output logic  [1:0] ram_be,
	input  logic [15:0] ram_dout,
	input  logic        ram_ack,

	input  logic [16:0] sprite_video_address,
	output logic [63:0] sprite_video_q,
	input  logic [14:0] palette_video_address,
	output logic [15:0] palette_video_q,
	input  logic  [4:0] video_reg_address,
	output logic [15:0] video_reg_q,
	output logic [15:0] video_control,
	output logic [26:0] video_x_offset,
	output logic [26:0] video_x_zoom,
	output logic [26:0] video_y_offset,
	output logic [26:0] video_y_zoom,
	output logic        sprite_buffer_busy,
	output logic [15:0] raster_enable,
	output logic [15:0] raster_position,
	output logic        raster_rearm,
	output logic        rowscroll_write,
	output logic [16:0] rowscroll_write_address,
	output logic [15:0] rowscroll_write_data,
	output logic  [1:0] rowscroll_write_byte_enable,

	output logic        x1_write,
	output logic [12:0] x1_address,
	output logic [15:0] x1_data,
	output logic  [1:0] x1_byte_enable,
	input  logic [15:0] x1_q,

	output logic [63:0] sample_banks,
	output logic [23:0] debug_address,
	output logic [31:0] debug_bus_cycles,
	output logic [31:0] debug_rom_cycles,
	output logic [15:0] debug_unmapped_cycles,
	output logic        cpu_running
);

// fx68k advances on alternating Phi1/Phi2 enables. 33.333 MHz phase
// events produce the TMP68301's 16.667 MHz CPU clock from 68.75 MHz.
localparam logic [31:0] CPU_EVENT_INCREMENT = 32'd2082408386;
localparam logic [31:0] TURBO_EVENT_INCREMENT = 32'd3123612579;
logic [31:0] cpu_clock_accumulator;
logic [32:0] cpu_clock_sum;
logic        cpu_half_phase;
logic        cpu_phi1;
logic        cpu_phi2;

always_comb cpu_clock_sum = {1'b0, cpu_clock_accumulator}
	+ {1'b0, turbo ? TURBO_EVENT_INCREMENT : CPU_EVENT_INCREMENT};

// TMP68301 timers stay on the board-rate phase stream. Turbo accelerates the
// 68000 instruction engine only; video IRQ cadence, timer timebases and audio
// pitch therefore remain faithful to the PCB.
logic [31:0] timer_clock_accumulator;
logic [32:0] timer_clock_sum;
logic        timer_half_phase;
logic        timer_cpu_ce;
always_comb timer_clock_sum = {1'b0, timer_clock_accumulator}
	+ {1'b0, CPU_EVENT_INCREMENT};

always_ff @(posedge clk) begin
	cpu_phi1 <= 1'b0;
	cpu_phi2 <= 1'b0;
	if (reset) begin
		cpu_clock_accumulator <= 32'd0;
		cpu_half_phase <= 1'b0;
	end
	else begin
		cpu_clock_accumulator <= cpu_clock_sum[31:0];
		// DX-101 list buffering is a bus-master transaction. Keep the 68000
		// stopped until the referenced records have been packed; otherwise a
		// long gameplay list can be rewritten by software while its tail is
		// still being copied, producing persistent column/checkerboard damage.
		if (cpu_clock_sum[32] && !sprite_buffer_busy) begin
			if (cpu_half_phase) cpu_phi2 <= 1'b1;
			else cpu_phi1 <= 1'b1;
			cpu_half_phase <= ~cpu_half_phase;
		end
	end
end

always_ff @(posedge clk) begin
	timer_cpu_ce <= 1'b0;
	if (reset) begin
		timer_clock_accumulator <= 32'd0;
		timer_half_phase <= 1'b0;
	end
	else begin
		timer_clock_accumulator <= timer_clock_sum[31:0];
		if (timer_clock_sum[32]) begin
			timer_half_phase <= ~timer_half_phase;
			if (timer_half_phase) timer_cpu_ce <= 1'b1;
		end
	end
end

wire        cpu_rw;
wire        cpu_as_n;
wire        cpu_lds_n;
wire        cpu_uds_n;
wire  [2:0] cpu_fc;
wire [15:0] cpu_data_out;
logic [15:0] cpu_data_in;
wire [23:1] cpu_word_addr;
logic        cpu_dtack_n;
wire [23:0] cpu_even_address = {cpu_word_addr, 1'b0};
wire [23:0] cpu_bus_address = {cpu_word_addr,
	(!cpu_lds_n && cpu_uds_n)};
wire [1:0] cpu_byte_enable = {~cpu_uds_n, ~cpu_lds_n};
wire cpu_data_strobe = !cpu_uds_n || !cpu_lds_n;
wire cpu_iack_cycle = !cpu_as_n && (&cpu_fc);

logic [2:0] tmp_irq_level;
logic [7:0] tmp_irq_vector;
wire [2:0] cpu_ipl_n = ~tmp_irq_level;
logic tmp_iack;

fx68k main_cpu
(
	.clk(clk), .HALTn(1'b1), .extReset(reset), .pwrUp(reset),
	.enPhi1(cpu_phi1), .enPhi2(cpu_phi2),
	.eRWn(cpu_rw), .ASn(cpu_as_n), .LDSn(cpu_lds_n), .UDSn(cpu_uds_n),
	.E(), .VMAn(), .FC0(cpu_fc[0]), .FC1(cpu_fc[1]), .FC2(cpu_fc[2]),
	.BGn(), .oRESETn(), .oHALTEDn(), .DTACKn(cpu_dtack_n),
	.VPAn(1'b1), .BERRn(1'b1), .BRn(1'b1), .BGACKn(1'b1),
	.IPL0n(cpu_ipl_n[0]), .IPL1n(cpu_ipl_n[1]),
	.IPL2n(cpu_ipl_n[2]), .iEdb(cpu_data_in),
	.oEdb(cpu_data_out), .eab(cpu_word_addr)
);

logic cpu_data_strobe_seen;
always_ff @(posedge clk) begin
	if (reset || cpu_as_n) cpu_data_strobe_seen <= 1'b0;
	else if (cpu_data_strobe) cpu_data_strobe_seen <= 1'b1;
end

wire cs_program = (cpu_even_address <= 24'h1ffffe);
wire cs_work = (cpu_even_address >= 24'h200000)
	&& (cpu_even_address <= 24'h20fffe);
wire cs_aux = (cpu_even_address >= 24'h304000)
	&& (cpu_even_address <= 24'h30fffe);
wire cs_dsw1 = (cpu_even_address == 24'h600000);
wire cs_dsw2 = (cpu_even_address == 24'h600002);
wire cs_p1 = (cpu_even_address == 24'h700000);
wire cs_p2 = (cpu_even_address == 24'h700002);
wire cs_system = (cpu_even_address == 24'h700004);
wire cs_watchdog = (cpu_even_address == 24'h70000c);
wire cs_coin = (cpu_even_address == 24'h800000);
wire cs_x1 = (cpu_even_address >= 24'hb00000)
	&& (cpu_even_address <= 24'hb03ffe);
wire cs_sprite = (cpu_even_address >= 24'hc00000)
	&& (cpu_even_address <= 24'hc3fffe);
wire cs_palette = (cpu_even_address >= 24'hc40000)
	&& (cpu_even_address <= 24'hc4fffe);
wire cs_extra_palette = (cpu_even_address >= 24'hc50000)
	&& (cpu_even_address <= 24'hc5fffe);
wire cs_video_regs = (cpu_even_address >= 24'hc60000)
	&& (cpu_even_address <= 24'hc6003e);
wire cs_sample_bank = (cpu_even_address >= 24'he00010)
	&& (cpu_even_address <= 24'he0001e);
wire cs_tmp = (cpu_even_address >= 24'hfffc00);
wire mapped_cycle = cs_program || cs_work || cs_aux || cs_dsw1 || cs_dsw2
	|| cs_p1 || cs_p2 || cs_system || cs_watchdog || cs_coin || cs_x1
	|| cs_sprite || cs_palette || cs_extra_palette || cs_video_regs
	|| cs_sample_bank || cs_tmp;

typedef enum logic [2:0] {
	BUS_IDLE, BUS_ROM_WAIT, BUS_RAM_WAIT, BUS_ACK
} bus_state_t;
bus_state_t bus_state;

wire local_write = !cpu_as_n && !cpu_iack_cycle && cpu_data_strobe
	&& cpu_data_strobe_seen && !cpu_rw && (bus_state == BUS_IDLE);

always_comb begin
	rowscroll_write = local_write && cs_sprite;
	rowscroll_write_address = cpu_even_address[17:1];
	rowscroll_write_data = cpu_data_out;
	rowscroll_write_byte_enable = cpu_byte_enable;
end

wire [15:0] work_q;
wire [15:0] work_read_data;
wire [15:0] work_write_data;
wire [15:0] work_video_unused;
gd_work_ram_cheats work_ram_cheats
(
	.address(cpu_even_address), .ram_q(work_q),
	.cpu_write_data(cpu_data_out), .cpu_write_be(cpu_byte_enable),
	.cheats, .cpu_read_data(work_read_data),
	.ram_write_data(work_write_data)
);
gd_word_ram #(.ADDR_WIDTH(15)) work_ram
(
	.clk(clk), .address(cpu_even_address[15:1]), .data(work_write_data),
	.byte_enable(cpu_byte_enable), .write(local_write && cs_work), .q(work_q),
	.video_clk(clk), .video_address(15'd0), .video_q(work_video_unused)
);

// The game uses this 48 KiB window for live tile data. Keep it on-chip so
// normal rendering and CPU updates never stall on DDR3 write-through traffic.
wire [15:0] aux_q;
wire [15:0] aux_video_unused;
wire [14:0] aux_address = cpu_even_address[15:1] - 15'h2000;
gd_word_ram #(.ADDR_WIDTH(15), .NUM_WORDS(24576)) aux_ram
(
	.clk(clk), .address(aux_address), .data(cpu_data_out),
	.byte_enable(cpu_byte_enable), .write(local_write && cs_aux), .q(aux_q),
	.video_clk(clk), .video_address(15'd0), .video_q(aux_video_unused)
);

wire [15:0] sprite_q;
wire sprite_buffer_trigger = local_write && cs_video_regs
	&& (cpu_even_address[5:1] == 5'h13)
	&& ((cpu_byte_enable[1] && (cpu_data_out[15:8] != 8'd0))
	    || (cpu_byte_enable[0] && (cpu_data_out[7:0] != 8'd0)));
// Writing one to register 0x3c re-arms the raster timer. Guardians relies on
// the special case where register 0x3e still names the current line: the
// still-active source queues a second service after the handler returns, then
// that second service advances to line two and begins the rowscroll chain.
always_comb raster_rearm = local_write && cs_video_regs
	&& (cpu_even_address[5:1] == 5'h1e)
	&& cpu_byte_enable[0] && cpu_data_out[0];
gd_sprite_ram sprite_ram
(
	.clk(clk), .reset, .buffer_trigger(sprite_buffer_trigger),
	.address(cpu_even_address[17:1]), .data(cpu_data_out),
	.byte_enable(cpu_byte_enable), .write(local_write && cs_sprite), .q(sprite_q),
	.video_clk(clk), .video_address(sprite_video_address), .video_q(sprite_video_q),
	.buffer_busy(sprite_buffer_busy)
);

wire [15:0] palette_q;
gd_word_ram #(.ADDR_WIDTH(15)) palette_ram
(
	.clk(clk), .address(cpu_even_address[15:1]), .data(cpu_data_out),
	.byte_enable(cpu_byte_enable), .write(local_write && cs_palette), .q(palette_q),
	.video_clk(clk), .video_address(palette_video_address), .video_q(palette_video_q)
);

logic [15:0] video_registers [0:31];
integer vr;
always_ff @(posedge clk) begin
	if (reset) begin
		for (vr = 0; vr < 32; vr = vr + 1) video_registers[vr] <= 16'd0;
	end
	else if (local_write && cs_video_regs) begin
		if (cpu_byte_enable[1]) video_registers[cpu_even_address[5:1]][15:8]
			<= cpu_data_out[15:8];
		if (cpu_byte_enable[0]) video_registers[cpu_even_address[5:1]][7:0]
			<= cpu_data_out[7:0];
	end
end
always_comb video_reg_q = video_registers[video_reg_address];
always_comb begin
	video_control = video_registers[24];
	video_x_offset = {video_registers[9][10:0], video_registers[8]};
	video_x_zoom = {video_registers[11][10:0], video_registers[10]};
	video_y_offset = {video_registers[13][10:0], video_registers[12]};
	video_y_zoom = {video_registers[15][10:0], video_registers[14]};
	raster_enable = video_registers[30];
	raster_position = video_registers[31];
end
wire [15:0] cpu_video_reg_q = video_registers[cpu_even_address[5:1]];

logic [15:0] p1_port;
logic [15:0] p2_port;
logic [15:0] system_port;
always_comb begin
	p1_port = 16'hffff;
	p2_port = 16'hffff;
	system_port = 16'hffff;
	// MAME bit order: left, right, up, down, B1, B2, B3, start.
	p1_port[0] = ~joystick_p1[1]; p2_port[0] = ~joystick_p2[1];
	p1_port[1] = ~joystick_p1[0]; p2_port[1] = ~joystick_p2[0];
	p1_port[2] = ~joystick_p1[3]; p2_port[2] = ~joystick_p2[3];
	p1_port[3] = ~joystick_p1[2]; p2_port[3] = ~joystick_p2[2];
	p1_port[4] = ~joystick_p1[4]; p2_port[4] = ~joystick_p2[4];
	p1_port[5] = ~joystick_p1[5]; p2_port[5] = ~joystick_p2[5];
	p1_port[6] = ~joystick_p1[6]; p2_port[6] = ~joystick_p2[6];
	p1_port[7] = ~joystick_p1[8]; p2_port[7] = ~joystick_p2[8];
	system_port[0] = ~joystick_p1[9];
	system_port[1] = ~joystick_p2[9];
	system_port[2] = ~(joystick_p1[10] | joystick_p2[10]);
	system_port[3] = ~service;
end

wire [15:0] tmp_q;
gd_tmp68301 tmp68301_regs
(
	.clk(clk), .reset(reset), .cpu_ce(timer_cpu_ce), .cs(cs_tmp),
	.write(local_write && cs_tmp),
	.address(cpu_even_address[9:0]), .data(cpu_data_out),
	.byte_enable(cpu_byte_enable), .q(tmp_q), .ext_irq0(vblank),
	.ext_irq1(raster_irq), .iack(tmp_iack), .irq_level(tmp_irq_level),
	.irq_vector(tmp_irq_vector)
);

always_ff @(posedge clk) begin
	x1_write <= 1'b0;
	if (reset) begin
		x1_address <= 13'd0;
		x1_data <= 16'd0;
		x1_byte_enable <= 2'd0;
		sample_banks <= 64'd0;
	end
	else begin
		if (local_write && cs_x1) begin
			x1_write <= 1'b1;
			x1_address <= cpu_even_address[13:1];
			x1_data <= cpu_data_out;
			x1_byte_enable <= cpu_byte_enable;
		end
		if (local_write && cs_sample_bank && cpu_byte_enable[0])
			sample_banks[cpu_even_address[3:1]*8 +: 8] <= cpu_data_out[7:0];
	end
end

always_ff @(posedge clk) begin
	debug_address <= cpu_bus_address;
	tmp_iack <= 1'b0;
	if (reset) begin
		bus_state <= BUS_IDLE;
		cpu_dtack_n <= 1'b1;
		cpu_data_in <= 16'hffff;
		rom_addr <= 21'd0;
		rom_req <= 1'b0;
		ram_addr <= 17'd0;
		ram_req <= 1'b0;
		ram_write <= 1'b0;
		ram_data <= 16'd0;
		ram_be <= 2'd0;
		debug_address <= 24'd0;
		debug_bus_cycles <= 32'd0;
		debug_rom_cycles <= 32'd0;
		debug_unmapped_cycles <= 16'd0;
		cpu_running <= 1'b0;
		tmp_iack <= 1'b0;
	end
	else begin
		case (bus_state)
			BUS_IDLE: begin
				cpu_dtack_n <= 1'b1;
				if (!cpu_as_n && cpu_data_strobe && cpu_data_strobe_seen) begin
					debug_bus_cycles <= debug_bus_cycles + 32'd1;
					if (cpu_iack_cycle) begin
						cpu_data_in <= {8'hff, tmp_irq_vector};
						tmp_iack <= 1'b1;
						cpu_dtack_n <= 1'b0;
						bus_state <= BUS_ACK;
					end
					else if (cs_program && cpu_rw) begin
						rom_addr <= cpu_even_address[20:0];
						rom_req <= ~rom_req;
						debug_rom_cycles <= debug_rom_cycles + 32'd1;
						cpu_running <= 1'b1;
						bus_state <= BUS_ROM_WAIT;
					end
					else if (cs_extra_palette) begin
						ram_addr <= {1'b1, cpu_even_address[15:0]};
						ram_write <= !cpu_rw;
						ram_data <= cpu_data_out;
						ram_be <= cpu_byte_enable;
						ram_req <= ~ram_req;
						bus_state <= BUS_RAM_WAIT;
					end
					else begin
						if (!mapped_cycle)
							debug_unmapped_cycles <= debug_unmapped_cycles + 16'd1;
						if (cs_work) cpu_data_in <= work_read_data;
						else if (cs_aux) cpu_data_in <= aux_q;
						else if (cs_dsw1) cpu_data_in <= {8'hff, dip_switches[7:0]};
						else if (cs_dsw2) cpu_data_in <= {8'hff, dip_switches[15:8]};
						else if (cs_p1) cpu_data_in <= p1_port;
						else if (cs_p2) cpu_data_in <= p2_port;
						else if (cs_system) cpu_data_in <= system_port;
						else if (cs_x1) cpu_data_in <= x1_q;
						else if (cs_sprite) cpu_data_in <= sprite_q;
						else if (cs_palette) cpu_data_in <= palette_q;
						else if (cs_video_regs) cpu_data_in <= cpu_video_reg_q;
						else if (cs_tmp) cpu_data_in <= tmp_q;
						else cpu_data_in <= 16'hffff;
						cpu_dtack_n <= 1'b0;
						bus_state <= BUS_ACK;
					end
				end
			end

			BUS_ROM_WAIT: if (rom_ack == rom_req) begin
				cpu_data_in <= rom_dout;
				cpu_dtack_n <= 1'b0;
				bus_state <= BUS_ACK;
			end

			BUS_RAM_WAIT: if (ram_ack == ram_req) begin
				cpu_data_in <= ram_dout;
				cpu_dtack_n <= 1'b0;
				bus_state <= BUS_ACK;
			end

			BUS_ACK: if (cpu_as_n) begin
				cpu_dtack_n <= 1'b1;
				bus_state <= BUS_IDLE;
			end
			default: bus_state <= BUS_IDLE;
		endcase
	end
end

endmodule
