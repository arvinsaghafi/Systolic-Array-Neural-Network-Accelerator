`timescale 1ns/1ps

module tb_sanna;
	parameter ROWS        = 4;
	parameter COLS        = 4;
	parameter WIDTH       = 8;
	parameter A_WIDTH     = 32;
	parameter NUM_WEIGHTS = 50176;
	parameter IMG_SIZE    = 784;
	
	logic clk;
	logic rst;
	logic ld_w;
	logic signed [WIDTH-1:0]   memory_data_in [0:ROWS-1];
	logic signed [A_WIDTH-1:0] top_in_sum     [0:ROWS-1];
	logic signed [A_WIDTH-1:0] final_results  [0:ROWS-1];
	
	// Simulation memory to hold file data
	logic [7:0] ram_weights [0:NUM_WEIGHTS-1];
	logic [7:0] ram_image   [0:IMG_SIZE-1];
	
	sanna #(
		.ROWS(ROWS),
		.COLS(COLS),
		.WIDTH(WIDTH),
		.A_WIDTH(A_WIDTH))
	dut (
		.clk(clk),
		.rst(rst),
		.ld_w(ld_w),
		.memory_data_in(memory_data_in),
		.top_in_sum(top_in_sum),
		.final_results(final_results)
	);
	
	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end
	
	integer i, k;
	
	initial begin
		$dumpfile("sanna.vcd");
		$dumpvars;
		
		$readmemh("fc1_weights.txt", ram_weights);
		$readmemh("test_image.txt", ram_image);
		
		$display("File load check");
		$display("Weight[0]: %h", ram_weights[0]);
		$display("Pixel[0]: %h", ram_image[0]);
		
		rst = 0;
		ld_w = 0;
		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;
		for (i = 0; i < COLS; i++) top_in_sum[i] = 0;
		
		// Deassert reset away from the active clock edge.
		repeat(2) @(negedge clk);
		rst = 1;
		
		// Load weights
		$display("[Time %0t], start weight load (First 4x4 tile)", $time);
		for (k = 3; k >= 0; k--) begin
			@(negedge clk);
			ld_w = 1;
			memory_data_in[0] = ram_weights[k + 0];
			memory_data_in[1] = ram_weights[k + 4];
			memory_data_in[2] = ram_weights[k + 8];
			memory_data_in[3] = ram_weights[k + 12];
		end
		
		// Stop loading before the next rising edge. Additional load cycles would
		// shift zeros into the PE weight registers and overwrite valid weights.
		@(negedge clk);
		ld_w = 0;
		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;
		$display("[Time %0t], weights loaded", $time);
		
		// Compute
		$display("[Time %0t], start compute", $time);
		for (k = 0; k < 4; k++) begin
			@(negedge clk);
			memory_data_in[0] = ram_image[k + 0];
			memory_data_in[1] = ram_image[k + 4];
			memory_data_in[2] = ram_image[k + 8];
			memory_data_in[3] = ram_image[k + 12];
		end
		
		@(negedge clk);
		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;
		repeat(15) @(posedge clk);
		$display("[Time %0t], start compute", $time);
		$finish;
	end
endmodule
