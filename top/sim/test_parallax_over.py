import cocotb
import os
import sys
from math import log, ceil
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
import random

RESOLUTION_WIDTH = 1280
SENSOR_WIDTH = 0.334646
PIXEL_DENSITY = RESOLUTION_WIDTH / SENSOR_WIDTH
FOCAL_LENGTH = 0.1295276
BASELINE_DISTANCE = 6

def get_expected_depth(x1, x2):
    # using formula Z (depth in inches) = (Focal Length * Baseline Distance * Pixel Density) / (x_1 - x_2)
    if x1 == x2: return 0xFF 
    return int((FOCAL_LENGTH * BASELINE_DISTANCE * PIXEL_DENSITY) / abs(x1 - x2))

@cocotb.test()
async def test_parallax_over_basic(dut):
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    dut.data_valid_in.value = 0
    dut.num_players.value = 3 # its x-1 the number of players you want to test. So this is 2.
    await ClockCycles(dut.clk_in, 5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Example test: 2 players
    # Set centroids in board 1
    x1_vals = [300, 100, 200, 400] # 0 to 3, 1 to 2, 2 to 0, and 3 to 1 
    y1_vals = [400, 200, 300, 100]
    # Set centroids in board 2, slightly shifted
    x2_vals = [198, 399, 95, 298]
    y2_vals = [302, 101, 202, 403]

    dut.data_valid_in.value = 1
    dut.x_in_1[0].value = x1_vals[0]
    dut.y_in_1[0].value = y1_vals[0]
    dut.x_in_1[1].value = x1_vals[1]
    dut.y_in_1[1].value = y1_vals[1]
    dut.x_in_2[0].value = x2_vals[0]
    dut.y_in_2[0].value = y2_vals[0]
    dut.x_in_2[1].value = x2_vals[1]
    dut.y_in_2[1].value = y2_vals[1]
    dut.x_in_1[2].value = x1_vals[2]
    dut.y_in_1[2].value = y1_vals[2]
    dut.x_in_1[3].value = x1_vals[3]
    dut.y_in_1[3].value = y1_vals[3]
    dut.x_in_2[2].value = x2_vals[2]
    dut.y_in_2[2].value = y2_vals[2]
    dut.x_in_2[3].value = x2_vals[3]
    dut.y_in_2[3].value = y2_vals[3]

    await RisingEdge(dut.clk_in)
    dut.data_valid_in.value = 0

    # Wait a lot of cycles to let parallax finish
    await ClockCycles(dut.clk_in, 10000)

    # Check results
    # depth_out[0] corresponds to first player's matched centroid
    # depth_out[1] corresponds to second player's matched centroid
    expected_0 = get_expected_depth(x1_vals[0], x2_vals[3])
    expected_1 = get_expected_depth(x1_vals[1], x2_vals[2])
    expected_2 = get_expected_depth(x1_vals[2], x2_vals[1])
    expected_3 = get_expected_depth(x1_vals[3], x2_vals[0])
    assert dut.depth_out[0].value.integer == expected_0, f"Player 1 depth mismatch: got {dut.depth_out[0].value.integer}, expected {expected_0}"
    assert dut.depth_out[1].value.integer == expected_1, f"Player 2 depth mismatch: got {dut.depth_out[1].value.integer}, expected {expected_1}"
    assert dut.depth_out[2].value.integer == expected_2, f"Player 3 depth mismatch: got {dut.depth_out[2].value.integer}, expected {expected_2}"
    assert dut.depth_out[3].value.integer == expected_3, f"Player 4 depth mismatch: got {dut.depth_out[3].value.integer}, expected {expected_3}"

def test_runner():
    """Parallax module testing."""
    proj_path = Path(__file__).resolve().parent.parent
    
    
    # Setup simulation
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    
    # Add simulation model path
    sys.path.append(str(proj_path / "sim" / "model"))
    
    # Define sources
    sources = [proj_path / "hdl" / "parallax_over.sv", proj_path / "hdl" / "parallax.sv", proj_path / "hdl" / "divider.sv"]
    
    # Build arguments
    build_test_args = ["-Wall"]
    
    # Get and configure runner
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="parallax_over",
        always=True,
        build_args=build_test_args,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    # Run tests
    run_test_args = []
    runner.test(
        hdl_toplevel="parallax_over",
        test_module="test_parallax_over",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_runner()