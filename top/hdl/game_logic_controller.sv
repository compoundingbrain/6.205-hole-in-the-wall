`timescale 1ns / 1ps
`default_nettype none

module game_logic_controller #(
    parameter SCREEN_WIDTH = 1280, 
    parameter SCREEN_HEIGHT = 720, 
    parameter GOAL_DEPTH = 60,
    parameter GOAL_DEPTH_DELTA = 10,
    parameter MAX_WALL_DEPTH = GOAL_DEPTH + GOAL_DEPTH_DELTA + 5,
    parameter MAX_FRAMES_PER_WALL_TICK = 15, // slowest speed of wall movement
    parameter BIT_MASK_DOWN_SAMPLE_FACTOR = 16,
    parameter MAX_ROUNDS = 5,
    parameter COLLISION_THRESHOLD = 65536
)
(
    input  wire                clk_in,
    input  wire                rst_in,
    input  wire [15:0]         start_game_in,

    input  wire [10:0]         hcount_in,
    input  wire [9:0]          vcount_in,
    input  wire                data_valid_in,

    input  wire                is_person_in,
    input  wire [7:0]          player_depth_in,

    output logic [10:0]        hcount_out,
    output logic [9:0]         vcount_out,
    output logic               data_valid_out,

    output logic [7:0]         wall_depth_out,
    output logic [7:0]         player_depth_out,
    output logic               is_wall_out,
    output logic               is_person_out,
    output logic               is_collision_out,

    output logic [2:0]         game_state
);
    // Round and frame info
    logic game_started;
    logic [7:0] curr_round;
    logic new_round_pulse;
    logic new_frame;
    assign new_frame = (hcount_in == SCREEN_WIDTH - 1 && vcount_in == SCREEN_HEIGHT - 1 && data_valid_in);

    // Wall and collision info
    logic [3:0] curr_wall_idx;
    logic[$clog2(BIT_MASK_WIDTH):0] bitmask_x; // index into wall bit mask computed over 2 cycles
    logic [$clog2(BIT_MASK_HEIGHT)*2:0] bitmask_y;
    logic is_wall;
    logic is_collision;
    logic [$clog2(SCREEN_HEIGHT * SCREEN_WIDTH):0] num_collisions; // worst case all pixels are collisions
    // TODO: Bit masks get pulled from BRAM in reverse so we need to flip the indices but
    //       it would be more efficient to just have the python script store them in reverse
    assign is_wall = bit_mask_wall[bitmask_x + bitmask_y] && data_valid_in;
    assign is_collision = is_person_in && is_wall;

    // Move wall forward one inch every `wall_tick_frequency` frames
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

    // Wall bit mask: access a new wall bit mask every round
    logic [BIT_MASK_SIZE-1:0] bit_mask_wall;
    localparam BIT_MASK_WIDTH = SCREEN_WIDTH / BIT_MASK_DOWN_SAMPLE_FACTOR;
    localparam BIT_MASK_HEIGHT = SCREEN_HEIGHT / BIT_MASK_DOWN_SAMPLE_FACTOR;
    localparam BIT_MASK_SIZE = BIT_MASK_WIDTH * BIT_MASK_HEIGHT;
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
        .bitmask_idx(curr_wall_idx),
        .wall_bit_mask(bit_mask_wall)
    ); 


    // Game progression logic
    // TODO: Check player is within bounds
    always_ff @(posedge clk_in) begin

        bitmask_x <= BIT_MASK_WIDTH - 1 - hcount_in[10:$clog2(BIT_MASK_DOWN_SAMPLE_FACTOR)];
        bitmask_y <= (BIT_MASK_HEIGHT - 1 - vcount_in[9:$clog2(BIT_MASK_DOWN_SAMPLE_FACTOR)]) * BIT_MASK_WIDTH;

        is_wall_out <= is_wall;
        is_person_out <= is_person_in;
        is_collision_out <= is_collision;

        if (rst_in) begin
            game_started <= 0;
            wall_depth_rst <= 0;
            curr_round <= 0;
            curr_wall_idx <= 0;
            wall_tick_frequency <= MAX_FRAMES_PER_WALL_TICK;
            new_round_pulse <= 0;
            wall_tick_pulse <= 0;
            game_state <= 1;
            num_collisions <= 0;
            
        end else if (~game_started && start_game_in) begin
            // Start game
            game_started <= 1;
            wall_depth_rst <= 0;
            curr_round <= 0;
            curr_wall_idx <= 0;
            wall_tick_frequency <= MAX_FRAMES_PER_WALL_TICK;
            new_round_pulse <= 0;
            wall_tick_pulse <= 0;
            game_state <= 1;
            num_collisions <= 0;

        end else if (~game_started) begin
            // Game not started
            wall_depth_rst <= 1;
            wall_depth_out <= 0;

        end else if (game_started) begin
            // Game in progress

            // Control sending wall movement signal at correct frequency
            if (wall_tick_pulse) begin
                wall_tick_pulse <= 0;
            end
            else if(wall_tick_count == wall_tick_frequency) begin
                wall_tick_pulse <= 1;
            end 

            if (new_round_pulse) begin
                // New round
                new_round_pulse <= 0;
                wall_depth_rst <= 0;
                curr_round <= curr_round + 1;
                curr_wall_idx <= (curr_wall_idx == 9) ? 0 : curr_wall_idx + 1;
            end
            else if(wall_tick_pulse && wall_depth == MAX_WALL_DEPTH - 1) begin
                // Wall reached end of depth
                new_round_pulse <= 1;
                wall_depth_rst <= 1;
            end

            if (curr_round == MAX_ROUNDS) begin
                // Won game
                game_state <= 2;
                game_started <= 0;
            end

            if (new_frame) 
                num_collisions <= 0;
            else if(is_collision)
                num_collisions <= num_collisions + 1;

            if (data_valid_in &&
                (wall_depth >= (GOAL_DEPTH - GOAL_DEPTH_DELTA)) &&
                (wall_depth <= (GOAL_DEPTH + GOAL_DEPTH_DELTA)) && 
                num_collisions >= COLLISION_THRESHOLD) begin
                // Pixel collision
                game_state <= 0;
                game_started <= 0;
            end

            wall_depth_out <= wall_depth;
            
            player_depth_out <= player_depth_in;
            hcount_out <= hcount_in;
            vcount_out <= vcount_in;
            data_valid_out <= data_valid_in;
        end
    end

endmodule   
`default_nettype wire
