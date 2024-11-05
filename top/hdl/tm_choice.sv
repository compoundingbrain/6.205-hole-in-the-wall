module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [3:0] num_ones;
  logic op;
  always_comb begin
    num_ones = 4'b0;
    for (integer i = 0; i < 8; i++) begin
        if(data_in[i] == 1) 
            num_ones++;
    end
    op = (num_ones > 4 || (num_ones == 4 && data_in[0] == 0)) ? 1'b0 : 1'b1;

    qm_out[0] = data_in[0];
    for (integer i = 1; i < 8; i++) begin
        if(op) 
            qm_out[i] = qm_out[i-1] ^ data_in[i];
        else
            qm_out[i] = ~(qm_out[i-1] ^ data_in[i]);
    end
    qm_out[8] = op;
  end

endmodule