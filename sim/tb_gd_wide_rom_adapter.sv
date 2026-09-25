`timescale 1ns/1ps

module tb_gd_wide_rom_adapter;
logic clk = 1'b0;
always #5 clk = ~clk;
logic reset = 1'b1;
logic wide_downloading = 1'b0;
logic wide_wr = 1'b0;
logic [26:0] wide_addr = 27'd0;
logic [15:0] wide_data = 16'd0;
logic wide_wait;
logic byte_downloading;
logic byte_wr;
logic [26:0] byte_addr;
logic [7:0] byte_data;
logic byte_wait = 1'b0;
logic [26:0] seen_addr [0:3];
logic [7:0] seen_data [0:3];
integer seen_count = 0;

gd_wide_rom_adapter dut(.*);

always_ff @(posedge clk) begin
	if (byte_wr && !byte_wait) begin
		seen_addr[seen_count] <= byte_addr;
		seen_data[seen_count] <= byte_data;
		seen_count <= seen_count + 1;
	end
end

initial begin
	repeat (3) @(negedge clk);
	reset = 1'b0;
	wide_downloading = 1'b1;
	wide_addr = 27'd0;
	wide_data = 16'h2211;
	wide_wr = 1'b1;
	@(negedge clk);
	wide_wr = 1'b0;
	if (!wide_wait || !byte_wr || byte_addr !== 27'd0
	    || byte_data !== 8'h11)
		$fatal(1, "first wide word was not serialized low-byte first");
	@(negedge clk);
	byte_wait = 1'b1;
	if (!byte_wr || byte_addr !== 27'd1 || byte_data !== 8'h22)
		$fatal(1, "second byte did not follow at the next address");
	repeat (3) @(negedge clk);
	if (seen_count != 1 || !wide_wait || byte_addr !== 27'd1)
		$fatal(1, "downstream back-pressure duplicated or dropped a byte");
	wide_downloading = 1'b0;
	if (!byte_downloading)
		$fatal(1, "download ended before the held byte drained");
	byte_wait = 1'b0;
	@(negedge clk);
	if (seen_count != 2 || byte_downloading || wide_wait)
		$fatal(1, "held byte did not complete after back-pressure");
	wide_downloading = 1'b1;
	wide_addr = 27'd2;
	wide_data = 16'h4433;
	wide_wr = 1'b1;
	@(negedge clk);
	wide_wr = 1'b0;
	wide_downloading = 1'b0;
	repeat (2) @(negedge clk);
	if (seen_count != 4 || byte_downloading
	    || seen_addr[0] !== 27'd0 || seen_data[0] !== 8'h11
	    || seen_addr[1] !== 27'd1 || seen_data[1] !== 8'h22
	    || seen_addr[2] !== 27'd2 || seen_data[2] !== 8'h33
	    || seen_addr[3] !== 27'd3 || seen_data[3] !== 8'h44)
		$fatal(1, "wide transfer order or completion is wrong");
	$display("PASS gd_wide_rom_adapter preserves byte order and back-pressure");
	$finish;
end
endmodule
