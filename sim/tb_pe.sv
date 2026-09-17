`timescale 1ns/1ps

module tb_pe;
	parameter WIDTH   = 8;
	parameter A_WIDTH = 32;

	logic clk;
	logic rst;
	logic ld_w;
	logic signed [WIDTH-1:0]   x_in;
	logic signed [A_WIDTH-1:0] y_in;
	logic signed [WIDTH-1:0]   x_out;
	logic signed [A_WIDTH-1:0] y_out;

	integer checks_completed;
	integer error_count;

	pe #(
		.WIDTH(WIDTH),
		.A_WIDTH(A_WIDTH))
	dut (
		.clk(clk),
		.rst(rst),
		.ld_w(ld_w),
		.x_in(x_in),
		.y_in(y_in),
		.x_out(x_out),
		.y_out(y_out)
	);

	task automatic check_pe(
		input string test_name,
		input logic signed [WIDTH-1:0] expected_x,
		input logic signed [A_WIDTH-1:0] expected_y
	);
		checks_completed++;
		if ((x_out !== expected_x) || (y_out !== expected_y)) begin
			error_count++;
			$error("[FAIL] %s: x_out=%0d, y_out=%0d; expected x_out=%0d, y_out=%0d",
			       test_name, $signed(x_out), $signed(y_out), expected_x, expected_y);
		end
		else begin
			$display("[PASS] %s: x_out=%0d, y_out=%0d",
			         test_name, $signed(x_out), $signed(y_out));
		end
	endtask

	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end

	initial begin
		$dumpfile("pe.vcd");
		$dumpvars(0, tb_pe);

		rst = 0;
		ld_w = 0;
		x_in = 0;
		y_in = 0;
		checks_completed = 0;
		error_count = 0;

		#1;
		check_pe("asynchronous reset", '0, '0);

		repeat(2) @(negedge clk);
		rst = 1;

		@(negedge clk);
		ld_w = 1;
		x_in = 5;
		y_in = 0;
		@(posedge clk);
		#1;
		check_pe("load positive weight", 8'sd5, 32'sd0);

		@(negedge clk);
		ld_w = 0;
		x_in = 2;
		y_in = 0;
		@(posedge clk);
		#1;
		check_pe("positive multiply", 8'sd2, 32'sd10);

		@(negedge clk);
		x_in = 3;
		y_in = 20;
		@(posedge clk);
		#1;
		check_pe("incoming partial sum", 8'sd3, 32'sd35);

		@(negedge clk);
		ld_w = 1;
		x_in = -7;
		y_in = 0;
		@(posedge clk);
		#1;
		check_pe("load negative weight", -8'sd7, 32'sd0);

		@(negedge clk);
		ld_w = 0;
		x_in = 6;
		y_in = 10;
		@(posedge clk);
		#1;
		check_pe("negative product", 8'sd6, -32'sd32);

		@(negedge clk);
		x_in = -8;
		y_in = -5;
		@(posedge clk);
		#1;
		check_pe("two negative operands", -8'sd8, 32'sd51);

		#2;
		rst = 0;
		#1;
		check_pe("reset while active", '0, '0);

		if (error_count == 0) begin
			$display("PE SELF-CHECK PASSED: %0d checks completed", checks_completed);
			$finish;
		end
		else begin
			$fatal(1, "PE SELF-CHECK FAILED: %0d of %0d checks failed",
			       error_count, checks_completed);
		end
	end
endmodule
