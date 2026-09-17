`timescale 1ns/1ps

module tb_sanna;

	parameter ROWS        = 4;
	parameter COLS        = 4;
	parameter WIDTH       = 8;
	parameter A_WIDTH     = 32;
	parameter FC1_INPUTS  = 784;
	parameter FC1_OUTPUTS = 64;
	parameter NUM_WEIGHTS = FC1_INPUTS * FC1_OUTPUTS;
	parameter IMG_SIZE    = FC1_INPUTS;

	localparam NUM_VECTORS        = 2;
	localparam SECOND_VECTOR_BASE = 202;
	localparam MONITOR_CYCLES     = ROWS + COLS + NUM_VECTORS - 2;

	logic clk;
	logic rst;
	logic ld_w;
	logic input_valid;

	logic signed [WIDTH-1:0] memory_data_in [0:ROWS-1];
	logic signed [A_WIDTH-1:0] top_in_sum [0:COLS-1];
	logic signed [A_WIDTH-1:0] final_results [0:COLS-1];
	logic output_valid [0:COLS-1];

	logic [7:0] ram_weights [0:NUM_WEIGHTS-1];
	logic [7:0] ram_image [0:IMG_SIZE-1];

	integer signed expected_results [0:NUM_VECTORS-1][0:COLS-1];

	integer i;
	integer k;
	integer vector_index;
	integer cycle;
	integer error_count;
	integer result_checks;
	integer weights_file;
	integer image_file;

	sanna #(
		.ROWS(ROWS),
		.COLS(COLS),
		.WIDTH(WIDTH),
		.A_WIDTH(A_WIDTH)
	) dut (
		.clk(clk),
		.rst(rst),
		.ld_w(ld_w),
		.input_valid(input_valid),
		.memory_data_in(memory_data_in),
		.top_in_sum(top_in_sum),
		.final_results(final_results),
		.output_valid(output_valid)
	);

	function automatic integer signed signed_byte(input logic [7:0] value);
		signed_byte = {24'b0, value};
		if (value[7]) signed_byte -= 256;
	endfunction

	function automatic integer pixel_index(input integer vector_number, input integer row);
		pixel_index = (vector_number == 0) ? row : SECOND_VECTOR_BASE + row;
	endfunction

	task automatic check_cycle(input integer cycle_index);
		integer col;
		integer expected_vector;
		logic expected_valid;

		for (col = 0; col < COLS; col++) begin
			expected_vector = cycle_index - (ROWS - 1 + col);
			expected_valid = (expected_vector >= 0) && (expected_vector < NUM_VECTORS);

			if (output_valid[col] !== expected_valid) begin
				error_count++;
				$error("[FAIL] Cycle %0d, column %0d: output_valid=%b, expected=%b", cycle_index, col, output_valid[col], expected_valid);
			end

			if ((output_valid[col] === 1'b1) && expected_valid) begin
				result_checks++;

				if (final_results[col] !== expected_results[expected_vector][col]) begin
					error_count++;
					$error("[FAIL] Vector %0d, column %0d: result=%0d, expected=%0d", expected_vector, col, $signed(final_results[col]), expected_results[expected_vector][col]);
				end
				else begin
					$display("[PASS] Vector %0d, column %0d: result=%0d at pipeline cycle %0d", expected_vector, col, $signed(final_results[col]), cycle_index);
				end
			end
		end
	endtask

	initial begin
		clk = 0;
		forever #5 clk = ~clk;
	end

	initial begin
		$dumpfile("sanna.vcd");
		$dumpvars(0, tb_sanna);

		weights_file = $fopen("software/fc1_weights.txt", "r");
		if (weights_file == 0) $fatal(1, "Unable to open software/fc1_weights.txt");
		$fclose(weights_file);

		image_file = $fopen("software/test_image.txt", "r");
		if (image_file == 0) $fatal(1, "Unable to open software/test_image.txt");
		$fclose(image_file);

		$readmemh("software/fc1_weights.txt", ram_weights);
		$readmemh("software/test_image.txt", ram_image);

		rst = 0;
		ld_w = 0;
		input_valid = 0;
		error_count = 0;
		result_checks = 0;

		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;
		for (i = 0; i < COLS; i++) top_in_sum[i] = 0;

		// Calculate the expected results for the first FC1 weight tile.
		for (vector_index = 0; vector_index < NUM_VECTORS; vector_index++) begin
			for (k = 0; k < COLS; k++) begin
				expected_results[vector_index][k] = 0;

				for (i = 0; i < ROWS; i++) begin
					expected_results[vector_index][k] += signed_byte(ram_image[pixel_index(vector_index, i)]) * signed_byte(ram_weights[(i * FC1_OUTPUTS) + k]);
				end
			end
		end

		repeat (2) @(negedge clk);
		rst = 1;

		// Load the first 4x4 weight tile in reverse column order.
		$display("[Time %0t] Loading first %0dx%0d FC1 weight tile", $time, ROWS, COLS);

		for (k = COLS - 1; k >= 0; k--) begin
			@(negedge clk);
			ld_w = 1;

			for (i = 0; i < ROWS; i++) begin
				memory_data_in[i] = ram_weights[(i * FC1_OUTPUTS) + k];
			end
		end

		@(negedge clk);
		ld_w = 0;

		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;

		// Stream two input vectors through the array without a gap.
		$display("[Time %0t] Injecting %0d back-to-back %0d-element input vectors", $time, NUM_VECTORS, ROWS);

		for (vector_index = 0; vector_index < NUM_VECTORS; vector_index++) begin
			@(negedge clk);
			input_valid = 1;

			for (i = 0; i < ROWS; i++) begin
				memory_data_in[i] = ram_image[pixel_index(vector_index, i)];
			end

			@(posedge clk);
			#1;
			check_cycle(vector_index);
		end

		@(negedge clk);
		input_valid = 0;

		for (i = 0; i < ROWS; i++) memory_data_in[i] = 0;

		// Wait for both vectors to move through every output column.
		for (cycle = NUM_VECTORS; cycle <= MONITOR_CYCLES; cycle++) begin
			@(posedge clk);
			#1;
			check_cycle(cycle);
		end

		if (result_checks != (NUM_VECTORS * COLS)) begin
			error_count++;
			$error("[FAIL] Checked %0d results; expected %0d", result_checks, NUM_VECTORS * COLS);
		end

		if (error_count == 0) begin
			$display("SANNA SELF-CHECK PASSED: %0d results from %0d back-to-back vectors verified", result_checks, NUM_VECTORS);
			$finish;
		end
		else begin
			$fatal(1, "SANNA SELF-CHECK FAILED: %0d errors", error_count);
		end
	end

endmodule