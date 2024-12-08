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

async def do_setup(dut):
    """cocotb test for seven segment controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    # cocotb.start_soon(test_spi_device(dut))
    dut._log.info("Holding reset...")
    dut.rst_in.value = 1
    dut.hcount_in.value = 0
    dut.vcount_in.value = 0
    dut.wall_depth_in.value = 0
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

    for v in range(1):
        for h in range(20):
            dut.hcount_in.value = h
            dut.vcount_in.value = v
            dut.wall_depth_in.value = 3
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
        proj_path / "hdl" / f"{MODULE_NAME}.sv"]
    build_test_args = ["-Wall"]
    parameters = {
        "GOAL_DEPTH": 3,
        "GOAL_DEPTH_DELTA": 1,
        "MAX_WALL_DEPTH": 5,
        "X": 0,
        "Y": 0,
        "HEIGHT": 1,
        "BAR_WIDTH": 1
    }
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