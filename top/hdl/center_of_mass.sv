`default_nettype none
module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);

    // the sum value is 1 + ... + 1024 = 524800
    // the max number of pixels is max(768*(1+...+1024), 1024*(1+...+768))
    localparam [4:0] MAX_NUM_BITS = $clog2(524800 * 768);

    logic [MAX_NUM_BITS-1:0] num_pixels;
    logic [MAX_NUM_BITS-1:0] x_sum;
    logic [MAX_NUM_BITS-1:0] y_sum;

    logic [MAX_NUM_BITS-1:0] dividend;
    logic [MAX_NUM_BITS-1:0] divisor;
    logic divide_valid_in;
    logic[MAX_NUM_BITS-1:0] quotient;
    logic[MAX_NUM_BITS-1:0] remainder;
    logic divide_valid_out;
    logic divide_error_out;
    logic divide_busy_out;
    divider #(.WIDTH(MAX_NUM_BITS)) com_divider(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(dividend),
        .divisor_in(divisor),
        .data_valid_in(divide_valid_in),
        .quotient_out(quotient),
        .remainder_out(remainder),
        .data_valid_out(divide_valid_out),
        .error_out(divide_error_out),
        .busy_out(divide_busy_out)
    );

    enum {FREE, BUSY_X, BUSY_Y} busy_state;
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            busy_state <= FREE;
            num_pixels <= 0;
            x_sum <= 0;
            y_sum <= 0;
        end 

        case (busy_state) 
            FREE: begin
                valid_out <= 1'b0;
                if (tabulate_in & ~divide_busy_out & num_pixels > 0) begin
                    busy_state <= BUSY_X;
                    dividend <= x_sum;
                    divisor <= num_pixels;
                    divide_valid_in <= 1'b1;
                end
                else if (valid_in) begin
                    num_pixels <= num_pixels + 1;
                    x_sum <= x_sum + x_in;
                    y_sum <= y_sum + y_in;
                end
            end
            BUSY_X: begin
                if(divide_valid_out) begin
                    x_out <= quotient;

                    busy_state <= BUSY_Y;
                    dividend <= y_sum;
                    divisor <= num_pixels;
                    divide_valid_in <= 1'b1;
                end else 
                    divide_valid_in <= 1'b0;
            end
            BUSY_Y: begin
                if(divide_valid_out) begin
                    y_out <= quotient;
                    valid_out <= 1'b1;

                    busy_state <= FREE;
                    num_pixels <= 0;
                    x_sum <= 0;
                    y_sum <= 0;
                end else 
                    divide_valid_in <= 1'b0;
            end
        endcase
    end
endmodule

`default_nettype wire
