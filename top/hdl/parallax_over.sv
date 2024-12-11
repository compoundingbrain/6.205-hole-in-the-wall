`timescale 1ns / 1ps
`default_nettype none

module parallax_over (
  input wire clk_in,
  input wire rst_in,
  input wire data_valid_in,
  input wire [1:0] num_players,
  input wire [10:0] x_in_1 [3:0],
  input wire [9:0]  y_in_1 [3:0],
  input wire [10:0] x_in_2 [3:0],
  input wire [9:0]  y_in_2 [3:0],
  output logic [7:0] depth_out [3:0]
);

  localparam ONE_PLAYER = 2'b00;
  localparam TWO_PLAYERS = 2'b01;
  localparam THREE_PLAYERS = 2'b10;
  localparam FOUR_PLAYERS = 2'b11;

  // Pipeline stage 1: register inputs
  logic [1:0] num_players_pipe_1;
  logic [10:0] x_in_1_pipe_1 [3:0];
  logic [9:0]  y_in_1_pipe_1 [3:0];
  logic [10:0] x_in_2_pipe_1 [3:0];
  logic [9:0]  y_in_2_pipe_1 [3:0];
  logic valid_in_pipe_1;
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      valid_in_pipe_1 <= 1'b0;
    end else begin
      num_players_pipe_1 <= num_players;
        x_in_1_pipe_1[0] <= x_in_1[0];
        x_in_1_pipe_1[1] <= x_in_1[1];
        x_in_1_pipe_1[2] <= x_in_1[2];
        x_in_1_pipe_1[3] <= x_in_1[3];

        y_in_1_pipe_1[0] <= y_in_1[0];
        y_in_1_pipe_1[1] <= y_in_1[1];
        y_in_1_pipe_1[2] <= y_in_1[2];
        y_in_1_pipe_1[3] <= y_in_1[3];

        x_in_2_pipe_1[0] <= x_in_2[0];
        x_in_2_pipe_1[1] <= x_in_2[1];
        x_in_2_pipe_1[2] <= x_in_2[2];
        x_in_2_pipe_1[3] <= x_in_2[3];

        y_in_2_pipe_1[0] <= y_in_2[0];
        y_in_2_pipe_1[1] <= y_in_2[1];
        y_in_2_pipe_1[2] <= y_in_2[2];
        y_in_2_pipe_1[3] <= y_in_2[3];
      valid_in_pipe_1 <= data_valid_in;
    end
  end

  // Closest centroid for the first point
  logic [10:0] manhattan_distance_1_1, manhattan_distance_2_1, manhattan_distance_3_1, manhattan_distance_4_1;
  logic [10:0] min_dist_1;
  logic [1:0]  closest_centroid_1;
  always_comb begin
    manhattan_distance_1_1 = ( (x_in_1_pipe_1[0]>x_in_2_pipe_1[0]) ? (x_in_1_pipe_1[0]-x_in_2_pipe_1[0]) : (x_in_2_pipe_1[0]-x_in_1_pipe_1[0]) )
                           + ( (y_in_1_pipe_1[0]>y_in_2_pipe_1[0]) ? (y_in_1_pipe_1[0]-y_in_2_pipe_1[0]) : (y_in_2_pipe_1[0]-y_in_1_pipe_1[0]) );
    manhattan_distance_2_1 = ( (x_in_1_pipe_1[0]>x_in_2_pipe_1[1]) ? (x_in_1_pipe_1[0]-x_in_2_pipe_1[1]) : (x_in_2_pipe_1[1]-x_in_1_pipe_1[0]) )
                           + ( (y_in_1_pipe_1[0]>y_in_2_pipe_1[1]) ? (y_in_1_pipe_1[0]-y_in_2_pipe_1[1]) : (y_in_2_pipe_1[1]-y_in_1_pipe_1[0]) );
    manhattan_distance_3_1 = ( (x_in_1_pipe_1[0]>x_in_2_pipe_1[2]) ? (x_in_1_pipe_1[0]-x_in_2_pipe_1[2]) : (x_in_2_pipe_1[2]-x_in_1_pipe_1[0]) )
                           + ( (y_in_1_pipe_1[0]>y_in_2_pipe_1[2]) ? (y_in_1_pipe_1[0]-y_in_2_pipe_1[2]) : (y_in_2_pipe_1[2]-y_in_1_pipe_1[0]) );
    manhattan_distance_4_1 = ( (x_in_1_pipe_1[0]>x_in_2_pipe_1[3]) ? (x_in_1_pipe_1[0]-x_in_2_pipe_1[3]) : (x_in_2_pipe_1[3]-x_in_1_pipe_1[0]) )
                           + ( (y_in_1_pipe_1[0]>y_in_2_pipe_1[3]) ? (y_in_1_pipe_1[0]-y_in_2_pipe_1[3]) : (y_in_2_pipe_1[3]-y_in_1_pipe_1[0]) );

    min_dist_1 = manhattan_distance_1_1;
    closest_centroid_1 = 2'b00;
    if (num_players_pipe_1 >= TWO_PLAYERS && manhattan_distance_2_1 < min_dist_1) begin
      min_dist_1 = manhattan_distance_2_1;
      closest_centroid_1 = 2'b01;
    end
    if (num_players_pipe_1 >= THREE_PLAYERS && manhattan_distance_3_1 < min_dist_1) begin
      min_dist_1 = manhattan_distance_3_1;
      closest_centroid_1 = 2'b10;
    end
    if (num_players_pipe_1 == FOUR_PLAYERS && manhattan_distance_4_1 < min_dist_1) begin
      min_dist_1 = manhattan_distance_4_1;
      closest_centroid_1 = 2'b11;
    end
  end

  logic [7:0] depth_out_1;
  parallax parallax_1 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_valid_in(valid_in_pipe_1),
    .x_1_in(x_in_1_pipe_1[0]),
    .x_2_in(x_in_2_pipe_1[closest_centroid_1]),
    .depth_out(depth_out_1)
  );

  // Pipeline stage 2: register intermediate results for second centroid calculation
  logic [1:0] num_players_pipe_2;
  logic [10:0] x_in_1_pipe_2 [3:0];
  logic [9:0]  y_in_1_pipe_2 [3:0];
  logic [10:0] x_in_2_pipe_2 [3:0];
  logic [9:0]  y_in_2_pipe_2 [3:0];
  logic valid_in_pipe_2;
  logic [1:0] closest_centroid_to_centroid_1;

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      valid_in_pipe_2 <= 1'b0;
    end else begin
      num_players_pipe_2 <= num_players_pipe_1;
        x_in_1_pipe_2[0] <= x_in_1_pipe_1[0];
        x_in_1_pipe_2[1] <= x_in_1_pipe_1[1];
        x_in_1_pipe_2[2] <= x_in_1_pipe_1[2];
        x_in_1_pipe_2[3] <= x_in_1_pipe_1[3];

        y_in_1_pipe_2[0] <= y_in_1_pipe_1[0];
        y_in_1_pipe_2[1] <= y_in_1_pipe_1[1];
        y_in_1_pipe_2[2] <= y_in_1_pipe_1[2];
        y_in_1_pipe_2[3] <= y_in_1_pipe_1[3];

        x_in_2_pipe_2[0] <= x_in_2_pipe_1[0];
        x_in_2_pipe_2[1] <= x_in_2_pipe_1[1];
        x_in_2_pipe_2[2] <= x_in_2_pipe_1[2];
        x_in_2_pipe_2[3] <= x_in_2_pipe_1[3];

        y_in_2_pipe_2[0] <= y_in_2_pipe_1[0];
        y_in_2_pipe_2[1] <= y_in_2_pipe_1[1];
        y_in_2_pipe_2[2] <= y_in_2_pipe_1[2];
        y_in_2_pipe_2[3] <= y_in_2_pipe_1[3];
      valid_in_pipe_2 <= valid_in_pipe_1;
      closest_centroid_to_centroid_1 <= closest_centroid_1;
    end
  end

  // Closest centroid for the second point
  logic [10:0] manhattan_distance_1_2, manhattan_distance_2_2, manhattan_distance_3_2, manhattan_distance_4_2;
  logic [10:0] min_dist_2;
  logic [1:0]  closest_centroid_2;
  always_comb begin
    manhattan_distance_1_2 = ( (x_in_1_pipe_2[1]>x_in_2_pipe_2[0]) ? (x_in_1_pipe_2[1]-x_in_2_pipe_2[0]) : (x_in_2_pipe_2[0]-x_in_1_pipe_2[1]) )
                           + ( (y_in_1_pipe_2[1]>y_in_2_pipe_2[0]) ? (y_in_1_pipe_2[1]-y_in_2_pipe_2[0]) : (y_in_2_pipe_2[0]-y_in_1_pipe_2[1]) );
    manhattan_distance_2_2 = ( (x_in_1_pipe_2[1]>x_in_2_pipe_2[1]) ? (x_in_1_pipe_2[1]-x_in_2_pipe_2[1]) : (x_in_2_pipe_2[1]-x_in_1_pipe_2[1]) )
                           + ( (y_in_1_pipe_2[1]>y_in_2_pipe_2[1]) ? (y_in_1_pipe_2[1]-y_in_2_pipe_2[1]) : (y_in_2_pipe_2[1]-y_in_1_pipe_2[1]) );
    manhattan_distance_3_2 = ( (x_in_1_pipe_2[1]>x_in_2_pipe_2[2]) ? (x_in_1_pipe_2[1]-x_in_2_pipe_2[2]) : (x_in_2_pipe_2[2]-x_in_1_pipe_2[1]) )
                           + ( (y_in_1_pipe_2[1]>y_in_2_pipe_2[2]) ? (y_in_1_pipe_2[1]-y_in_2_pipe_2[2]) : (y_in_2_pipe_2[2]-y_in_1_pipe_2[1]) );
    manhattan_distance_4_2 = ( (x_in_1_pipe_2[1]>x_in_2_pipe_2[3]) ? (x_in_1_pipe_2[1]-x_in_2_pipe_2[3]) : (x_in_2_pipe_2[3]-x_in_1_pipe_2[1]) )
                           + ( (y_in_1_pipe_2[1]>y_in_2_pipe_2[3]) ? (y_in_1_pipe_2[1]-y_in_2_pipe_2[3]) : (y_in_2_pipe_2[3]-y_in_1_pipe_2[1]) );

    min_dist_2 = manhattan_distance_1_2;
    closest_centroid_2 = 2'b00;
    if (num_players_pipe_2 >= TWO_PLAYERS && manhattan_distance_2_2 < min_dist_2) begin
      min_dist_2 = manhattan_distance_2_2;
      closest_centroid_2 = 2'b01;
    end
    if (num_players_pipe_2 >= THREE_PLAYERS && manhattan_distance_3_2 < min_dist_2) begin
      min_dist_2 = manhattan_distance_3_2;
      closest_centroid_2 = 2'b10;
    end
    if (num_players_pipe_2 == FOUR_PLAYERS && manhattan_distance_4_2 < min_dist_2) begin
      min_dist_2 = manhattan_distance_4_2;
      closest_centroid_2 = 2'b11;
    end
  end

  logic [7:0] depth_out_2;
  parallax parallax_2 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_valid_in(valid_in_pipe_2),
    .x_1_in(x_in_1_pipe_2[1]),
    .x_2_in(x_in_2_pipe_2[closest_centroid_2]),
    .depth_out(depth_out_2)
  );

  // Pipeline stage 3
  logic [1:0] num_players_pipe_3;
  logic [10:0] x_in_1_pipe_3 [3:0];
  logic [9:0]  y_in_1_pipe_3 [3:0];
  logic [10:0] x_in_2_pipe_3 [3:0];
  logic [9:0]  y_in_2_pipe_3 [3:0];
  logic valid_in_pipe_3;
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      valid_in_pipe_3 <= 1'b0;
    end else begin
      num_players_pipe_3 <= num_players_pipe_2;
        x_in_1_pipe_3[0] <= x_in_1_pipe_2[0];
        x_in_1_pipe_3[1] <= x_in_1_pipe_2[1];
        x_in_1_pipe_3[2] <= x_in_1_pipe_2[2];
        x_in_1_pipe_3[3] <= x_in_1_pipe_2[3];

        y_in_1_pipe_3[0] <= y_in_1_pipe_2[0];
        y_in_1_pipe_3[1] <= y_in_1_pipe_2[1];
        y_in_1_pipe_3[2] <= y_in_1_pipe_2[2];
        y_in_1_pipe_3[3] <= y_in_1_pipe_2[3];

        x_in_2_pipe_3[0] <= x_in_2_pipe_2[0];
        x_in_2_pipe_3[1] <= x_in_2_pipe_2[1];
        x_in_2_pipe_3[2] <= x_in_2_pipe_2[2];
        x_in_2_pipe_3[3] <= x_in_2_pipe_2[3];

        y_in_2_pipe_3[0] <= y_in_2_pipe_2[0];
        y_in_2_pipe_3[1] <= y_in_2_pipe_2[1];
        y_in_2_pipe_3[2] <= y_in_2_pipe_2[2];
        y_in_2_pipe_3[3] <= y_in_2_pipe_2[3];
      valid_in_pipe_3 <= valid_in_pipe_2;
    end
  end

  // Closest centroid for the third point
  logic [10:0] manhattan_distance_1_3, manhattan_distance_2_3, manhattan_distance_3_3, manhattan_distance_4_3;
  logic [10:0] min_dist_3;
  logic [1:0]  closest_centroid_3;
  always_comb begin
    manhattan_distance_1_3 = ( (x_in_1_pipe_3[2]>x_in_2_pipe_3[0]) ? (x_in_1_pipe_3[2]-x_in_2_pipe_3[0]) : (x_in_2_pipe_3[0]-x_in_1_pipe_3[2]) )
                           + ( (y_in_1_pipe_3[2]>y_in_2_pipe_3[0]) ? (y_in_1_pipe_3[2]-y_in_2_pipe_3[0]) : (y_in_2_pipe_3[0]-y_in_1_pipe_3[2]) );
    manhattan_distance_2_3 = ( (x_in_1_pipe_3[2]>x_in_2_pipe_3[1]) ? (x_in_1_pipe_3[2]-x_in_2_pipe_3[1]) : (x_in_2_pipe_3[1]-x_in_1_pipe_3[2]) )
                           + ( (y_in_1_pipe_3[2]>y_in_2_pipe_3[1]) ? (y_in_1_pipe_3[2]-y_in_2_pipe_3[1]) : (y_in_2_pipe_3[1]-y_in_1_pipe_3[2]) );
    manhattan_distance_3_3 = ( (x_in_1_pipe_3[2]>x_in_2_pipe_3[2]) ? (x_in_1_pipe_3[2]-x_in_2_pipe_3[2]) : (x_in_2_pipe_3[2]-x_in_1_pipe_3[2]) )
                           + ( (y_in_1_pipe_3[2]>y_in_2_pipe_3[2]) ? (y_in_1_pipe_3[2]-y_in_2_pipe_3[2]) : (y_in_2_pipe_3[2]-y_in_1_pipe_3[2]) );
    manhattan_distance_4_3 = ( (x_in_1_pipe_3[2]>x_in_2_pipe_3[3]) ? (x_in_1_pipe_3[2]-x_in_2_pipe_3[3]) : (x_in_2_pipe_3[3]-x_in_1_pipe_3[2]) )
                           + ( (y_in_1_pipe_3[2]>y_in_2_pipe_3[3]) ? (y_in_1_pipe_3[2]-y_in_2_pipe_3[3]) : (y_in_2_pipe_3[3]-y_in_1_pipe_3[2]) );

    min_dist_3 = manhattan_distance_1_3;
    closest_centroid_3 = 2'b00;
    if (num_players_pipe_3 >= TWO_PLAYERS && manhattan_distance_2_3 < min_dist_3) begin
      min_dist_3 = manhattan_distance_2_3;
      closest_centroid_3 = 2'b01;
    end
    if (num_players_pipe_3 >= THREE_PLAYERS && manhattan_distance_3_3 < min_dist_3) begin
      min_dist_3 = manhattan_distance_3_3;
      closest_centroid_3 = 2'b10;
    end
    if (num_players_pipe_3 == FOUR_PLAYERS && manhattan_distance_4_3 < min_dist_3) begin
      min_dist_3 = manhattan_distance_4_3;
      closest_centroid_3 = 2'b11;
    end
  end

  logic [7:0] depth_out_3;
  parallax parallax_3 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_valid_in(valid_in_pipe_3),
    .x_1_in(x_in_1_pipe_3[2]),
    .x_2_in(x_in_2_pipe_3[closest_centroid_3]),
    .depth_out(depth_out_3)
  );

  // Pipeline stage 4
  logic [1:0] num_players_pipe_4;
  logic [10:0] x_in_1_pipe_4 [3:0];
  logic [9:0]  y_in_1_pipe_4 [3:0];
  logic [10:0] x_in_2_pipe_4 [3:0];
  logic [9:0]  y_in_2_pipe_4 [3:0];
  logic valid_in_pipe_4;
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      valid_in_pipe_4 <= 1'b0;
    end else begin
      num_players_pipe_4 <= num_players_pipe_3;
        x_in_1_pipe_4[0] <= x_in_1_pipe_3[0];
        x_in_1_pipe_4[1] <= x_in_1_pipe_3[1];
        x_in_1_pipe_4[2] <= x_in_1_pipe_3[2];
        x_in_1_pipe_4[3] <= x_in_1_pipe_3[3];

        y_in_1_pipe_4[0] <= y_in_1_pipe_3[0];
        y_in_1_pipe_4[1] <= y_in_1_pipe_3[1];
        y_in_1_pipe_4[2] <= y_in_1_pipe_3[2];
        y_in_1_pipe_4[3] <= y_in_1_pipe_3[3];

        x_in_2_pipe_4[0] <= x_in_2_pipe_3[0];
        x_in_2_pipe_4[1] <= x_in_2_pipe_3[1];
        x_in_2_pipe_4[2] <= x_in_2_pipe_3[2];
        x_in_2_pipe_4[3] <= x_in_2_pipe_3[3];

        y_in_2_pipe_4[0] <= y_in_2_pipe_3[0];
        y_in_2_pipe_4[1] <= y_in_2_pipe_3[1];
        y_in_2_pipe_4[2] <= y_in_2_pipe_3[2];
        y_in_2_pipe_4[3] <= y_in_2_pipe_3[3];
      valid_in_pipe_4 <= valid_in_pipe_3;
    end
  end

  // Closest centroid for the fourth point
  logic [10:0] manhattan_distance_1_4, manhattan_distance_2_4, manhattan_distance_3_4, manhattan_distance_4_4;
  logic [10:0] min_dist_4;
  logic [1:0]  closest_centroid_4;
  always_comb begin
    manhattan_distance_1_4 = ( (x_in_1_pipe_4[3]>x_in_2_pipe_4[0]) ? (x_in_1_pipe_4[3]-x_in_2_pipe_4[0]) : (x_in_2_pipe_4[0]-x_in_1_pipe_4[3]) )
                           + ( (y_in_1_pipe_4[3]>y_in_2_pipe_4[0]) ? (y_in_1_pipe_4[3]-y_in_2_pipe_4[0]) : (y_in_2_pipe_4[0]-y_in_1_pipe_4[3]) );
    manhattan_distance_2_4 = ( (x_in_1_pipe_4[3]>x_in_2_pipe_4[1]) ? (x_in_1_pipe_4[3]-x_in_2_pipe_4[1]) : (x_in_2_pipe_4[1]-x_in_1_pipe_4[3]) )
                           + ( (y_in_1_pipe_4[3]>y_in_2_pipe_4[1]) ? (y_in_1_pipe_4[3]-y_in_2_pipe_4[1]) : (y_in_2_pipe_4[1]-y_in_1_pipe_4[3]) );
    manhattan_distance_3_4 = ( (x_in_1_pipe_4[3]>x_in_2_pipe_4[2]) ? (x_in_1_pipe_4[3]-x_in_2_pipe_4[2]) : (x_in_2_pipe_4[2]-x_in_1_pipe_4[3]) )
                           + ( (y_in_1_pipe_4[3]>y_in_2_pipe_4[2]) ? (y_in_1_pipe_4[3]-y_in_2_pipe_4[2]) : (y_in_2_pipe_4[2]-y_in_1_pipe_4[3]) );
    manhattan_distance_4_4 = ( (x_in_1_pipe_4[3]>x_in_2_pipe_4[3]) ? (x_in_1_pipe_4[3]-x_in_2_pipe_4[3]) : (x_in_2_pipe_4[3]-x_in_1_pipe_4[3]) )
                           + ( (y_in_1_pipe_4[3]>y_in_2_pipe_4[3]) ? (y_in_1_pipe_4[3]-y_in_2_pipe_4[3]) : (y_in_2_pipe_4[3]-y_in_1_pipe_4[3]) );

    min_dist_4 = manhattan_distance_1_4;
    closest_centroid_4 = 2'b00;
    if (num_players_pipe_4 >= TWO_PLAYERS && manhattan_distance_2_4 < min_dist_4) begin
      min_dist_4 = manhattan_distance_2_4;
      closest_centroid_4 = 2'b01;
    end
    if (num_players_pipe_4 >= THREE_PLAYERS && manhattan_distance_3_4 < min_dist_4) begin
      min_dist_4 = manhattan_distance_3_4;
      closest_centroid_4 = 2'b10;
    end
    if (num_players_pipe_4 == FOUR_PLAYERS && manhattan_distance_4_4 < min_dist_4) begin
      min_dist_4 = manhattan_distance_4_4;
      closest_centroid_4 = 2'b11;
    end
  end

  logic [7:0] depth_out_4;
  parallax parallax_4 (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .data_valid_in(valid_in_pipe_4),
    .x_1_in(x_in_1_pipe_4[3]),
    .x_2_in(x_in_2_pipe_4[closest_centroid_4]),
    .depth_out(depth_out_4)
  );

  assign depth_out[0] = depth_out_1;
  assign depth_out[1] = depth_out_2;
  assign depth_out[2] = depth_out_3;
  assign depth_out[3] = depth_out_4;

endmodule

`default_nettype wire