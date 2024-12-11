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
  input wire data_valid_in,
  input wire [11:0] x_1_in, x_2_in,
  output logic [7:0] depth_out
);
  // TODO: Parallax scale can be >8 bits and disparity can be as low as 1 so depth can be 
  // more than 8 bits. Need to handle by tuning parameters well to avoid overflow or something else.

  // Need to get the pixels per inch of sensor then multiply by the focal length
  localparam PIXELS_PER_INCH = RESOLUTION_WIDTH / SENSOR_WIDTH;
  
  // Pre-compute numerator: (Focal Length * Baseline Distance * Pixels/Inch)
  // This gives us a scaling factor in pixel-inches that we'll divide by the disparity
  localparam PARALLAX_SCALE = PIXELS_PER_INCH * FOCAL_LENGTH * BASELINE_DISTANCE;

  // Z (depth in inches) = (Focal Length * Baseline Distance * Pixels/Inch) / (x_1 - x_2)
  // where (x_1 - x_2) is the disparity in pixels between left and right images
  logic [11:0] disparity;
  assign disparity = (x_1_in > x_2_in) ? (x_1_in - x_2_in) : (x_2_in - x_1_in); // absolute value

  logic div_valid_in;
  logic [11:0] div_data_out;
  logic div_valid_out;
  divider disparity_divider(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(PARALLAX_SCALE),
    .divisor_in(disparity),
    .data_valid_in(div_valid_in),
    .quotient_out(div_data_out),
    .remainder_out(),
    .data_valid_out(div_valid_out),
    .error_out(),
    .busy_out()
  );
  
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      depth_out <= 0;
      div_valid_in <= 0;
    end else begin      
      if (data_valid_in && disparity != 0) begin
        div_valid_in <= 1'b1;
      end else if (data_valid_in && disparity == 0) begin
        div_valid_in <= 1'b0;
        depth_out <= 8'hFF;
      end else begin
        div_valid_in <= 1'b0;
      end

      if (div_valid_out) begin
        depth_out <= div_data_out;
      end
    end
  end
endmodule


`default_nettype wire

