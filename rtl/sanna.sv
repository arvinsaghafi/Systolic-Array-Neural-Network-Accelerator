`timescale 1ns/1ps

module sanna #(
	parameter ROWS    = 4,
	parameter COLS    = 4,
	parameter WIDTH   = 8,
	parameter A_WIDTH = 32
)(
	input logic clk,
	input logic rst,
	input logic ld_w,
	input logic input_valid,
	input var logic signed [WIDTH-1:0] memory_data_in [0:ROWS-1],
	input var logic signed [A_WIDTH-1:0] top_in_sum [0:COLS-1],
	output logic signed [A_WIDTH-1:0] final_results [0:COLS-1],
	output logic output_valid [0:COLS-1]
);

	localparam VALID_STAGES = ROWS + COLS - 1;

	logic signed [WIDTH-1:0] skew_input_wires [0:ROWS-1];
	logic signed [WIDTH-1:0] skewed_wires [0:ROWS-1];
	logic signed [WIDTH-1:0] array_in_wires [0:ROWS-1];
	logic [VALID_STAGES-1:0] valid_pipe;

	// Weight data bypasses the activation skew buffer during weight loading.
	genvar i;
	generate
		for (i = 0; i < ROWS; i++) begin: input_mode_mux
			assign skew_input_wires[i] = ld_w ? '0 : memory_data_in[i];
			assign array_in_wires[i] = ld_w ? memory_data_in[i] : skewed_wires[i];
		end
	endgenerate

	// Track each input vector as it moves through the systolic array.
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) begin
			valid_pipe <= '0;
		end
		else if (ld_w) begin
			valid_pipe <= '0;
		end
		else begin
			valid_pipe[0] <= input_valid;

			for (int k = 1; k < VALID_STAGES; k++) begin
				valid_pipe[k] <= valid_pipe[k-1];
			end
		end
	end

	// Column j produces a valid result after ROWS - 1 + j cycles.
	genvar j;
	generate
		for (j = 0; j < COLS; j++) begin: output_valid_gen
			assign output_valid[j] = valid_pipe[ROWS-1+j];
		end
	endgenerate

	input_skew #(
		.ROWS(ROWS),
		.WIDTH(WIDTH)
	) u_skew (
		.clk(clk),
		.rst(rst),
		.flat_data_in(skew_input_wires),
		.skewed_data_out(skewed_wires)
	);

	systolic_array #(
		.ROWS(ROWS),
		.COLS(COLS),
		.WIDTH(WIDTH),
		.A_WIDTH(A_WIDTH)
	) u_array (
		.clk(clk),
		.rst(rst),
		.ld_w(ld_w),
		.input_x(array_in_wires),
		.input_y(top_in_sum),
		.output_y(final_results)
	);

endmodule