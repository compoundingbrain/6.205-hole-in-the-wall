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
    dut.num_players.value = 0

    # Go through all values from 0 to 1280 and 0 to 720 and randomly assign it value_in 1 or 0
    # keep internal track of the center of mass for comparison

    for num_tests in range(0, 3):
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
        dut.valid_in.value = 0
        await ClockCycles(dut.clk_in,1)
        dut.tabulate_in.value = 0
        await with_timeout(RisingEdge(dut.valid_out), 100000, "ns")
        await ClockCycles(dut.clk_in,1)
        
        expected_x = x_sum // total
        expected_y = y_sum // total

        assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value} on trial {num_tests}"
        assert dut.x_out[0].value == expected_x, f"Expected x_out[0] to be {expected_x}, got {dut.x_out[0].value.integer} on trial {num_tests}"
        assert dut.y_out[0].value == expected_y, f"Expected y_out[0] to be {expected_y}, got {dut.y_out[0].value.integer} on trial {num_tests}"

        await ClockCycles(dut.clk_in,1)
        assert dut.valid_out.value == 0

def manhattan_distance(x1, y1, x2, y2):
    return abs(x1 - x2) + abs(y1 - y2)

@cocotb.test()
async def test_two_players(dut):
    """cocotb test for moving frame k means with two player. Tracking two centroids."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    dut.num_players.value = 1 # two players

    # initialize two centroids
    # assumes both are initialized to 0 and that all centroids will go to player 1 on the first iteration

    centroid_1_x = 0
    centroid_1_y = 0
    centroid_2_x = 0
    centroid_2_y = 0

    for num_tests in range(0,5):
        sum_x_1 = 0
        sum_y_1 = 0
        sum_x_2 = 0
        sum_y_2 = 0
        total_1 = 0
        total_2 = 0

        for j in range(0, ACTIVE_LINES, 4):
            for i in range(0, ACTIVE_H_PIXELS, 4):
                dut.x_in.value = i
                dut.y_in.value = j
                valid_in = random.randint(0,1)
                dut.valid_in.value = valid_in
                if manhattan_distance(centroid_1_x, centroid_1_y, i, j) <= manhattan_distance(centroid_2_x, centroid_2_y, i, j):
                    sum_x_1 += valid_in * i
                    sum_y_1 += valid_in * j
                    total_1 += valid_in
                else:
                    sum_x_2 += valid_in * i
                    sum_y_2 += valid_in * j
                    total_2 += valid_in
                await ClockCycles(dut.clk_in,1)

        dut.tabulate_in.value = 1
        dut.valid_in.value = 0
        await ClockCycles(dut.clk_in,1)
        dut.tabulate_in.value = 0
        await with_timeout(RisingEdge(dut.valid_out), 100000, "ns")
        await ClockCycles(dut.clk_in,1)

        centroid_1_x = 0 if total_1 == 0 else sum_x_1 // total_1
        centroid_1_y = 0 if total_1 == 0 else sum_y_1 // total_1
        centroid_2_x = 0 if total_2 == 0 else sum_x_2 // total_2
        centroid_2_y = 0 if total_2 == 0 else sum_y_2 // total_2

        # print("Expected Centroid 1:", centroid_1_x, centroid_1_y)
        # print("Expected Centroid 2:", centroid_2_x, centroid_2_y)

        assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value} on trial {num_tests}"
        assert dut.x_out[0].value == centroid_1_x, f"Expected x_out[0] to be {centroid_1_x}, got {dut.x_out[0].value.integer} on trial {num_tests}"
        assert dut.y_out[0].value == centroid_1_y, f"Expected y_out[0] to be {centroid_1_y}, got {dut.y_out[0].value.integer} on trial {num_tests}"

        assert dut.x_out[1].value == centroid_2_x, f"Expected x_out[1] to be {centroid_2_x}, got {dut.x_out[1].value.integer} on trial {num_tests}"
        assert dut.y_out[1].value == centroid_2_y, f"Expected y_out[1] to be {centroid_2_y}, got {dut.y_out[1].value.integer} on trial {num_tests}"

        await ClockCycles(dut.clk_in,1)
        assert dut.valid_out.value == 0
        await ClockCycles(dut.clk_in,4)

@cocotb.test()
async def test_three_players(dut):
    """cocotb test for moving frame k means with three players. Tracking three centroids."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    dut.num_players.value = 2 # three players

    # initialize three centroids
    # assumes both are initialized to 0 and that all centroids will go to player 1 on the first iteration

    centroid_1_x = 0
    centroid_1_y = 0
    centroid_2_x = 0
    centroid_2_y = 0
    centroid_3_x = 0
    centroid_3_y = 0

    for num_tests in range(0,5):
        sum_x_1 = 0
        sum_y_1 = 0
        sum_x_2 = 0
        sum_y_2 = 0
        sum_x_3 = 0
        sum_y_3 = 0
        total_1 = 0
        total_2 = 0
        total_3 = 0

        for j in range(0, ACTIVE_LINES, 4):
            for i in range(0, ACTIVE_H_PIXELS, 4):
                dut.x_in.value = i
                dut.y_in.value = j
                valid_in = random.randint(0,1)
                dut.valid_in.value = valid_in
                distance_1 = manhattan_distance(centroid_1_x, centroid_1_y, i, j)
                distance_2 = manhattan_distance(centroid_2_x, centroid_2_y, i, j)
                distance_3 = manhattan_distance(centroid_3_x, centroid_3_y, i, j)
                if distance_1 <= distance_2 and distance_1 <= distance_3:
                    sum_x_1 += valid_in * i
                    sum_y_1 += valid_in * j
                    total_1 += valid_in
                elif distance_2 <= distance_1 and distance_2 <= distance_3:
                    sum_x_2 += valid_in * i
                    sum_y_2 += valid_in * j
                    total_2 += valid_in
                else:
                    sum_x_3 += valid_in * i
                    sum_y_3 += valid_in * j
                    total_3 += valid_in
                await ClockCycles(dut.clk_in,1)

        dut.tabulate_in.value = 1
        dut.valid_in.value = 0
        await ClockCycles(dut.clk_in,1)
        dut.tabulate_in.value = 0
        await with_timeout(RisingEdge(dut.valid_out), 100000, "ns")
        await ClockCycles(dut.clk_in,1)

        centroid_1_x = 0 if total_1 == 0 else sum_x_1 // total_1
        centroid_1_y = 0 if total_1 == 0 else sum_y_1 // total_1
        centroid_2_x = 0 if total_2 == 0 else sum_x_2 // total_2
        centroid_2_y = 0 if total_2 == 0 else sum_y_2 // total_2
        centroid_3_x = 0 if total_3 == 0 else sum_x_3 // total_3
        centroid_3_y = 0 if total_3 == 0 else sum_y_3 // total_3

        # print("Expected Centroid 1:", centroid_1_x, centroid_1_y)
        # print("Expected Centroid 2:", centroid_2_x, centroid_2_y)

        assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value} on trial {num_tests}"
        assert dut.x_out[0].value == centroid_1_x, f"Expected x_out[0] to be {centroid_1_x}, got {dut.x_out[0].value.integer} on trial {num_tests}"
        assert dut.y_out[0].value == centroid_1_y, f"Expected y_out[0] to be {centroid_1_y}, got {dut.y_out[0].value.integer} on trial {num_tests}"

        assert dut.x_out[1].value == centroid_2_x, f"Expected x_out[1] to be {centroid_2_x}, got {dut.x_out[1].value.integer} on trial {num_tests}"
        assert dut.y_out[1].value == centroid_2_y, f"Expected y_out[1] to be {centroid_2_y}, got {dut.y_out[1].value.integer} on trial {num_tests}"

        assert dut.x_out[2].value == centroid_3_x, f"Expected x_out[2] to be {centroid_3_x}, got {dut.x_out[2].value.integer} on trial {num_tests}"
        assert dut.y_out[2].value == centroid_3_y, f"Expected y_out[2] to be {centroid_3_y}, got {dut.y_out[2].value.integer} on trial {num_tests}"

        await ClockCycles(dut.clk_in,1)
        assert dut.valid_out.value == 0
        await ClockCycles(dut.clk_in,4)

@cocotb.test()
async def test_four_players(dut):
    """cocotb test for moving frame k means with four players. Tracking four centroids."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    dut.num_players.value = 3 # four players

    # Initialize four players
    # assumes both are initialized to 0 and that all centroids will go to player 1 on the first iteration

    centroid_1_x = 0
    centroid_1_y = 0
    centroid_2_x = 0
    centroid_2_y = 0
    centroid_3_x = 0
    centroid_3_y = 0
    centroid_4_x = 0
    centroid_4_y = 0

    for num_tests in range(0,5):
        sum_x_1 = 0
        sum_y_1 = 0
        sum_x_2 = 0
        sum_y_2 = 0
        sum_x_3 = 0
        sum_y_3 = 0
        sum_x_4 = 0
        sum_y_4 = 0
        total_1 = 0
        total_2 = 0
        total_3 = 0
        total_4 = 0

        for j in range(0, ACTIVE_LINES, 4):
            for i in range(0, ACTIVE_H_PIXELS, 4):
                dut.x_in.value = i
                dut.y_in.value = j
                valid_in = random.randint(0,1)
                dut.valid_in.value = valid_in
                distance_1 = manhattan_distance(centroid_1_x, centroid_1_y, i, j)
                distance_2 = manhattan_distance(centroid_2_x, centroid_2_y, i, j)
                distance_3 = manhattan_distance(centroid_3_x, centroid_3_y, i, j)
                distance_4 = manhattan_distance(centroid_4_x, centroid_4_y, i, j)
                if distance_1 <= distance_2 and distance_1 <= distance_3 and distance_1 <= distance_4: 
                    sum_x_1 += valid_in * i
                    sum_y_1 += valid_in * j
                    total_1 += valid_in
                elif distance_2 <= distance_1 and distance_2 <= distance_3 and distance_2 <= distance_4:
                    sum_x_2 += valid_in * i
                    sum_y_2 += valid_in * j
                    total_2 += valid_in
                elif distance_3 <= distance_1 and distance_3 <= distance_2 and distance_3 <= distance_4:
                    sum_x_3 += valid_in * i
                    sum_y_3 += valid_in * j
                    total_3 += valid_in
                else:
                    sum_x_4 += valid_in * i
                    sum_y_4 += valid_in * j
                    total_4 += valid_in
                await ClockCycles(dut.clk_in,1)

        dut.tabulate_in.value = 1
        dut.valid_in.value = 0
        await ClockCycles(dut.clk_in,1)
        dut.tabulate_in.value = 0
        await with_timeout(RisingEdge(dut.valid_out), 100000, "ns")
        await ClockCycles(dut.clk_in,1)

        centroid_1_x = 0 if total_1 == 0 else sum_x_1 // total_1
        centroid_1_y = 0 if total_1 == 0 else sum_y_1 // total_1
        centroid_2_x = 0 if total_2 == 0 else sum_x_2 // total_2
        centroid_2_y = 0 if total_2 == 0 else sum_y_2 // total_2
        centroid_3_x = 0 if total_3 == 0 else sum_x_3 // total_3
        centroid_3_y = 0 if total_3 == 0 else sum_y_3 // total_3
        centroid_4_x = 0 if total_4 == 0 else sum_x_4 // total_4
        centroid_4_y = 0 if total_4 == 0 else sum_y_4 // total_4

        # print("Expected Centroid 1:", centroid_1_x, centroid_1_y)
        # print("Expected Centroid 2:", centroid_2_x, centroid_2_y)

        assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value} on trial {num_tests}"
        assert dut.x_out[0].value == centroid_1_x, f"Expected x_out[0] to be {centroid_1_x}, got {dut.x_out[0].value.integer} on trial {num_tests}"
        assert dut.y_out[0].value == centroid_1_y, f"Expected y_out[0] to be {centroid_1_y}, got {dut.y_out[0].value.integer} on trial {num_tests}"

        assert dut.x_out[1].value == centroid_2_x, f"Expected x_out[1] to be {centroid_2_x}, got {dut.x_out[1].value.integer} on trial {num_tests}"
        assert dut.y_out[1].value == centroid_2_y, f"Expected y_out[1] to be {centroid_2_y}, got {dut.y_out[1].value.integer} on trial {num_tests}"

        assert dut.x_out[2].value == centroid_3_x, f"Expected x_out[2] to be {centroid_3_x}, got {dut.x_out[2].value.integer} on trial {num_tests}"
        assert dut.y_out[2].value == centroid_3_y, f"Expected y_out[2] to be {centroid_3_y}, got {dut.y_out[2].value.integer} on trial {num_tests}"

        assert dut.x_out[3].value == centroid_4_x, f"Expected x_out[3] to be {centroid_4_x}, got {dut.x_out[3].value.integer} on trial {num_tests}"
        assert dut.y_out[3].value == centroid_4_y, f"Expected y_out[3] to be {centroid_4_y}, got {dut.y_out[3].value.integer} on trial {num_tests}"

        await ClockCycles(dut.clk_in,1)
        assert dut.valid_out.value == 0
        await ClockCycles(dut.clk_in,4)

@cocotb.test()
async def test_changing_players(dut):
    """cocotb test for moving frame k means with changing player counts. Tracking variable number of centroids."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_in,1)
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_in,5)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)
    num_players = 3 # four players
    dut.num_players.value = num_players # four players

    # Initialize four players
    # assumes both are initialized to 0 and that all centroids will go to player 1 on the first iteration

    centroid_1_x = 0
    centroid_1_y = 0
    centroid_2_x = 0
    centroid_2_y = 0
    centroid_3_x = 0
    centroid_3_y = 0
    centroid_4_x = 0
    centroid_4_y = 0

    for num_tests in range(0,20):
        sum_x_1 = 0
        sum_y_1 = 0
        sum_x_2 = 0
        sum_y_2 = 0
        sum_x_3 = 0
        sum_y_3 = 0
        sum_x_4 = 0
        sum_y_4 = 0
        total_1 = 0
        total_2 = 0
        total_3 = 0
        total_4 = 0
        num_players = random.randint(0,3)
        dut.num_players.value = num_players

        for j in range(0, ACTIVE_LINES, 4):
            for i in range(0, ACTIVE_H_PIXELS, 4):
                dut.x_in.value = i
                dut.y_in.value = j
                valid_in = random.randint(0,1)
                dut.valid_in.value = valid_in
                distance_1 = manhattan_distance(centroid_1_x, centroid_1_y, i, j)
                distance_2 = manhattan_distance(centroid_2_x, centroid_2_y, i, j)
                distance_3 = manhattan_distance(centroid_3_x, centroid_3_y, i, j)
                distance_4 = manhattan_distance(centroid_4_x, centroid_4_y, i, j)
                if num_players == 0 or (distance_1 <= distance_2 and (num_players <= 1 or (distance_1 <= distance_3 and (num_players <= 2 or (distance_1 <= distance_4))))): 
                    sum_x_1 += valid_in * i
                    sum_y_1 += valid_in * j
                    total_1 += valid_in
                elif distance_2 <= distance_1 and (num_players <= 1 or (distance_2 <= distance_3 and (num_players <= 2 or (distance_2 <= distance_4)))):
                    sum_x_2 += valid_in * i
                    sum_y_2 += valid_in * j
                    total_2 += valid_in
                elif distance_3 <= distance_1 and distance_3 <= distance_2 and (num_players <= 2 or (distance_3 <= distance_4)):
                    sum_x_3 += valid_in * i
                    sum_y_3 += valid_in * j
                    total_3 += valid_in
                else:
                    sum_x_4 += valid_in * i
                    sum_y_4 += valid_in * j
                    total_4 += valid_in
                await ClockCycles(dut.clk_in,1)

        dut.tabulate_in.value = 1
        dut.valid_in.value = 0
        await ClockCycles(dut.clk_in,1)
        dut.tabulate_in.value = 0
        await with_timeout(RisingEdge(dut.valid_out), 100000, "ns")
        await ClockCycles(dut.clk_in,1)

        centroid_1_x = 0 if total_1 == 0 else sum_x_1 // total_1
        centroid_1_y = 0 if total_1 == 0 else sum_y_1 // total_1
        centroid_2_x = 0 if total_2 == 0 else sum_x_2 // total_2
        centroid_2_y = 0 if total_2 == 0 else sum_y_2 // total_2
        centroid_3_x = 0 if total_3 == 0 else sum_x_3 // total_3
        centroid_3_y = 0 if total_3 == 0 else sum_y_3 // total_3
        centroid_4_x = 0 if total_4 == 0 else sum_x_4 // total_4
        centroid_4_y = 0 if total_4 == 0 else sum_y_4 // total_4

        # print("Expected Centroid 1:", centroid_1_x, centroid_1_y)
        # print("Expected Centroid 2:", centroid_2_x, centroid_2_y)

        assert dut.valid_out.value == 1, f"Expected valid_out to be 1, got {dut.valid_out.value} on trial {num_tests}"
        assert dut.x_out[0].value == centroid_1_x, f"Expected x_out[0] to be {centroid_1_x}, got {dut.x_out[0].value.integer} on trial {num_tests}"
        assert dut.y_out[0].value == centroid_1_y, f"Expected y_out[0] to be {centroid_1_y}, got {dut.y_out[0].value.integer} on trial {num_tests}"

        assert dut.x_out[1].value == centroid_2_x, f"Expected x_out[1] to be {centroid_2_x}, got {dut.x_out[1].value.integer} on trial {num_tests}"
        assert dut.y_out[1].value == centroid_2_y, f"Expected y_out[1] to be {centroid_2_y}, got {dut.y_out[1].value.integer} on trial {num_tests}"

        assert dut.x_out[2].value == centroid_3_x, f"Expected x_out[2] to be {centroid_3_x}, got {dut.x_out[2].value.integer} on trial {num_tests}"
        assert dut.y_out[2].value == centroid_3_y, f"Expected y_out[2] to be {centroid_3_y}, got {dut.y_out[2].value.integer} on trial {num_tests}"

        assert dut.x_out[3].value == centroid_4_x, f"Expected x_out[3] to be {centroid_4_x}, got {dut.x_out[3].value.integer} on trial {num_tests}"
        assert dut.y_out[3].value == centroid_4_y, f"Expected y_out[3] to be {centroid_4_y}, got {dut.y_out[3].value.integer} on trial {num_tests}"

        await ClockCycles(dut.clk_in,1)
        assert dut.valid_out.value == 0
        await ClockCycles(dut.clk_in,4)




    
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

