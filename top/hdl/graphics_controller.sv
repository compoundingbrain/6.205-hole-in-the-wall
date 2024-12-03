`default_nettype none
module graphics_controller #(
    parameter ACTIVE_H_PIXELS = 1280, ACTIVE_LINES = 720,
    parameter COLLISION_COLOR = 24'h800000, WALL_COLOR = 24'hFF0080,
    parameter GOAL_DEPTH=60, GOAL_DEPTH_DELTA=10, MAX_WALL_DEPTH=75
)(
    /*
    Spec: pixel_out should default to the video input in pixel_in unless the pixel
    corresponds to the following (in order of priority): 
        - a UI component (wall indicator)
        - a collision
        - a wall
    */
    input wire clk_in,
    input wire rst_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    input wire [1:0] pixel_player_num,
    input wire [7:0] wall_depth,
    input wire [7:0] player_depth,
    input wire is_player,
    input wire is_wall,
    input wire is_collision,
    input wire [23:0] pixel_in,
    input wire [2:0] game_state_in,

    output logic [23:0] pixel_out
);

    logic [23:0] wall_depth_sprite_pixel;
    logic in_wall_depth_sprite;
    wall_depth_sprite #(
        .GOAL_DEPTH(GOAL_DEPTH), .GOAL_DEPTH_DELTA(GOAL_DEPTH_DELTA), .MAX_WALL_DEPTH(MAX_WALL_DEPTH),
        .X(950), .Y(20),
        .WIDTH(MAX_WALL_DEPTH * 4), .HEIGHT(20),
        .WALL_COLOR(WALL_COLOR), .BAR_WIDTH(5)
    ) wds (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .hcount_in(hcount_in),
        .vcount_in(vcount_in),
        .wall_depth_in(wall_depth),
        .player_depth_in(player_depth),
        .pixel_out(wall_depth_sprite_pixel),
        .in_sprite(in_wall_depth_sprite)
    );

    logic [23:0] game_over_sprite_pixel;
    game_over_sprite #(
        .SCREEN_WIDTH(ACTIVE_H_PIXELS), .SCREEN_HEIGHT(ACTIVE_LINES), .SCREEN_COLOR(COLLISION_COLOR)
    ) gos (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .hcount_in(hcount_in),
        .vcount_in(vcount_in),
        .pixel_out(game_over_sprite_pixel)
    );

    always_comb begin
        if (!rst_in && hcount_in < ACTIVE_H_PIXELS && vcount_in < ACTIVE_LINES) begin  
            if (game_state_in == 0) begin
                // Game over screen
                pixel_out = game_over_sprite_pixel;
            end else if (in_wall_depth_sprite) begin
                // Wall depth sprite
                pixel_out = wall_depth_sprite_pixel;
            end else if (is_collision) begin
                // Collision
                pixel_out = COLLISION_COLOR;
            end else if (is_wall) begin
                // Wall
                pixel_out = WALL_COLOR;
            end else if (is_player) begin
                // Players  
                case (pixel_player_num)
                    0: pixel_out = 24'h0000FF;
                    1: pixel_out = 24'hFFFF00;
                    2: pixel_out = 24'h00FF00;
                    3: pixel_out = 24'hFFAA00;
                endcase
            end else begin
                // Video stream
                pixel_out = pixel_in;
            end
        end
    end
endmodule  
`default_nettype wire