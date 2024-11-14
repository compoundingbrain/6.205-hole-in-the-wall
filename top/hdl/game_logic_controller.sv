`timescale 1ns / 1ps
`default_nettype none

module game_logic_controller #(
    parameter SCREEN_WIDTH = 1280, 
    parameter SCREEN_HEIGHT = 720, 
    parameter GOAL_DEPTH = 60,
    parameter GOAL_DEPTH_DELTA = 10,
    parameter MAX_WALL_DEPTH = GOAL_DEPTH + GOAL_DEPTH_DELTA + 5,
    parameter MAX_FRAMES_PER_WALL_TICK = 15, // slowest speed of wall movement
    parameter BIT_MASK_DOWN_SAMPLE_FACTOR = 16
)
(
    input  wire                clk_in,
    input  wire                rst_in,
    input  wire [15:0]         sw,

    input  wire [10:0]         hcount_in,
    input  wire [9:0]          vcount_in,
    input  wire [15:0]         pixel_in,
    input  wire                data_valid_in,

    input  wire                is_person_in,
    input  wire [7:0]          player_depth_in,

    output logic [10:0]        hcount_out,
    output logic [9:0]         vcount_out,
    output logic [15:0]        pixel_out,
    output logic               data_valid_out,

    output logic               is_wall_out,
    output logic [7:0]         wall_depth_out,
    output logic [7:0]         player_depth_out,
    output logic               is_person_out,
    output logic [2:0]         game_state
);
    logic new_round_pulse;
    logic [7:0] curr_round;

    logic curr_wall_idx;
    logic [6:0] bitmask_x = hcount_in[10:4];
    logic [5:0] bitmask_y = vcount_in[9:4];

    logic new_frame;
    assign new_frame = (hcount_in == SCREEN_WIDTH - 1 && vcount_in == SCREEN_HEIGHT - 1 && data_valid_in);


    // Wall depth: move wall forward one inch every `wall_tick_frequency` frames
    logic [7:0] wall_depth;
    logic wall_depth_rst;
    logic wall_tick_pulse;
    localparam MAX_WALL_TICK_FREQUENCY_BITS = ($clog2(MAX_FRAMES_PER_WALL_TICK) < 1) ? 1 : $clog2(MAX_FRAMES_PER_WALL_TICK);
    logic [MAX_WALL_TICK_FREQUENCY_BITS-1:0] wall_tick_frequency; // move the wall every 15 frames
    logic [MAX_WALL_TICK_FREQUENCY_BITS-1:0] wall_tick_count;
    evt_counter_dynamic wall_tick_counter (
        .clk_in(clk_in),
        .rst_in(rst_in | wall_depth_rst),
        .evt_in(new_frame),
        .max_count_in(wall_tick_frequency+1),
        .count_out(wall_tick_count)
    );
    evt_counter #(.MAX_COUNT(MAX_WALL_DEPTH)) wall_depth_counter (
        .clk_in(clk_in),
        .rst_in(rst_in | wall_depth_rst),
        .evt_in(wall_tick_pulse),
        .count_out(wall_depth)
    );
    always_ff @(posedge clk_in) begin
        if (wall_tick_pulse) begin
            wall_tick_pulse <= 0;
        end
        else if(wall_tick_count == wall_tick_frequency) begin
            wall_tick_pulse <= 1;
        end 

        if (new_round_pulse) begin
            new_round_pulse <= 0;
            wall_depth_rst <= 0;
        end
        else if(wall_depth == MAX_WALL_DEPTH - 1) begin
            new_round_pulse <= 1;
            wall_depth_rst <= 1;
        end
    end

    // Wall bit mask: access a new wall bit mask every round
    localparam BIT_MASK_WIDTH = SCREEN_WIDTH / BIT_MASK_DOWN_SAMPLE_FACTOR;
    localparam BIT_MASK_HEIGHT = SCREEN_HEIGHT / BIT_MASK_DOWN_SAMPLE_FACTOR;
    localparam BIT_MASK_SIZE = BIT_MASK_WIDTH * BIT_MASK_HEIGHT;
    logic [BIT_MASK_SIZE-1:0] bit_mask_wall;
    logic bit_mask_wall_valid;
    wall_bit_mask  #(
        .SCREEN_WIDTH(SCREEN_WIDTH),
        .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .DOWN_SAMPLE_FACTOR(BIT_MASK_DOWN_SAMPLE_FACTOR),
        .BIT_MASK_WIDTH(BIT_MASK_WIDTH),
        .BIT_MASK_HEIGHT(BIT_MASK_HEIGHT),
        .BIT_MASK_SIZE(BIT_MASK_SIZE)
        ) wall_bit_mask_storage (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .valid_in(new_round_pulse),
        .bitmask_idx(curr_wall_idx),
        .valid_out(bit_mask_wall_valid),
        .wall_bit_mask(bit_mask_wall)
    ); 


    // Game progression logic
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            curr_round <= 0;
            curr_wall_idx <= 0;
            wall_tick_frequency <= MAX_FRAMES_PER_WALL_TICK;
            wall_depth_rst <= 0;
            new_round_pulse <= 0;
            wall_tick_pulse <= 0;
            
        end else begin
            if (new_round_pulse) begin
                // New round
                curr_round <= curr_round + 1;
            end
        end
    end

endmodule   
`default_nettype wire
