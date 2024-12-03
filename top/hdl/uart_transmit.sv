`timescale 1ns / 1ps
`default_nettype none
module uart_transmit 
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000, 
    parameter BAUD_RATE = 9600,
    parameter DATA_WIDTH = 8
    )
  ( input wire          clk_in,
    input wire          rst_in,
    input wire [DATA_WIDTH-1:0]    data_byte_in,
    input wire          trigger_in,
    output logic        busy_out,
    output logic        tx_wire_out
  );
    parameter BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
    parameter BAUD_BIT_PERIOD_BITS = $clog2(BAUD_BIT_PERIOD);

    enum {RUNNING, IDLE} state;
    logic [DATA_WIDTH:0] data_in_copy;
    logic [$clog2(DATA_WIDTH):0] num_sent;

    logic [BAUD_BIT_PERIOD_BITS-1:0] baud_period_counter;
    logic clock_reset = 1'b0;
    counter bit_counter(
        .clk_in(clk_in),
        .rst_in(rst_in | clock_reset),
        .period_in(BAUD_BIT_PERIOD),
        .count_out(baud_period_counter)
    );

    always_ff @(posedge clk_in) begin
        if(rst_in) begin
            data_in_copy <= 0;
            busy_out <= 1'b0;
            tx_wire_out <= 1'b1;
            state <= IDLE;
        end else if (state == IDLE && trigger_in==1) begin
            state <= RUNNING;
            data_in_copy <= {1'b1, data_byte_in}; // data byte + end bit
            busy_out <= 1'b1;
            tx_wire_out <= 1'b0; // send start bit
            clock_reset<=1'b1;
            num_sent<=0;
        end else if (state == RUNNING) begin
            clock_reset <= 1'b0;
            if(baud_period_counter == BAUD_BIT_PERIOD-1) begin
                if (num_sent == DATA_WIDTH+1) begin
                    state <= IDLE;
                    busy_out <= 1'b0;
                    tx_wire_out <= 1'b1;
                end else begin
                    tx_wire_out <= data_in_copy[0];
                    data_in_copy <= {1'b0, data_in_copy[DATA_WIDTH:1]};
                    num_sent <= num_sent + 1;
                end
            end
        end
    end
endmodule // uart_transmit
`default_nettype wire
