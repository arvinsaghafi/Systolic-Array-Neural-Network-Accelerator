module sanna #(
	parameter ROWS    = 4,
	parameter COLS    = 4,
	parameter WIDTH   = 8,
	parameter A_WIDTH = 32
)(
	input  logic clk,
	input  logic rst,
	input  logic ld_w,
	input  logic signed [WIDTH-1:0]   memory_data_in [0:ROWS-1],
	input  logic signed [A_WIDTH-1:0] top_in_sum     [0:COLS-1],
	output logic signed [A_WIDTH-1:0] final_results  [0:COLS-1]
);
	logic signed [WIDTH-1:0] skewed_wires [0:ROWS-1];
	
	input_skew #(
		.ROWS(ROWS),
		.WIDTH(WIDTH))
	u_skew (
		.clk(clk),
		.rst(rst),
		.flat_data_in(memory_data_in),
		.skewed_data_out(skewed_wires)
	);
	systolic_array #(
		.ROWS(ROWS),
		.COLS(COLS),
		.WIDTH(WIDTH),
		.A_WIDTH(A_WIDTH))
	u_array (
		.clk(clk),
		.rst(rst),
		.ld_w(ld_w),
		.input_x(skewed_wires),
		.input_y(top_in_sum),
		.output_y(final_results)
	);
endmodule