`default_nettype none
module graphics_controller #(parameter ACTIVE_H_PIXELS = 1280, parameter ACTIVE_LINES = 720)(
    /*
    Spec: pixel_out will be pixel_in if is_wall is low, 
    else it will be wall_color.
    */
    input wire clk_in,
    input wire rst_in,
    input wire [10:0] h_count_in,
    input wire [9:0] v_count_in,
    input wire [7:0] wall_depth,   // TODO: use this
    input wire [7:0] player_depth, // TODO: use this,
    input wire is_wall,
    input wire [15:0] wall_color,
    input wire [15:0] pixel_in,

    output logic [15:0] pixel_out

);
    always_comb begin
        if (!rst_in) begin
            if (h_count_in < ACTIVE_H_PIXELS && v_count_in < ACTIVE_LINES) begin
                if (is_wall) begin
                    pixel_out = wall_color;
                end else begin
                    pixel_out = pixel_in;
                end
            end
        end
    end
endmodule  
`default_nettype wire