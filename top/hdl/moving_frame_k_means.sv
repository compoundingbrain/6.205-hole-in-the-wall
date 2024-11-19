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
  output logic [10:0] x_out [3:0], // make this 4 wide for 4 players
  output logic [9:0] y_out [3:0], // make this 4 wide for 4 players
  output logic valid_out
);
  // pipelined valid_out
  logic pipe_valid_out;

  // x and y coordinates of the first centroid
  logic [10:0] centroid_1_x, centroid_1_y;
  logic [10:0] x_out_1;
  logic [9:0] y_out_1;
  assign x_out[0] = x_out_1;
  assign y_out[0] = y_out_1;
  // x and y coordinates of the second centroid
  logic [10:0] centroid_2_x, centroid_2_y;
  logic [10:0] x_out_2;
  logic [9:0] y_out_2;
  assign x_out[1] = x_out_2;
  assign y_out[1] = y_out_2;
  // x and y coordinates of the third centroid
  logic [10:0] centroid_3_x, centroid_3_y;
  logic [10:0] x_out_3;
  logic [9:0] y_out_3;
  assign x_out[2] = x_out_3;
  assign y_out[2] = y_out_3;
  // x and y coordinates of the fourth centroid
  logic [10:0] centroid_4_x, centroid_4_y;
  logic [10:0] x_out_4;
  logic [9:0] y_out_4;
  assign x_out[3] = x_out_4;
  assign y_out[3] = y_out_4;

  // manhattan distances from the centroids to the current COM
  logic [10:0] manhattan_distance_1, manhattan_distance_2, manhattan_distance_3, manhattan_distance_4;
  
  // which centroid is closest to the current COM
  logic [1:0] closest_centroid;

  // Calculate the manhattan distance to each centroid, then calculate which is the smallest
  always_comb begin
    manhattan_distance_1 = (x_in > centroid_1_x) ? (x_in - centroid_1_x) : (centroid_1_x - x_in) + (y_in > centroid_1_y) ? (y_in - centroid_1_y) : (centroid_1_y - y_in);
    manhattan_distance_2 = (x_in > centroid_2_x) ? (x_in - centroid_2_x) : (centroid_2_x - x_in) + (y_in > centroid_2_y) ? (y_in - centroid_2_y) : (centroid_2_y - y_in);
    manhattan_distance_3 = (x_in > centroid_3_x) ? (x_in - centroid_3_x) : (centroid_3_x - x_in) + (y_in > centroid_3_y) ? (y_in - centroid_3_y) : (centroid_3_y - y_in);
    manhattan_distance_4 = (x_in > centroid_4_x) ? (x_in - centroid_4_x) : (centroid_4_x - x_in) + (y_in > centroid_4_y) ? (y_in - centroid_4_y) : (centroid_4_y - y_in);

    // Determine which centroid is closest
    if ((manhattan_distance_1 <= manhattan_distance_2) && 
        (manhattan_distance_1 <= manhattan_distance_3) && 
        (manhattan_distance_1 <= manhattan_distance_4)) begin
      closest_centroid = 2'b00;
    end else if ((manhattan_distance_2 <= manhattan_distance_3) && 
                 (manhattan_distance_2 <= manhattan_distance_4)) begin
      closest_centroid = 2'b01;
    end else if (manhattan_distance_3 <= manhattan_distance_4) begin
      closest_centroid = 2'b10;
    end else begin
      closest_centroid = 2'b11;
    end
  end

  // Add combinational logic here that will calculate the closest centroid
  // for each pixel doing the manhattan distance

  // module center_of_mass (
  //                        input wire clk_in,
  //                        input wire rst_in,
  //                        input wire [10:0] x_in,
  //                        input wire [9:0]  y_in,
  //                        input wire valid_in,
  //                        input wire tabulate_in,
  //                        output logic [10:0] x_out,
  //                        output logic [9:0] y_out,
  //                        output logic valid_out);

  center_of_mass com_1(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .x_in(x_in),
    .y_in(y_in),
    .valid_in(valid_in),
    .tabulate_in(tabulate_in),
    .x_out(x_out_1),
    .y_out(y_out_1),
    .valid_out(pipe_valid_out)
  );

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      // TODO: add the default centroids based on the number of players
      centroid_1_x <= 0;
      centroid_1_y <= 0;
    end else begin
      if (pipe_valid_out) begin
        centroid_1_x <= x_out_1;
        centroid_1_y <= y_out_1;
        valid_out <= pipe_valid_out;
      end else begin
        valid_out <= 0;
      end
    end
  end

endmodule

`default_nettype wire

