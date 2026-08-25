// Native OSD cheats for Guardians / Denjin Makai II work RAM.
// Address/value pairs are from Pugsy's public MAME cheat collection and are
// clamped on both CPU reads and CPU writes while the corresponding option is
// enabled. With every option off this module is an exact combinational bypass.
// SPDX-License-Identifier: GPL-3.0-or-later

module gd_work_ram_cheats
(
	input  logic [23:0] address,
	input  logic [15:0] ram_q,
	input  logic [15:0] cpu_write_data,
	input  logic  [1:0] cpu_write_be,
	input  logic [11:0] cheats,
	output logic [15:0] cpu_read_data,
	output logic [15:0] ram_write_data
);

// cheats[0]  infinite credits       0x2014f1 = 0x09
// cheats[1]  infinite time          0x201312 = 0x9a
// cheats[2]  P1 infinite lives      0x201629 = 0x0a
// cheats[3]  P1 infinite energy     0x203142/4 = 0x02c002c0
// cheats[4]  P1 infinite power      0x203146/8 = 0x02c002c0
// cheats[5]  P1 invincibility       0x20308f = 0x02
// cheats[6]  P1 always special      0x20314e = 0xffff
// cheats[7]  P2 infinite lives      0x2016a9 = 0x04
// cheats[8]  P2 infinite energy     0x203342/4 = 0x02c002c0
// cheats[9]  P2 infinite power      0x203346/8 = 0x02c002c0
// cheats[10] P2 invincibility       0x20328f = 0x02
// cheats[11] P2 always special      0x20334e = 0xffff
always_comb begin
	cpu_read_data = ram_q;
	ram_write_data = cpu_write_data;

	case (address)
		24'h2014f0: if (cheats[0]) begin
			cpu_read_data[7:0] = 8'h09;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'h09;
		end

		24'h201312: if (cheats[1]) begin
			cpu_read_data[15:8] = 8'h9a;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'h9a;
		end

		24'h201628: if (cheats[2]) begin
			cpu_read_data[7:0] = 8'h0a;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'h0a;
		end

		24'h203142, 24'h203144: if (cheats[3]) begin
			cpu_read_data = 16'h02c0;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hc0;
		end

		24'h203146, 24'h203148: if (cheats[4]) begin
			cpu_read_data = 16'h02c0;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hc0;
		end

		24'h20308e: if (cheats[5]) begin
			cpu_read_data[7:0] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'h02;
		end

		24'h20314e: if (cheats[6]) begin
			cpu_read_data = 16'hffff;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'hff;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hff;
		end

		24'h2016a8: if (cheats[7]) begin
			cpu_read_data[7:0] = 8'h04;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'h04;
		end

		24'h203342, 24'h203344: if (cheats[8]) begin
			cpu_read_data = 16'h02c0;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hc0;
		end

		24'h203346, 24'h203348: if (cheats[9]) begin
			cpu_read_data = 16'h02c0;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hc0;
		end

		24'h20328e: if (cheats[10]) begin
			cpu_read_data[7:0] = 8'h02;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'h02;
		end

		24'h20334e: if (cheats[11]) begin
			cpu_read_data = 16'hffff;
			if (cpu_write_be[1]) ram_write_data[15:8] = 8'hff;
			if (cpu_write_be[0]) ram_write_data[7:0] = 8'hff;
		end

		default: begin end
	endcase
end

endmodule
