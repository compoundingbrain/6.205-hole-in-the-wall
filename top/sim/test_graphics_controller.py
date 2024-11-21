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
    assert False, "Test bench has not been updated"
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Go through all the values from 0 to ACTIVE_H_PIXELS and ACTIVE_LINES
    # and check that the output is as expected f
    
    dut.h_count_in.value = 0
    dut.v_count_in.value = 0
    dut.pixel_in.value = 0
    dut.is_wall.value = 0
    dut.wall_color.value = 0
    await ClockCycles(dut.clk_in,1)

    for j in range(0, ACTIVE_LINES, 16):
        for i in range(0, ACTIVE_H_PIXELS, 16):
            dut.h_count_in.value = i
            dut.v_count_in.value = j
            pixel_in = random.randint(0,2**16-1)
            dut.pixel_in.value = pixel_in
            is_wall = random.randint(0,1)
            dut.is_wall.value = is_wall
            wall_color = random.randint(0,2**16-1)
            dut.wall_color.value = wall_color
            await RisingEdge(dut.clk_in)
            if is_wall:
                assert dut.pixel_out.value == wall_color
            else:
                assert dut.pixel_out.value == pixel_in
            await ClockCycles(dut.clk_in,1)

    
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

