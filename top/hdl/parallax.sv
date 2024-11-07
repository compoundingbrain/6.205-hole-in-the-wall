`timescale 1ns / 1ps
`default_nettype none

// takes two points in terms of x and y and returns the depth in inches using stereo vision
// Focal length and baseline distance in inches
module parallax #(parameter FOCAL_LENGTH = 1, parameter BASELINE_DISTANCE = 1)(
  input wire clk_in,
  input wire rst_in,
  input wire [11:0] x_1_in, x_2_in,
  output logic [7:0] depth_out
);

  localparam FOCAL_LENGTH_X_BASELINE_DIST = FOCAL_LENGTH * BASELINE_DISTANCE;

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      depth_out <= 0;
    end else begin
      depth_out <= (FOCAL_LENGTH_X_BASELINE_DIST) / (x_1_in - x_2_in);
    end
  end
endmodule


`default_nettype wire
