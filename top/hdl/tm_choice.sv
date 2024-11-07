module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [3:0] sum;

  always_comb begin
    // sum the number of bits in data_in
    sum = 0;
    for (int i = 0; i < 8; i++) begin
      sum = sum + data_in[i];
    end

    if (sum > 4 || (sum ==4 && data_in[0] == 0)) begin // do option 2
      qm_out[0] = data_in[0];
      qm_out[1] = !(data_in[1] ^ qm_out[0]);
      qm_out[2] = !(data_in[2] ^ qm_out[1]);
      qm_out[3] = !(data_in[3] ^ qm_out[2]);
      qm_out[4] = !(data_in[4] ^ qm_out[3]);
      qm_out[5] = !(data_in[5] ^ qm_out[4]);
      qm_out[6] = !(data_in[6] ^ qm_out[5]);
      qm_out[7] = !(data_in[7] ^ qm_out[6]);
      qm_out[8] = 0;
    end else begin // do option 1
      qm_out[0] = data_in[0];
      qm_out[1] = data_in[1] ^ qm_out[0];
      qm_out[2] = data_in[2] ^ qm_out[1];
      qm_out[3] = data_in[3] ^ qm_out[2];
      qm_out[4] = data_in[4] ^ qm_out[3];
      qm_out[5] = data_in[5] ^ qm_out[4];
      qm_out[6] = data_in[6] ^ qm_out[5];
      qm_out[7] = data_in[7] ^ qm_out[6];
      qm_out[8] = 1;
    end
  end 



endmodule //end tm_choice
