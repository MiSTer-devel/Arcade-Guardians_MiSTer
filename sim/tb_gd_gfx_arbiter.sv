`timescale 1ns/1ps

module tb_gd_gfx_arbiter;
logic clk = 0;
always #5 clk = ~clk;
logic reset = 1;
logic cache_flush = 0;
logic [24:0] loader_addr = 0;
logic [15:0] loader_din = 0;
logic [1:0] loader_be = 0;
logic loader_rnw = 0;
logic loader_req = 0;
logic [15:0] loader_dout;
logic loader_ack;
logic [24:0] renderer_addr = 0;
logic renderer_req = 0;
logic [63:0] renderer_dout;
logic renderer_ack;
logic [24:0] mem_addr;
logic [15:0] mem_din;
logic [1:0] mem_be;
logic mem_rnw;
logic mem_req;
logic [15:0] mem_dout = 0;
logic mem_ack = 0;
logic [24:0] dma_addr;
logic dma_req;
logic [63:0] dma_data = 0;
logic dma_ack = 0;

gd_gfx_arbiter dut(.*);

task automatic renderer_read(
	input [24:0] address,
	input [63:0] expected
);
	begin
		renderer_addr <= address;
		renderer_req <= ~renderer_req;
		do @(posedge clk); while (renderer_ack != renderer_req);
		if (renderer_dout !== expected)
			$fatal(1, "renderer row %h returned %h", address,
			       renderer_dout);
	end
endtask

logic first_dma_toggle;
initial begin
	repeat (5) @(posedge clk);
	reset <= 0;
	repeat (2) @(posedge clk);

	// A miss must request exactly the renderer's eight-byte row. This is the
	// latency-critical path used by the SDRAM burst-of-four port.
	renderer_addr <= 25'h0000018;
	renderer_req <= ~renderer_req;
	do @(posedge clk); while (dma_req == dma_ack);
	if (dma_addr !== 25'h0000018)
		$fatal(1, "wrong row DMA address %h", dma_addr);
	first_dma_toggle = dma_req;
	dma_data <= 64'h3333333333333333;
	dma_ack <= dma_req;
	do @(posedge clk); while (renderer_ack != renderer_req);
	if (renderer_dout !== 64'h3333333333333333)
		$fatal(1, "selected row=%h", renderer_dout);

	// Re-reading the same row must hit without another SDRAM command.
	renderer_read(25'h0000018, 64'h3333333333333333);
	if (dma_req !== first_dma_toggle)
		$fatal(1, "cached row caused another DMA request");

	$display("PASS gd_gfx_arbiter filled a demand row cache line");
	$finish;
end
endmodule
