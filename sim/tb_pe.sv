`timescale 1ns/1ps

module tb_pe;
	parameter WIDTH = 8;
	parameter A_WIDTH = 32;
	
	logic clk;
	logic rst;
	logic ld_w;
	
	logic signed [WIDTH-1:0]   x_in;
	logic signed [A_WIDTH-1:0] y_in;
	
	logic signed [WIDTH-1:0]   x_out;
	logic signed [A_WIDTH-1:0] y_out;
	
	pe #(.WIDTH(WIDTH),
	     .A_WIDTH(A_WIDTH))
	dut (.clk(clk),
	     .rst(rst),
		  .ld_w(ld_w),
		  .x_in(x_in),
		  .y_in(y_in),
		  .x_out(x_out),
		  .y_out(y_out)
	);
	
	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end
	
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars;
		
		// Initialize inputs
		rst  = 0;
		ld_w = 0;
		x_in = 0;
		y_in = 0;
		
		// Reset sequence
		$display("Starting simulation");
		#15;
		rst = 1;
		#5;
		
		// Test case 1: Load weight
		$display("[Time %0t] loading weight: 5", $time);
		ld_w = 1;
		x_in = 5;
		y_in = 0;
		
		@(posedge clk);
		#1;
		
		// Test case 2: Compute
		$display("[Time %0t] loading weight: 5", $time);
		ld_w = 0;
		x_in = 2;
		y_in = 0;
		
		@(posedge clk);
		#1;
		
		@(posedge clk);
		#1;
		if (y_out == 10)
			$display("[PASS] Output: %0d (Expected 10)", y_out);
		else
			$display("[FAIL] Output: %0d (Expected 10)", y_out);
			
		$display("[Time %0t] Input A: 3, Input sum: 20", $time);
		ld_w = 0;
		x_in = 3;
		y_in = 20;
		
		@(posedge clk)
		#1;
		if (y_out == 35)
			$display("[PASS] Output: %0d (Expected 35)", y_out);
		else
			$display("[FAIL] Output: %0d (Expected 35)", y_out);
			
		#10;
		$display("Simulation complete");
		$finish;
	end
endmodule
		