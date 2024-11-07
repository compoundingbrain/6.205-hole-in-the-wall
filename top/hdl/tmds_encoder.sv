`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,       // Video data (red, green, or blue)
  input wire [1:0] control_in,    // For blue set to {vs, hs}, else will be 0
  input wire ve_in,               // Video data enable
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;

  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m)
  );

  logic [4:0] prev_count;
  logic [4:0] new_prev_count;
  logic [3:0] sum_0s;
  logic [3:0] sum_1s;
  logic [9:0] q_out;

  // Combinational logic block
  always_comb begin
    // Default assignments
    sum_1s = 0;
    sum_0s = 0;
    q_out = 10'b0;
    new_prev_count = prev_count;

    if (rst_in) begin
        new_prev_count = 0;
        q_out = 10'b0;
    end else if (!ve_in) begin
        new_prev_count = 0;
        case (control_in)
            2'b00: q_out = 10'b1101010100;
            2'b01: q_out = 10'b0010101011;
            2'b10: q_out = 10'b0101010100;
            2'b11: q_out = 10'b1010101011;
            default: q_out = 10'b0; // Default case for safety
        endcase
    end else begin
        // Calculate the number of 1s in q_m[7:0]
        for (int i = 0; i < 8; i++) begin
            sum_1s = sum_1s + q_m[i];
        end
        sum_0s = 5'd8 - sum_1s;

        // Determine q_out and new_prev_count based on the algorithm
        if ((prev_count == 0) || (sum_0s == sum_1s)) begin
            q_out[9] = ~q_m[8];
            q_out[8] = q_m[8];
            q_out[7:0] = q_m[8] ? q_m[7:0] : ~q_m[7:0];

            if (!q_m[8]) begin
                new_prev_count = prev_count + sum_0s - sum_1s;
            end else begin
                new_prev_count = prev_count + sum_1s - sum_0s;
            end
        end else begin
            if (((!prev_count[4] && prev_count > 0) && (sum_1s > sum_0s)) || ((prev_count[4]) && (sum_1s < sum_0s))) begin
                q_out[9] = 1'b1;
                q_out[8] = q_m[8];
                q_out[7:0] = ~q_m[7:0];
                new_prev_count = prev_count + 2'd2*q_m[8] + sum_0s - sum_1s;
            end else begin
                q_out[9] = 1'b0;
                q_out[8] = q_m[8];
                q_out[7:0] = q_m[7:0];
                new_prev_count = prev_count - 2'd2*(!q_m[8]) + sum_1s - sum_0s;
            end
        end
    end
  end

  // Sequential logic block
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        prev_count <= 0;
        tmds_out <= 0;
    end else begin
        prev_count <= new_prev_count;
        tmds_out <= q_out;
    end
  end

endmodule

`default_nettype wire