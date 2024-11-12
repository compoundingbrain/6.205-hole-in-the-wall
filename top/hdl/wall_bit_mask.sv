`timescale 1ns / 1ps
`default_nettype none

module wall_bit_mask #(
    parameter SCREEN_WIDTH = 1280, 
    parameter SCREEN_HEIGHT = 720, 
    parameter DOWN_SAMPLE_FACTOR = 16,
    parameter BIT_MASK_WIDTH = SCREEN_WIDTH/DOWN_SAMPLE_FACTOR,
    parameter BIT_MASK_HEIGHT = SCREEN_HEIGHT/DOWN_SAMPLE_FACTOR, 
    parameter BIT_MASK_SIZE = BIT_MASK_WIDTH * BIT_MASK_HEIGHT
    )
    (
    input wire 	       clk_in,
    input wire 	       rst_in,
    
    input wire valid_in,
    input wire [$clog2(NUM_BITMASKS_PER_BRAM)-1:0] bitmask_idx,

    output logic valid_out,
    output logic [BIT_MASK_SIZE - 1:0] wall_bit_mask
);
    localparam BRAM_MEMORY = 36000;
    localparam NUM_BITMASKS_PER_BRAM = BRAM_MEMORY / (BIT_MASK_SIZE);

    // Delay valid out signal by 2 cycles
    logic valid_out_pipe = 1'b0;
    always_ff @(posedge clk_in) begin
        valid_out_pipe <= valid_in;
        valid_out <= valid_out_pipe;
    end

    // Bit masks are down sampled by 16 i.e. 80x45 = 3600 bits. 
    // We can store 36kb/3600 = 10 bit masks in BRAM.
    xilinx_single_port_ram_read_first
        #(
        .RAM_WIDTH(BIT_MASK_SIZE),
        .RAM_DEPTH(NUM_BITMASKS_PER_BRAM),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
        .INIT_FILE("walls.mem")
        ) bit_masks
        (
        .clka(clk_in),         // Clock
        .rsta(rst_in),         // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .addra(bitmask_idx),   // Address bus, width determined from RAM_DEPTH
        .douta(wall_bit_mask), // RAM output data, width determined from RAM_WIDTH
        
        .wea(1'b0),            // Write enable
        .dina(0)               // RAM input data, width determined from RAM_WIDTH
    );

endmodule   

`default_nettype wire
