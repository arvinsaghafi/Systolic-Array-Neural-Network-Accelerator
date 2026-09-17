`timescale 1ns/1ps

module pe #(
	parameter WIDTH = 8,	  // Width of input data (INT8)
	parameter A_WIDTH = 32 // Width of accumulator
)(
	input  logic                      clk,
	input  logic                      rst,
	input  logic                      ld_w,
	input  logic signed [WIDTH-1:0]   x_in,
	input  logic signed [A_WIDTH-1:0] y_in,
	output logic signed [WIDTH-1:0]   x_out,
	output logic signed [A_WIDTH-1:0] y_out
);
// Computing y_out = y_in + w * x_in, where:
// x_in  is the data
// y_in  is the incoming partial sum
// w     is the weight stored in the PE
// x_out is the output data passed to the next PE
// y_out is the updated partial sum

	logic signed [WIDTH-1:0] w_reg;
	logic signed [(2*WIDTH)-1:0] product;
	logic signed [A_WIDTH-1:0] product_extended;
	
	assign product = x_in * w_reg;
	assign product_extended = {{(A_WIDTH-(2*WIDTH)){product[(2*WIDTH)-1]}}, product};
	
	always_ff @(posedge clk or negedge rst) begin
		if (!rst) begin
			x_out	<= '0;
			y_out <= '0;
			w_reg <= '0;
		end
		else begin
			if (ld_w) begin
				w_reg <= x_in;
				x_out <= x_in;
				y_out <= y_in;
			end
			else begin
			x_out <= x_in;
			y_out <= y_in + product_extended;
			end
		end
	end
endmodule
