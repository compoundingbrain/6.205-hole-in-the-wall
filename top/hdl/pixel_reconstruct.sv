`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct #( parameter HCOUNT_WIDTH = 11, parameter VCOUNT_WIDTH = 10)
	(
	 input wire 									    clk_in,
	 input wire 										rst_in,
	 input wire 										camera_pclk_in,
	 input wire 										camera_hs_in,
	 input wire 										camera_vs_in,
	 input wire [7:0] 							        camera_data_in,
	 output logic 									    pixel_valid_out,
	 output logic [HCOUNT_WIDTH-1:0]                    pixel_hcount_out,
	 output logic [VCOUNT_WIDTH-1:0]                    pixel_vcount_out,
	 output logic [15:0] 						        pixel_data_out
	 );

	 // your code here! and here's a handful of logics that you may find helpful to utilize.
	 
	 // previous value of PCLK
	 logic pclk_prev;

	 // can be assigned combinationally:
	 //  true when pclk transitions from 0 to 1
	 logic camera_sample_valid;
	 assign camera_sample_valid = ~pclk_prev & camera_pclk_in; // TODO: fix this assign
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic last_sampled_hs;
     logic last_sampled_vs;
	 logic [7:0] last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic half_pixel_ready;

	logic [HCOUNT_WIDTH-1: 0] hcount;
	logic [VCOUNT_WIDTH-1: 0] vcount;
	assign pixel_hcount_out = hcount - 1;
	assign pixel_vcount_out = vcount;

	enum {ACTIVE, HSYNC, VSYNC} state;

	always_ff@(posedge clk_in) begin
		pixel_valid_out <= 1'b0;

		if (rst_in) begin
			state <= ACTIVE;
			pclk_prev <= 0;
			last_sampled_data <= 0;
			last_sampled_hs <= 0;
			last_sampled_vs <= 0;
			half_pixel_ready <= 0;
			hcount <= 0;
			vcount <= 0;

		end else begin
			pclk_prev <= camera_pclk_in;

			if(camera_sample_valid) begin
				last_sampled_hs <= camera_hs_in;
				last_sampled_vs <= camera_vs_in;
				last_sampled_data <= camera_data_in;

				case(state)
					ACTIVE: begin
						if(camera_hs_in & camera_vs_in) begin
							half_pixel_ready <= half_pixel_ready ^ 1;

							if (half_pixel_ready) begin
								pixel_valid_out <= 1'b1;
								pixel_data_out <= {last_sampled_data, camera_data_in};
								hcount <= hcount + 1;
							end
						end
						else if (last_sampled_hs & ~camera_hs_in) begin
							state <= HSYNC;
						end

					end
					HSYNC: begin
						if (last_sampled_vs & ~camera_vs_in)
							state <= VSYNC;
						else if (~last_sampled_hs & camera_hs_in) begin
							state <= ACTIVE;
							hcount <= 0;
							vcount <= vcount + 1;
							// make sure to count data_in immediatly on hsync rising 
							half_pixel_ready <= 1;
						end

					end
					VSYNC: begin
						if (~last_sampled_vs & camera_vs_in) begin
							state <= ACTIVE;
							hcount <= 0;
							vcount <= 0;
							half_pixel_ready <= 1;
						end

					end
				endcase
			end	 
		end
	end
endmodule

`default_nettype wire