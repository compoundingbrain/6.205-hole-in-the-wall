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
    dut.tx_trigger_in.value = 0
    dut.tx_data_in.value = 0 #set in 16 bit input value
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

    dut.tx_data_in.value = 0b101_0101_0101
    dut.tx_trigger_in.value = 1
    await ClockCycles(dut.clk_in, 1,rising=False)
    dut.tx_data_in.value = 0b000_0000_0000 # once trigger in is off, don't expect data_in to stay the same!!
    dut.tx_trigger_in.value = 0
    await ClockCycles(dut.clk_in, 12000)
    

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
        proj_path/"hdl"/"uart_transmit.sv", 
        proj_path/"hdl"/"uart_receive.sv",
        proj_path/"hdl"/"counter.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
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
