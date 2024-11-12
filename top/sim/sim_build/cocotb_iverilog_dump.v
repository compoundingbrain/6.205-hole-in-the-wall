module cocotb_iverilog_dump();
initial begin
    $dumpfile("/home/nathan/holeInTheWall-62050/top/sim/sim_build/wall_bit_mask.fst");
    $dumpvars(0, wall_bit_mask);
end
endmodule
