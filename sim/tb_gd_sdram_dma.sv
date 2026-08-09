`timescale 1ns/1ps

module tb_gd_sdram_dma;
logic clk = 1'b0;
logic reset = 1'b1;
tri [15:0] SDRAM_DQ;
logic [15:0] external_dq = 16'h0000;
assign SDRAM_DQ = external_dq;
wire [12:0] SDRAM_A;
wire [1:0] SDRAM_BA;
wire SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH;
wire SDRAM_nCS, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS;
logic [24:0] mem_addr = 25'd0;
logic [15:0] mem_din = 16'd0;
logic [1:0] mem_be = 2'b11;
logic mem_rnw = 1'b1;
logic mem_req = 1'b0;
logic [15:0] mem_dout;
logic mem_ack;
logic video_dma_req = 1'b0;
logic [24:0] video_dma_addr = 25'h0123400;
logic video_dma_ack;
logic [63:0] video_dma_data;
logic ready;

integer read_delay = -1;
integer burst_word = 0;
integer timeout = 0;

always #4.365 clk = ~clk;

gd_sdram dut(.*);

// Minimal CAS-3, burst-length-4 SDRAM read model. Commands are sampled on
// the forwarded SDRAM clock and returned data is changed on that same edge,
// leaving it centered around the controller's following clk rising edge.
always @(posedge SDRAM_CLK) begin
	if ({SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} == 3'b101) begin
		read_delay = 3;
		burst_word = 0;
	end
	else if (read_delay > 1) begin
		read_delay = read_delay - 1;
	end
	else if (read_delay == 1) begin
		external_dq = 16'h1122;
		read_delay = 0;
		burst_word = 1;
	end
	else if (read_delay == 0 && burst_word < 4) begin
		case (burst_word)
			1: external_dq = 16'h3344;
			2: external_dq = 16'h5566;
			default: external_dq = 16'h7788;
		endcase
		burst_word = burst_word + 1;
	end
end

initial begin
	repeat (4) @(posedge clk);
	reset = 1'b0;
	while (!ready && timeout < 30000) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	if (!ready) $fatal(1, "SDRAM initialization timeout");

	@(negedge clk);
	video_dma_req = ~video_dma_req;
	timeout = 0;
	while ((video_dma_ack != video_dma_req) && timeout < 100) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	if (video_dma_ack != video_dma_req)
		$fatal(1, "DMA timeout state=%0d", dut.state);
	if (video_dma_data !== 64'h7788_5566_3344_1122)
		$fatal(1, "DMA row=%h", video_dma_data);
	$display("PASS gd_sdram captured one CAS-3 burst-of-4 graphics row in %0d clocks",
	         timeout);
	$finish;
end
endmodule
