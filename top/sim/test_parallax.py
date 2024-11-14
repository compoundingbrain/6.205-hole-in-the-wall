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

# Parameters matching those in parallax.sv
RESOLUTION_WIDTH = 1280
SENSOR_WIDTH = 0.334646
PIXEL_DENSITY = RESOLUTION_WIDTH / SENSOR_WIDTH
FOCAL_LENGTH = 0.1295276
BASELINE_DISTANCE = 6

def get_expected_depth(x1, x2):
    # using formula Z (depth in inches) = (Focal Length * Baseline Distance * Pixel Density) / (x_1 - x_2)
    if x1 == x2: return 0xFF 
    return int(ceil((FOCAL_LENGTH * BASELINE_DISTANCE * PIXEL_DENSITY) / abs(x1 - x2)))

@cocotb.test()
async def test_parallax_basic(dut):
    """Test basic functionality of parallax depth calculation"""
    dut._log.info("Starting basic parallax test...")
    
    # Start clock and reset
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in, 1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test cases with known disparities
    # x_1_in, x_2_in
    test_cases = [
        (100, 90, get_expected_depth(100, 90)),    # Close object (large disparity)
        (200, 198, get_expected_depth(200, 198)),    # Far object (small disparity)
        (150, 150, get_expected_depth(150, 150)),    # Zero disparity (should output 0xFF)
        (500, 400, get_expected_depth(500, 400)),  # Very close object
    ]

    for x1, x2, disparity in test_cases:
        dut.x_1_in.value = x1
        dut.x_2_in.value = x2
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        await RisingEdge(dut.clk_in)
        
        if disparity == 0:
            assert dut.depth_out.value == 0xFF, f"Expected 0xFF for zero disparity, got {dut.depth_out.value}"
        else:
            # Depth should be inversely proportional to disparity
            assert dut.depth_out.value.integer > 0, f"Depth should be positive, got {dut.depth_out.value} for x1={x1}, x2={x2}"

@cocotb.test()
async def test_parallax_edge_cases(dut):
    """Test edge cases for parallax depth calculation"""
    dut._log.info("Starting edge case tests...")
    
    # Start clock and reset
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in, 5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Test maximum disparity
    dut.x_1_in.value = 0xFFF  # Maximum 12-bit value
    dut.x_2_in.value = 0
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    expected_depth = get_expected_depth(0xFFF, 0)
    assert dut.depth_out.value.integer == expected_depth, f"Expected {expected_depth} for maximum disparity, got {dut.depth_out.value.integer}"

    # Test minimum disparity
    dut.x_1_in.value = 0
    dut.x_2_in.value = 0xFFF  # Maximum 12-bit value
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    expected_depth = get_expected_depth(0, 0xFFF)
    assert dut.depth_out.value.integer == expected_depth, f"Expected {expected_depth} for minimum disparity, got {dut.depth_out.value.integer}"


def test_runner():
    """Parallax module testing."""
    proj_path = Path(__file__).resolve().parent.parent
    
    # Define parameters matching the SystemVerilog module
    parameters = {
        'RESOLUTION_WIDTH': RESOLUTION_WIDTH,
        'SENSOR_WIDTH': SENSOR_WIDTH,
        'FOCAL_LENGTH': FOCAL_LENGTH,
        'BASELINE_DISTANCE': BASELINE_DISTANCE
    }
    
    # Setup simulation
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    
    # Add simulation model path
    sys.path.append(str(proj_path / "sim" / "model"))
    
    # Define sources
    sources = [proj_path / "hdl" / "parallax.sv"]
    
    # Build arguments
    build_test_args = ["-Wall"]
    
    # Get and configure runner
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="parallax",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True
    )
    
    # Run tests
    run_test_args = []
    runner.test(
        hdl_toplevel="parallax",
        test_module="test_parallax",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_runner()
