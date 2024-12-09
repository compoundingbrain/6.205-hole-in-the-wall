module uart_sim_test (
    input  wire          clk_in,
    input  wire          rst_in,

    input  wire [10:0]   tx_data_in,
    input  wire          tx_trigger_in,
    output logic         busy_out,
    // output logic         tx_wire_out,

    // input  wire          rx_wire_in,
    output logic         rx_trigger_out,
    output logic [10:0]  rx_data_out
);

    localparam UART_BAUD_RATE = 115200;
    logic line;

    uart_transmit #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_tx_y (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .data_byte_in(tx_data_in),
        .trigger_in(tx_trigger_in),
        .busy_out(),
        .tx_wire_out(line)
    );

    logic [1:0] uart_rx_buf;
    always_comb begin
        uart_rx_buf[1] = line;
        uart_rx_buf[0] = uart_rx_buf[1];
    end

    logic [10:0] rx_data;
    uart_receive #(.BAUD_RATE(UART_BAUD_RATE), .DATA_WIDTH(11)) uart_rx_x (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .rx_wire_in(uart_rx_buf[0]),
        .new_data_out(rx_trigger_out),
        .data_byte_out(rx_data)
    );


    // Store COM on recieve
    always_ff @(posedge clk_in) begin
        if (rx_trigger_out) begin
            rx_data_out <= rx_data;
        end
    end

endmodule