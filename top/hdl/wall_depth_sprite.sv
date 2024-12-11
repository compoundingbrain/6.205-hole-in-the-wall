`timescale 1ns / 1ps
`default_nettype none
module wall_depth_sprite #(
  parameter GOAL_DEPTH=60, GOAL_DEPTH_DELTA=10, MAX_WALL_DEPTH=75,
  parameter X=800, Y=100,
  parameter WIDTH=MAX_WALL_DEPTH * 4, HEIGHT=20,
  parameter WALL_COLOR=24'hFF0080, BAR_WIDTH=5) 
(
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0]  vcount_in,
  input wire [7:0] wall_depth_in,
  input wire [1:0] num_players_in,
  input wire [7:0] player_depths_in [3:0],
  output logic [23:0] pixel_out,
  output logic in_sprite
);

  assign in_sprite = ((hcount_in >= X && hcount_in < (X + WIDTH)) &&
                      (vcount_in >= Y && vcount_in < (Y + HEIGHT)));

  // Scale pixel depth down by 4 when comparing to wall/player so that
  // entire wall depth graphics component is scaled 4x wide
  logic [7:0] pixel_depth;
  assign pixel_depth = (hcount_in - X)>>2;

  always_comb begin
    if(rst_in)
      pixel_out = 24'b0;
    else begin
      if(in_sprite) begin
        if (pixel_depth  == wall_depth_in)
          // wall depth indicator
          pixel_out = WALL_COLOR;
        else if (pixel_depth == player_depths_in[0])
          pixel_out = 24'h008000; // green
        else if (pixel_depth == player_depths_in[1] && num_players_in >= 1)
          pixel_out = 24'h800000; // red  
        else if (pixel_depth == player_depths_in[2] && num_players_in >= 2)
          pixel_out = 24'h800080; // purple
        else if (pixel_depth == player_depths_in[3] && num_players_in == 4)
          pixel_out = 24'hFF8000; // orange
        else if (pixel_depth == GOAL_DEPTH - GOAL_DEPTH_DELTA || pixel_depth == GOAL_DEPTH + GOAL_DEPTH_DELTA)
          // goal depth bounds
          pixel_out = 24'h000080; // blue
        else
          pixel_out = 24'hFFFFFF; // white
      end
    end
  end
endmodule
`default_nettype none
