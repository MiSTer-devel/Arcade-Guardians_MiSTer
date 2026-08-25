`timescale 1ns/1ps

module tb_gd_sdram_dma;
logic clk = 1'b0;
logic reset = 1'b1;
tri [15:0] SDRAM_DQ;
logic [15:0] external_dq = 16'h0000;
wire [12:0] SDRAM_A;
wire [1:0] SDRAM_BA;
wire SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH;
wire SDRAM_nCS, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS;
logic [24:0] mem_addr = 25'd0;
logic [15:0] mem_din = 16'd0;
logic [1:0] mem_be = 2'b11;
logic mem_burst = 1'b0;
logic [63:0] mem_burst_data = 64'd0;
logic mem_rnw = 1'b1;
logic mem_req = 1'b0;
logic [15:0] mem_dout;
logic mem_ack;
logic video_dma_req = 1'b0;
logic [24:0] video_dma_addr = 25'h0123400;
logic video_dma_ack;
logic [63:0] video_dma_data;
logic ready;

integer sdram_cycle = 0;
integer read_start0 = -100;
integer read_start1 = -100;
integer read_command_count = 0;
integer timeout = 0;
integer write_count = 0;
integer first_dma_clocks = 0;
integer same_row_dma_clocks = 0;
integer cross_row_dma_clocks = 0;
logic [15:0] written_word [0:3];
logic [8:0] written_column [0:3];
logic [1:0] written_bank [0:3];
logic written_autoprecharge [0:3];

always #4.365 clk = ~clk;

gd_sdram dut(.*);
assign SDRAM_DQ = dut.dq_oe ? 16'hzzzz : external_dq;

// Minimal CAS-3, burst-length-4 SDRAM read model. Commands are sampled on
// the forwarded SDRAM clock and returned data is changed on that same edge,
// leaving it centered around the controller's following clk rising edge.
always @(posedge SDRAM_CLK) begin
	sdram_cycle = sdram_cycle + 1;
	if ({SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} == 3'b100) begin
		written_word[write_count] = dut.dq_out;
		written_column[write_count] = SDRAM_A[8:0];
		written_bank[write_count] = SDRAM_BA;
		written_autoprecharge[write_count] = SDRAM_A[10];
		write_count = write_count + 1;
	end
	if ({SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} == 3'b101) begin
		if ((read_command_count & 1) == 0)
			read_start0 = sdram_cycle + 3;
		else
			read_start1 = sdram_cycle + 3;
		read_command_count = read_command_count + 1;
	end
	if ((sdram_cycle >= read_start0) && (sdram_cycle < read_start0 + 4)) begin
		case (sdram_cycle - read_start0)
			0: external_dq = 16'h1122;
			1: external_dq = 16'h3344;
			2: external_dq = 16'h5566;
			default: external_dq = 16'h7788;
		endcase
	end
	else if ((sdram_cycle >= read_start1)
	         && (sdram_cycle < read_start1 + 4)) begin
		case (sdram_cycle - read_start1)
			0: external_dq = 16'h1122;
			1: external_dq = 16'h3344;
			2: external_dq = 16'h5566;
			default: external_dq = 16'h7788;
		endcase
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
	first_dma_clocks = timeout;

	// Production graphics reads use auto-precharge, so a second line in the
	// same physical SDRAM row must complete with the same bounded latency.
	@(negedge clk);
	video_dma_addr = video_dma_addr + 25'd8;
	video_dma_req = ~video_dma_req;
	timeout = 0;
	while ((video_dma_ack != video_dma_req) && timeout < 100) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	same_row_dma_clocks = timeout;
	if (video_dma_ack != video_dma_req)
		$fatal(1, "same-row DMA timeout state=%0d", dut.state);
	if (same_row_dma_clocks != first_dma_clocks)
		$fatal(1, "closed-page DMA latency changed first=%0d same=%0d",
		       first_dma_clocks, same_row_dma_clocks);

	// Crossing the 1 KiB row boundary uses the same auto-precharged sequence
	// and must still return the complete burst correctly.
	@(negedge clk);
	video_dma_addr = video_dma_addr + 25'h0000400;
	video_dma_req = ~video_dma_req;
	timeout = 0;
	while ((video_dma_ack != video_dma_req) && timeout < 100) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	cross_row_dma_clocks = timeout;
	if (video_dma_ack != video_dma_req
	    || video_dma_data !== 64'h7788_5566_3344_1122)
		$fatal(1, "cross-row DMA failed clocks=%0d data=%h state=%0d",
		       cross_row_dma_clocks, video_dma_data, dut.state);

	if (cross_row_dma_clocks != first_dma_clocks)
		$fatal(1, "closed-page cross-row latency changed first=%0d cross=%0d",
		       first_dma_clocks, cross_row_dma_clocks);

	// Four loader words share one ACTIVE row but each receives a real WRITE
	// command because the mode register selects single-location write bursts.
	@(negedge clk);
	mem_addr = 25'h0012340;
	mem_burst_data = 64'h7788_5566_3344_1122;
	mem_burst = 1'b1;
	mem_rnw = 1'b0;
	mem_req = ~mem_req;
	timeout = 0;
	while ((mem_ack != mem_req) && timeout < 100) begin
		@(posedge clk);
		timeout = timeout + 1;
	end
	if (mem_ack != mem_req) $fatal(1, "loader block-write timeout");
	if (write_count != 4)
		$fatal(1, "loader issued %0d WRITE commands instead of four", write_count);
	if (written_word[0] !== 16'h1122 || written_word[1] !== 16'h3344
	    || written_word[2] !== 16'h5566 || written_word[3] !== 16'h7788)
		$fatal(1, "loader write data %h %h %h %h", written_word[0],
		       written_word[1], written_word[2], written_word[3]);
	for (timeout = 0; timeout < 4; timeout = timeout + 1) begin
		if (written_column[timeout] !== (mem_addr[9:1] + timeout))
			$fatal(1, "loader column[%0d]=%h", timeout,
			       written_column[timeout]);
		if (written_bank[timeout] !== mem_addr[24:23])
			$fatal(1, "loader bank[%0d]=%h", timeout, written_bank[timeout]);
		if (written_autoprecharge[timeout] !== (timeout == 3))
			$fatal(1, "loader auto-precharge[%0d]=%b", timeout,
			       written_autoprecharge[timeout]);
	end
	$display("PASS gd_sdram DMA closed-page and four-command block writes");
	$finish;
end
endmodule
