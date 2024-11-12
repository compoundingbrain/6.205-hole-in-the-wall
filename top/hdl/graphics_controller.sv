`default_nettype none
module graphics_controller #(parameter ACTIVE_H_PIXELS = 1280, parameter ACTIVE_LINES = 720)(
    /*
    Spec: If h_count_in and v_count_in are within 0 and ACTIVE_H_PIXELS - 1 and ACTIVE_LINES - 1, 
    then data_valid_out will be high and pixel_out will be pixel_in if is_wall is low, 
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

    output logic [10:0] hcount_out,
    output logic [9:0] vcount_out,
    output logic [15:0] pixel_out,
    output logic data_valid_out

);
    always_comb begin
        if (h_count_in < ACTIVE_H_PIXELS && v_count_in < ACTIVE_LINES) begin
            data_valid_out <= 1;
            if (is_wall) begin
                pixel_out <= wall_color;
            end else begin
                pixel_out <= pixel_in;
            end
        end else begin
            data_valid_out <= 0;
        end
    end
endmodule  
`default_nettype wire