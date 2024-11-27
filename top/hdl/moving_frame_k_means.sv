`timescale 1ns / 1ps
`default_nettype none

// K-means for i players set by the i parameter. 
// Right now will only work for one person and basically just do center of mass
module moving_frame_k_means (
  input wire clk_in,
  input wire rst_in,
  input wire [10:0] x_in,
  input wire [9:0]  y_in,
  input wire valid_in,
  input wire tabulate_in,
  input wire [1:0] num_players, // num players - 1
  output logic [10:0] x_out [3:0], // make this 4 wide for 4 players
  output logic [9:0] y_out [3:0], // make this 4 wide for 4 players
  output logic valid_out // make this 4 wide for 4 players
);

  localparam ONE_PLAYER = 2'b00;
  localparam TWO_PLAYERS = 2'b01;
  localparam THREE_PLAYERS = 2'b10;
  localparam FOUR_PLAYERS = 2'b11;

  // pipelined valid_out
  logic [3:0] pipe_valid_out;

  // x and y coordinates of the first centroid
  logic [10:0] centroid_1_x, centroid_1_y;
  logic [10:0] x_out_1;
  logic [9:0] y_out_1;
  assign x_out[0] = centroid_1_x;
  assign y_out[0] = centroid_1_y;
  // x and y coordinates of the second centroid
  logic [10:0] centroid_2_x, centroid_2_y;
  logic [10:0] x_out_2; 
  logic [9:0] y_out_2;
  assign x_out[1] = centroid_2_x;
  assign y_out[1] = centroid_2_y;
  // x and y coordinates of the third centroid
  logic [10:0] centroid_3_x, centroid_3_y;
  logic [10:0] x_out_3;
  logic [9:0] y_out_3;
  assign x_out[2] = centroid_3_x;
  assign y_out[2] = centroid_3_y;
  // x and y coordinates of the fourth centroid
  logic [10:0] centroid_4_x, centroid_4_y;
  logic [10:0] x_out_4;
  logic [9:0] y_out_4;
  assign x_out[3] = centroid_4_x;
  assign y_out[3] = centroid_4_y;

  // manhattan distances from the centroids to the current COM
  logic [10:0] manhattan_distance_1, manhattan_distance_2, manhattan_distance_3, manhattan_distance_4;

  // minimum manhattan distance
  logic [10:0] min_dist;

  // which centroid is closest to the current COM
  logic [1:0] closest_centroid;

  // Calculate the manhattan distance to each centroid, then calculate which is the smallest
  always_comb begin
    manhattan_distance_1 = ((x_in > centroid_1_x) ? (x_in - centroid_1_x) : (centroid_1_x - x_in)) + ((y_in > centroid_1_y) ? (y_in - centroid_1_y) : (centroid_1_y - y_in));
    manhattan_distance_2 = ((x_in > centroid_2_x) ? (x_in - centroid_2_x) : (centroid_2_x - x_in)) + ((y_in > centroid_2_y) ? (y_in - centroid_2_y) : (centroid_2_y - y_in));
    manhattan_distance_3 = ((x_in > centroid_3_x) ? (x_in - centroid_3_x) : (centroid_3_x - x_in)) + ((y_in > centroid_3_y) ? (y_in - centroid_3_y) : (centroid_3_y - y_in));
    manhattan_distance_4 = ((x_in > centroid_4_x) ? (x_in - centroid_4_x) : (centroid_4_x - x_in)) + ((y_in > centroid_4_y) ? (y_in - centroid_4_y) : (centroid_4_y - y_in));

    min_dist = manhattan_distance_1;
    closest_centroid = 2'b00;

    if (num_players >= TWO_PLAYERS && manhattan_distance_2 < min_dist) begin
      min_dist = manhattan_distance_2;
      closest_centroid = 2'b01;
    end

    if (num_players >= THREE_PLAYERS && manhattan_distance_3 < min_dist) begin
      min_dist = manhattan_distance_3;
      closest_centroid = 2'b10;
    end

    if (num_players >= FOUR_PLAYERS && manhattan_distance_4 < min_dist) begin
      min_dist = manhattan_distance_4;
      closest_centroid = 2'b11;
    end
  end

  // Add combinational logic here that will calculate the closest centroid
  // for each pixel doing the manhattan distance

  center_of_mass com_1(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .x_in(x_in),
    .y_in(y_in),
    .valid_in(valid_in && closest_centroid == 2'b00),
    .tabulate_in(tabulate_in),
    .x_out(x_out_1),
    .y_out(y_out_1),
    .valid_out(pipe_valid_out[0])
  );

  center_of_mass com_2(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .x_in(x_in),
    .y_in(y_in),
    .valid_in(valid_in && closest_centroid == 2'b01),
    .tabulate_in(tabulate_in),
    .x_out(x_out_2),
    .y_out(y_out_2),
    .valid_out(pipe_valid_out[1])
  );

  center_of_mass com_3(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .x_in(x_in),
    .y_in(y_in),
    .valid_in(valid_in && closest_centroid == 2'b10),
    .tabulate_in(tabulate_in),
    .x_out(x_out_3),
    .y_out(y_out_3),
    .valid_out(pipe_valid_out[2])
  );

  center_of_mass com_4(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .x_in(x_in),
    .y_in(y_in),
    .valid_in(valid_in && closest_centroid == 2'b11),
    .tabulate_in(tabulate_in),
    .x_out(x_out_4),
    .y_out(y_out_4),
    .valid_out(pipe_valid_out[3])
  );

  logic [3:0] valid_out_collector; // 4 wide, once all bits are 1, then valid out is 1

  assign valid_out = valid_out_collector == 4'b1111;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // TODO: add the default centroids based on the number of players
      centroid_1_x <= 0;
      centroid_1_y <= 0;
      centroid_2_x <= 0;
      centroid_2_y <= 0;
      centroid_3_x <= 0;
      centroid_3_y <= 0;
      centroid_4_x <= 0;
      centroid_4_y <= 0;
      valid_out_collector <= 0;
    end else begin
      if (pipe_valid_out[0]) begin
        centroid_1_x <= x_out_1;
        centroid_1_y <= y_out_1;
        valid_out_collector[0] <= 1;
      end
      if (pipe_valid_out[1]) begin
        centroid_2_x <= x_out_2;
        centroid_2_y <= y_out_2;
        valid_out_collector[1] <= 1;
      end
      if (pipe_valid_out[2]) begin
        centroid_3_x <= x_out_3;
        centroid_3_y <= y_out_3;
        valid_out_collector[2] <= 1;  
      end
      if (pipe_valid_out[3]) begin
        centroid_4_x <= x_out_4;
        centroid_4_y <= y_out_4;
        valid_out_collector[3] <= 1;
      end 
      if (valid_out_collector == 4'b1111) begin
        valid_out_collector <= 0;
      end 
    end
  end

endmodule

`default_nettype wire

