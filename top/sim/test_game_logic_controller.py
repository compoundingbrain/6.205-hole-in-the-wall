import cocotb
import os
import random
import re
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner, Verilog

SCREEN_WIDTH = 3
SCREEN_HEIGHT = 3
GOAL_DEPTH = 3
GOAL_DEPTH_DELTA = 1
MAX_WALL_DEPTH = 5
MAX_FRAMES_PER_WALL_TICK = 1
BIT_MASK_DOWN_SAMPLE_FACTOR = 1

async def do_setup(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # cocotb.start_soon(test_spi_device(dut))
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    dut.hcount_in.value = 0
    dut.vcount_in.value = 0
    dut.pixel_in.value = 0
    dut.data_valid_in.value = 0
    dut.is_person_in.value = 0
    dut.player_depth_in.value = 0
    
    await ClockCycles(dut.clk_in, 3) #wait three clock cycles
    await  FallingEdge(dut.clk_in)
    dut.rst_in.value = 0 #un reset device
    await FallingEdge(dut.clk_in)

"""
Example Test Code:
dut._log.info("Starting...")
cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
dut._log.info("Holding reset...")
dut.rst_in.value = 1
await ClockCycles(dut.clk_in, 3) #wait three clock cycles
await  FallingEdge(dut.clk_in)
dut.rst_in.value = 0 #un reset device
await ClockCycles(dut.clk_in, 1000) #wait a few clock cycles
"""
@cocotb.test()
async def test_a(dut):
    await do_setup(dut)

    for round in range(2):
        for frame in range(5):
            for y in range(SCREEN_HEIGHT):
                for x in range(SCREEN_WIDTH):
                    dut.hcount_in.value = x
                    dut.vcount_in.value = y
                    dut.pixel_in.value = 0
                    dut.data_valid_in.value = 1
                    dut.is_person_in.value = 0
                    dut.player_depth_in.value = 0
                    await FallingEdge(dut.clk_in)    

def test_runner():
    """Simulate the counter using the Python runner."""
    
    MODULE_NAME = re.search(r"test_(.*)\.py", os.path.basename(__file__)).group(1)

    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    runner = get_runner(sim)
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / f"{MODULE_NAME}.sv", 
        proj_path/"hdl"/"evt_counter.sv",
        proj_path/"hdl"/"evt_counter_dynamic.sv",
        proj_path/"hdl"/"wall_bit_mask.sv",
        proj_path/"hdl"/"xilinx_single_port_ram_read_first.sv"]
    build_test_args = ["-Wall"]
    parameters = {"SCREEN_WIDTH": SCREEN_WIDTH,
                  "SCREEN_HEIGHT": SCREEN_HEIGHT,
                  "GOAL_DEPTH": GOAL_DEPTH,
                  "GOAL_DEPTH_DELTA": GOAL_DEPTH_DELTA,
                  "MAX_WALL_DEPTH": MAX_WALL_DEPTH,
                  "MAX_FRAMES_PER_WALL_TICK": MAX_FRAMES_PER_WALL_TICK,
                  "BIT_MASK_DOWN_SAMPLE_FACTOR": BIT_MASK_DOWN_SAMPLE_FACTOR}
    sys.path.append(str(proj_path / "sim"))
    runner.build(
        sources=sources,
        hdl_toplevel=MODULE_NAME,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=MODULE_NAME,
        test_module=f"test_{MODULE_NAME}",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    test_runner()
