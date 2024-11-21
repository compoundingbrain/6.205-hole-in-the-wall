`timescale 1ns / 1ps
`default_nettype none
module wall_depth_sprite #(
  parameter GOAL_DEPTH=60, GOAL_DEPTH_DELTA=10, MAX_WALL_DEPTH=75,
  parameter X=800, Y=100,
  parameter WIDTH=MAX_WALL_DEPTH * 4, HEIGHT=20,
  parameter WALL_COLOR=23'hF000, BAR_WIDTH=5) 
(
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0]  vcount_in,
  input wire [7:0] wall_depth_in,
  input wire [7:0] player_depth_in,
  output logic [23:0] pixel_out,
  output logic in_sprite
);

  assign in_sprite = ((hcount_in >= X && hcount_in < (X + WIDTH)) &&
                      (vcount_in >= Y && vcount_in < (Y + HEIGHT)));

  // Scale pixel depth down by 4 when comparing to wall/player so that
  // entire wall depth graphics component is scaled 4x wide
  logic pixel_depth;
  assign pixel_depth = (hcount_in - X)>>2;

  always_comb begin
    if(rst_in)
      pixel_out = 24'b0;
    else begin
      if(in_sprite) begin
        if (pixel_depth  == wall_depth_in)
          pixel_out = WALL_COLOR;
        else if (pixel_depth == player_depth_in)
          pixel_out = 24'h008000; // green
        else if (pixel_depth == GOAL_DEPTH - GOAL_DEPTH_DELTA || pixel_depth == GOAL_DEPTH + GOAL_DEPTH_DELTA)
          pixel_out = 24'h000080; // blue
        else
          pixel_out = 24'hFFFFFF; // white
      end
    end
  end
endmodule
`default_nettype none
