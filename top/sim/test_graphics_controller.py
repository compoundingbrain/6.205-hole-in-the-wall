import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner
import random

ACTIVE_H_PIXELS = 1280
ACTIVE_LINES = 720

@cocotb.test()
async def test_a(dut):
    """cocotb test for image_sprite"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Go through all the values from 0 to ACTIVE_H_PIXELS and ACTIVE_LINES
    # and check that the output is as expected for varied values of is_wall and wall_color

    for j in range(0, ACTIVE_LINES):
        for i in range(0, ACTIVE_H_PIXELS):
            dut.h_count_in.value = i
            dut.v_count_in.value = j
            pixel_in = random.randint(0,2**16-1)
            dut.pixel_in.value = pixel_in
            is_wall = random.randint(0,1)
            dut.is_wall.value = is_wall
            wall_color = random.randint(0,2**16-1)
            dut.wall_color.value = wall_color
            await ClockCycles(dut.clk_in,1)
            assert dut.data_valid_out.value == 1
            if is_wall:
                assert dut.pixel_out.value == wall_color
            else:
                assert dut.pixel_out.value == pixel_in
    
    # Test out of bounds values
    dut.h_count_in.value = ACTIVE_H_PIXELS
    dut.v_count_in.value = ACTIVE_LINES
    await ClockCycles(dut.clk_in,1)
    assert dut.data_valid_out.value == 0
    
def is_runner():
    """Graphics Controller Testing."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "graphics_controller.sv"]
    build_test_args = ["-Wall"]
    parameters = {'ACTIVE_H_PIXELS':ACTIVE_H_PIXELS,'ACTIVE_LINES':ACTIVE_LINES}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="graphics_controller",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="graphics_controller",
        test_module="test_graphics_controller",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

