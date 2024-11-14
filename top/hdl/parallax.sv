`timescale 1ns / 1ps
`default_nettype none

// takes two points in terms of x and y and returns the depth in inches using stereo vision
// Focal length and baseline distance in inches
// Resolution is assuming 1280x720
// Sensor width of the camera in inches
// Takes two cycles to compute
module parallax #(parameter RESOLUTION_WIDTH = 1280, parameter SENSOR_WIDTH = 0.334646, parameter FOCAL_LENGTH = 0.1295276, parameter BASELINE_DISTANCE = 6)(
  input wire clk_in,
  input wire rst_in,
  input wire [11:0] x_1_in, x_2_in,
  output logic [11:0] depth_out
);

  // Need to get the pixels per inch of sensor then multiply by the focal length
  localparam PIXELS_PER_INCH = RESOLUTION_WIDTH / SENSOR_WIDTH;
  
  // Pre-compute numerator: (Focal Length * Baseline Distance * Pixels/Inch)
  // This gives us a scaling factor in pixel-inches that we'll divide by the disparity
  localparam PARALLAX_SCALE = PIXELS_PER_INCH * FOCAL_LENGTH * BASELINE_DISTANCE;

  // Z (depth in inches) = (Focal Length * Baseline Distance * Pixels/Inch) / (x_1 - x_2)
  // where (x_1 - x_2) is the disparity in pixels between left and right images
  logic [11:0] disparity;
  
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      depth_out <= 0;
    end else begin
      // Calculate disparity (difference in x coordinates between images)
      disparity <= (x_1_in > x_2_in) ? (x_1_in - x_2_in) : (x_2_in - x_1_in); // absolute value
      
      // Final depth calculation
      depth_out <= (disparity == 0) ? 8'hFF : PARALLAX_SCALE / disparity;
    end
  end
endmodule


`default_nettype wire

