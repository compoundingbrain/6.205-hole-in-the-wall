`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);
 
  logic [4:0] count; // 2s-complement running tally of #1s - #0s difference
  logic [8:0] q_m;
 
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  logic [3:0] num_ones;
  logic [3:0] num_zeros;
  always_comb begin
    num_ones = 4'b0;
    for (integer i = 0; i < 8; i++) begin
        if(q_m[i] == 1) 
            num_ones++;
    end
    num_zeros = 8 - num_ones;
  end
 
  always_ff @(posedge clk_in) begin
    if(rst_in) 
        tmds_out <= 10'b0;
    else if (~ve_in) begin
        count <= 0;
        case(control_in)
            2'b00: tmds_out <= 10'b1101010100;
            2'b01: tmds_out <= 10'b0010101011;
            2'b10: tmds_out <= 10'b0101010100;
            2'b11: tmds_out <= 10'b1010101011;
        endcase
    end 
    else begin
        if(count == 0 || num_ones == num_zeros) begin
            tmds_out <= {~q_m[8], q_m[8], (q_m[8]) ? q_m[7:0] : ~q_m[7:0]};
            if(q_m[8] == 0) 
                count <= count + num_zeros - num_ones;
            else
                count <= count + num_ones - num_zeros;
        end else begin
            if((count[4]==1'b0 && num_ones > num_zeros) || (count[4]==1'b1 && num_zeros > num_ones)) begin
                tmds_out <= {1'b1, q_m[8], ~q_m[7:0]};
                count <= count + 2*q_m[8] + (num_zeros - num_ones);
            end
            else begin
                tmds_out <= {1'b0, q_m[8], q_m[7:0]};
                count <= count - 2*((q_m[8]) ? 1'b0 : 1'b1) + (num_ones - num_zeros);
            end
        end
    end
  end 
endmodule

`default_nettype wire


