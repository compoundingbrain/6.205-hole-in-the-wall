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
async def test_one_player(dut):
    """cocotb test for moving frame k means with one player. Should just be center of mass."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    # Go through all values from 0 to 1280 and 0 to 720 and randomly assign it value_in 1 or 0
    # keep internal track of the center of mass for comparison

    x_sum = 0
    y_sum = 0
    total = 0

    for j in range(0, ACTIVE_LINES, 4):
        for i in range(0, ACTIVE_H_PIXELS, 4):
            dut.x_in.value = i
            dut.y_in.value = j
            valid_in = random.randint(0,1)
            total += valid_in
            dut.valid_in.value = valid_in
            x_sum += valid_in * i
            y_sum += valid_in * j
            await ClockCycles(dut.clk_in,1)

    dut.tabulate_in.value = 1
    await RisingEdge(dut.valid_out)
    dut.tabulate_in.value = 0
    
    expected_x = x_sum // total
    expected_y = y_sum // total

    assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value}"
    assert dut.x_out[0].value == expected_x, f"Expected x_out[0] to be {expected_x}, got {dut.x_out.value}"
    assert dut.y_out[0].value == expected_y, f"Expected y_out[0] to be {expected_y}, got {dut.y_out.value}"

    
def is_runner():
    """K Means Moving Frame Testing."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "moving_frame_k_means.sv"]
    sources += [proj_path / "hdl" / "center_of_mass.sv"]
    sources += [proj_path / "hdl" / "divider.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="moving_frame_k_means",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="moving_frame_k_means",
        test_module="test_moving_frame_k_means",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()

