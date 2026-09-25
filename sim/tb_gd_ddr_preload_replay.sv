`timescale 1ns/1ps

module tb_gd_ddr_preload_replay;
logic clk = 0;
always #5 clk = ~clk;
logic reset = 1;
logic hps_downloading = 0;
logic hps_wr = 0;
logic [26:0] hps_addr = 0;
logic [7:0] hps_data = 0;
logic hps_wait;
logic loader_downloading;
logic loader_wr;
logic [26:0] loader_addr;
logic [7:0] loader_data;
logic loader_wait;
logic [25:0] preload_addr;
logic preload_req;
logic [63:0] preload_data = 0;
logic preload_ack = 0;
logic throttle = 0;
logic [7:0] cycle_count = 0;
integer accepted = 0;
integer reads = 0;

gd_ddr_preload_replay #(.IMAGE_BYTES(27'd16)) dut(.*);
assign loader_wait = throttle && (cycle_count[1:0] == 2'd0);

always @(posedge clk) begin
	cycle_count <= cycle_count + 8'd1;
	if (preload_req != preload_ack) begin
		preload_data <= preload_addr == 26'd0
			? 64'h0706050403020100 : 64'h0f0e0d0c0b0a0908;
		preload_ack <= preload_req;
		reads <= reads + 1;
	end
	if (loader_wr && !loader_wait) begin
		if (throttle) begin
			if (loader_addr !== accepted[26:0]
			    || loader_data !== accepted[7:0])
				$fatal(1, "replay byte %0d addr=%h data=%h",
				       accepted, loader_addr, loader_data);
		end
		accepted <= accepted + 1;
	end
end

initial begin
	repeat (3) @(negedge clk);
	reset = 0;
	// Old MRAs still stream through the adapter without any DDR reads.
	hps_downloading = 1;
	hps_wr = 1;
	hps_addr = 27'd0;
	hps_data = 8'had;
	#1;
	if (!loader_downloading || !loader_wr || loader_data != 8'had)
		$fatal(1, "streaming fallback was not passed through");
	@(negedge clk);
	hps_wr = 0;
	hps_downloading = 0;
	repeat (4) @(negedge clk);
	if (reads != 0 || loader_downloading)
		$fatal(1, "streaming fallback attempted a DDR replay");
	accepted = 0;
	throttle = 1;

	// A direct-to-DDR MRA signals download start/end but sends no ioctl bytes.
	hps_downloading = 1;
	@(negedge clk);
	hps_downloading = 0;
	if (!loader_downloading)
		$fatal(1, "direct download dropped ready before replay start");
	wait (accepted == 16);
	repeat (3) @(negedge clk);
	if (reads != 2 || accepted != 16 || loader_downloading)
		$fatal(1, "replay incomplete reads=%0d bytes=%0d busy=%b",
		       reads, accepted, loader_downloading);
	$display("PASS gd_ddr_preload_replay streamed and replayed staged DDR bytes");
	$finish;
end

initial begin
	#10000;
	$fatal(1, "timeout");
end
endmodule
