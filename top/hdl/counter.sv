module counter(     input wire clk_in,
                    input wire rst_in,
                    input wire [31:0] period_in,
                    output logic [31:0] count_out
              );

    logic [31:0] cp;
    always_comb begin 
      cp = count_out + 1;
      if (cp >= period_in) begin
        cp = 0;
      end 
      if (rst_in == 1) begin
        cp = 0;
      end
    end

    always_ff @(posedge clk_in) begin
      count_out <= cp;
    end
endmodule
