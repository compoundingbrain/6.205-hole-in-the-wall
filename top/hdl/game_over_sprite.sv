`timescale 1ns / 1ps
`default_nettype none
module game_over_sprite #(
    parameter SCREEN_HEIGHT=720, SCREEN_WIDTH=1280,
    parameter SCREEN_COLOR=24'h800000, BAR_WIDTH=50) 
(
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0]  vcount_in,
  output logic [23:0] pixel_out
);

  logic in_sprite;
  assign in_sprite = (hcount_in < SCREEN_WIDTH && vcount_in < SCREEN_HEIGHT);

  always_comb begin
    if(rst_in)
        pixel_out = 24'b0;
    else if (in_sprite) begin
        if (SCREEN_WIDTH * 40/100 < hcount_in && hcount_in < SCREEN_WIDTH * 50/100 && SCREEN_HEIGHT * 25/100 < vcount_in && vcount_in < SCREEN_HEIGHT * 75/100)
            pixel_out = 24'hFFFFFF;
        else if (SCREEN_WIDTH * 40/100 < hcount_in && hcount_in < SCREEN_WIDTH * 65/100 && SCREEN_HEIGHT * 60/100 < vcount_in && vcount_in < SCREEN_HEIGHT * 75/100)
            pixel_out = 24'hFFFFFF;
        else
            pixel_out = SCREEN_COLOR;
    end
  end
endmodule
`default_nettype none
