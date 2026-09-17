`timescale 1ns/1ps

module systolic_array #(
	parameter ROWS    = 4,
	parameter COLS    = 4,
	parameter WIDTH   = 8,
	parameter A_WIDTH = 32
)(
	input  logic clk,
	input  logic rst,
	input  logic ld_w,
	input  var logic signed [WIDTH-1:0]   input_x  [0:ROWS-1],
	input  var logic signed [A_WIDTH-1:0] input_y  [0:COLS-1],
	output logic signed [A_WIDTH-1:0] output_y [0:COLS-1]
);

	logic signed [WIDTH-1:0]   wire_x [0:ROWS-1][0:COLS];
	logic signed [A_WIDTH-1:0] wire_y [0:ROWS][0:COLS-1];
	
	genvar i, j;
	generate
		for (i = 0; i < ROWS; i++) begin: left_edge_connections
			assign wire_x[i][0] = input_x[i];
		end
		
		for (j = 0; j < COLS; j++) begin: top_edge_connections
			assign wire_y[0][j] = input_y[j];
		end
	endgenerate
	
	generate
		for (i = 0; i < ROWS; i++) begin: row_loop
			for (j = 0; j < COLS; j++) begin: col_loop
				pe #(
					.WIDTH(WIDTH),
					.A_WIDTH(A_WIDTH))
				pe_instance (
					.clk   (clk),
					.rst   (rst),
					.ld_w  (ld_w),
					.x_in  (wire_x[i][j]),
					.y_in  (wire_y[i][j]),
					.x_out (wire_x[i][j+1]),
					.y_out (wire_y[i+1][j])
				);
			end
		end
	endgenerate
	
	generate
		for (j = 0; j < COLS; j++) begin: bottom_edge_connections
			assign output_y[j] = wire_y[ROWS][j];
		end
	endgenerate
endmodule
