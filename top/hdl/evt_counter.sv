`default_nettype none

module evt_counter
  # (
    parameter MAX_COUNT = 16
  )
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[31:0]  count_out
  );
 
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 32'b0;
    end else begin
      if (count_out == MAX_COUNT - 1 && evt_in) begin
        count_out <= 32'b0;
      end else begin
        count_out <= count_out + evt_in;
      end
    end
  end
endmodule

`default_nettype wire