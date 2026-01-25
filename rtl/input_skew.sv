module input_skew #(
	parameter ROWS  = 4,
	parameter WIDTH = 8
)(
	input  logic clk,
	input  logic rst,
	input  logic signed [WIDTH-1:0] flat_data_in    [0:ROWS-1],
	output logic signed [WIDTH-1:0] skewed_data_out [0:ROWS-1]
);

	genvar i;
	generate
		for (i = 0; i < ROWS; i++) begin: row_delay_gen
			if (i == 0) begin
				assign skewed_data_out[0] = flat_data_in[0];
			end
			else begin
				logic signed [WIDTH-1:0] delay_chain [0:i-1];
				
				always_ff @(posedge clk or negedge rst) begin
					if (!rst) begin
						for (int k = 0; k < i; k++) begin
							delay_chain[k] <= '0;
						end
					end
					else begin
						delay_chain[0] <= flat_data_in[i];
						for (int k = 1; k < i; k++) begin
							delay_chain[k] <= delay_chain[k-1];
						end
					end
				end
				assign skewed_data_out[i] = delay_chain[i-1];
			end
		end
	endgenerate
endmodule