`timescale 1ns / 1ps
`default_nettype none

module uart_receive
  #(
    parameter INPUT_CLOCK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter DATA_WIDTH = 8
    )
   (
    input wire 	       clk_in,
    input wire 	       rst_in,
    input wire 	       rx_wire_in,
    output logic       new_data_out,
    output logic [DATA_WIDTH-1:0] data_byte_out
    );

    parameter BAUD_BIT_PERIOD = INPUT_CLOCK_FREQ / BAUD_RATE;
    parameter BAUD_BIT_PERIOD_BITS = $clog2(BAUD_BIT_PERIOD);

    enum {IDLE, START, DATA, STOP, TRANSMIT} state;
    logic [$clog2(DATA_WIDTH):0] num_bits_rxd;

    logic [BAUD_BIT_PERIOD_BITS-1:0] baud_period_counter;
    logic clock_reset = 1'b0;
    counter bit_counter(
        .clk_in(clk_in),
        .rst_in(rst_in | clock_reset),
        .period_in(BAUD_BIT_PERIOD),
        .count_out(baud_period_counter)
    );

    always_ff @(posedge clk_in) begin
      case(state)
        IDLE: begin
          new_data_out <= 1'b0;
          if(rx_wire_in == 1'b0) begin
            state <= START;
            num_bits_rxd <= 0;
            clock_reset <= 1'b0;
          end else 
            clock_reset <= 1'b1;
        end
        START: begin
          if((0 <= baud_period_counter && baud_period_counter <= BAUD_BIT_PERIOD/2) && rx_wire_in != 1'b0) begin
            // bad start bit within first half of start bit period
            state <= IDLE;
            clock_reset <= 1'b1;
          end
          else if(baud_period_counter == BAUD_BIT_PERIOD-1)
            // good bit, continue to data
            state <= DATA;
        end
        DATA: begin
          if(num_bits_rxd == DATA_WIDTH && baud_period_counter == BAUD_BIT_PERIOD-1)
            // recieved 8 bits
            state <= STOP;
          else if(baud_period_counter == BAUD_BIT_PERIOD/2) begin
            data_byte_out = {rx_wire_in, data_byte_out[DATA_WIDTH-1:1]};
            num_bits_rxd <= num_bits_rxd+1;
          end
        end
        STOP: begin
          if((BAUD_BIT_PERIOD/2 <= baud_period_counter && baud_period_counter <= 3*BAUD_BIT_PERIOD/4) && rx_wire_in != 1'b1) begin
            // bad stop bit within third quarter of stop bit period
            state <= IDLE;
            clock_reset <= 1'b1;
          end
          else if(baud_period_counter == BAUD_BIT_PERIOD-1) begin
            // good bit, continue to transmit
            state <= TRANSMIT;
          end
        end
        TRANSMIT: begin
            state <= IDLE;
            new_data_out <= 1'b1;
            clock_reset <= 1'b1;
        end
      endcase
    end
endmodule // uart_receive

`default_nettype wire