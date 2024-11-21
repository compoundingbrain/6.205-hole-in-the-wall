`default_nettype none
module graphics_controller #(
    parameter ACTIVE_H_PIXELS = 1280, ACTIVE_LINES = 720,
    parameter COLLISION_COLOR = 24'h8000, WALL_COLOR = 24'hF000,
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
    input wire [7:0] wall_depth,
    input wire [7:0] player_depth,
    input wire is_wall,
    input wire is_collision,
    input wire [23:0] pixel_in,

    output logic [23:0] pixel_out
);

    logic [23:0] wall_depth_sprite_pixel;
    logic in_wall_depth_sprite;
    wall_depth_sprite #(
        .GOAL_DEPTH(GOAL_DEPTH), .GOAL_DEPTH_DELTA(GOAL_DEPTH_DELTA), .MAX_WALL_DEPTH(MAX_WALL_DEPTH),
        .X(800), .Y(100),
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

    always_comb begin
        if (!rst_in && hcount_in < ACTIVE_H_PIXELS && vcount_in < ACTIVE_LINES) begin  
            if (in_wall_depth_sprite) begin
                pixel_out = wall_depth_sprite_pixel;
            end else if (is_collision) begin
                pixel_out = COLLISION_COLOR;
            end else if (is_wall) begin
                pixel_out = WALL_COLOR;
            end else begin
                pixel_out = pixel_in;
            end
        end
    end
endmodule  
`default_nettype wire