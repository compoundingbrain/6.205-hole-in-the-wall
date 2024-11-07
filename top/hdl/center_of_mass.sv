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
	
    logic [31:0] sum_x, sum_y;
    logic [31:0] valid_pixel_count;

    logic mode; // 0 = counting, 1 = dividing

    logic x_dividing_complete, y_dividing_complete;

    // Counting Mode
    //    if not tabulate_in then add to sum_x, sum_y, and count if valid in.
    //    if tabulate_in then go to dividing mode
    // Dividing Mode
    //    if not busy, then send in x_sum, y_sum, and valid_pixel_count
    //    wait for data_valid_out and not error_out for both x and y to be ready then output them.

    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            x_out <= 0;
            y_out <= 0;
            valid_out <= 0;
            sum_x <= 0;
            sum_y <= 0;
            valid_pixel_count <= 0;
            mode <= 0; // counting
            x_dividing_complete <= 0;
            y_dividing_complete <= 0;
            trigger_x_divide <= 0;
            trigger_y_divide <= 0;
        end else begin

            if (mode == 0) begin // counting

                valid_out <= 0;

                if (valid_in) begin
                    sum_x <= sum_x + x_in;
                    sum_y <= sum_y + y_in;
                    valid_pixel_count <= valid_pixel_count + 1;
                end    
                
                if (tabulate_in) begin
                    mode <= 1; // dividing time
                    trigger_x_divide <= 1;
                    trigger_y_divide <= 1;
                end 

            end else if (mode == 1) begin // dividing

                // dividers have begun since mode == 1
                trigger_x_divide <= 0;
                trigger_y_divide <= 0;

                // if both dividers are done at the same time, output the results
                if (x_dividing_complete && y_dividing_complete) begin
                    mode <= 0;
                    sum_x <= 0;
                    sum_y <= 0;
                    valid_pixel_count <= 0;
                    x_dividing_complete <= 0;
                    y_dividing_complete <= 0;
                    valid_out <= 1;
                end else if (x_valid_out && !x_error_out && y_valid_out && !y_error_out) begin
                    x_dividing_complete <= 0; // do not need to set
                    y_dividing_complete <= 0;
                    x_out <= x_quotient_out;
                    y_out <= y_quotient_out;
                    valid_out <= 1;
                    mode <= 0;
                    sum_x <= 0;
                    sum_y <= 0;
                    valid_pixel_count <= 0;
                end else if (x_valid_out && !x_error_out) begin
                    x_dividing_complete <= 1;
                    x_out <= x_quotient_out;
                end else if (y_valid_out && !y_error_out) begin
                    y_dividing_complete <= 1;
                    y_out <= y_quotient_out;
                end else if (!x_error_out && !y_error_out) begin
                    valid_out <= 0;
                end else begin // there was an error so reset
                    x_out <= 0;
                    y_out <= 0;
                    valid_out <= 0;
                    sum_x <= 0;
                    sum_y <= 0;
                    valid_pixel_count <= 0;
                    mode <= 0; // counting
                    x_dividing_complete <= 0;
                    y_dividing_complete <= 0;
                end

            end

        end
    end

    logic x_valid_out, x_error_out, trigger_x_divide;
    logic [31:0] x_quotient_out;

    divider x_divider(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(sum_x),
        .divisor_in(valid_pixel_count),
        .data_valid_in(trigger_x_divide),
        .quotient_out(x_quotient_out),
        .remainder_out(),
        .data_valid_out(x_valid_out),
        .error_out(x_error_out),
        .busy_out()
    );

    logic y_valid_out, y_error_out, trigger_y_divide;
    logic [31:0] y_quotient_out;

    divider y_divider(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(sum_y),
        .divisor_in(valid_pixel_count),
        .data_valid_in(trigger_y_divide),
        .quotient_out(y_quotient_out),
        .remainder_out(),
        .data_valid_out(y_valid_out),
        .error_out(y_error_out),
        .busy_out()
    );

endmodule

`default_nettype wire
