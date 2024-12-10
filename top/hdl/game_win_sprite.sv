`timescale 1ns / 1ps
`default_nettype none
module game_win_sprite #(
    parameter SCREEN_HEIGHT=720, SCREEN_WIDTH=1280,
    parameter SCREEN_COLOR=24'h008000, BAR_WIDTH=50) 
(
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0]  vcount_in,
  output logic [23:0] pixel_out
);

  logic in_sprite;
  assign in_sprite = (hcount_in < SCREEN_WIDTH && vcount_in < SCREEN_HEIGHT);

  localparam left_vert_bar_start_horz = SCREEN_WIDTH * 20/100;
  localparam left_vert_bar_end_horz = SCREEN_WIDTH * 32/100;
  localparam middle_vert_bar_start_horz = SCREEN_WIDTH * 44/100;
  localparam middle_vert_bar_end_horz = SCREEN_WIDTH * 56/100;
  localparam right_vert_bar_start_horz = SCREEN_WIDTH * 68/100;
  localparam right_vert_bar_end_horz = SCREEN_WIDTH * 80/100;
  localparam all_vert_bar_start_vert = SCREEN_HEIGHT * 20/100;
  localparam all_vert_bar_end_vert = SCREEN_HEIGHT * 80/100;

  localparam bottom_horz_bar_start_horz = SCREEN_WIDTH * 20/100;
  localparam bottom_horz_bar_end_horz = SCREEN_WIDTH * 80/100;
  localparam bottom_horz_bar_start_vert = SCREEN_HEIGHT * 68/100;
  localparam bottom_horz_bar_end_vert = SCREEN_HEIGHT * 80/100;

  localparam white_pixel = 24'hFFFFFF;

  always_comb begin
    if(rst_in)
        pixel_out = 24'b0;
    else if (in_sprite) begin
        if ((vcount_in >= all_vert_bar_start_vert && vcount_in < all_vert_bar_end_vert) && 
            ((hcount_in >= left_vert_bar_start_horz && hcount_in < left_vert_bar_end_horz) ||
            (hcount_in >= middle_vert_bar_start_horz && hcount_in < middle_vert_bar_end_horz) ||
            (hcount_in >= right_vert_bar_start_horz && hcount_in < right_vert_bar_end_horz)))
            pixel_out = white_pixel;
        else if ((vcount_in >= bottom_horz_bar_start_vert && vcount_in < bottom_horz_bar_end_vert) &&
                (hcount_in >= bottom_horz_bar_start_horz && hcount_in < bottom_horz_bar_end_horz))
            pixel_out = white_pixel;
        else
            pixel_out = SCREEN_COLOR;
    end
  end
endmodule
`default_nettype none
