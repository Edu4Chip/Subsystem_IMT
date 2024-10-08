import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ClockCycles, with_timeout, Combine
from cocotb.types import LogicArray, Range

PERIOD = 100

async def reset_dut(dut):
    """Reset sequence for the DUT."""
    dut.rst_n_i.value = 0
    await Timer(25, units='ns')
    dut.rst_n_i.value = 1


async def generate_round_sequence(dut, sel_p12):
    dut.en_i.value = 0
    dut.load_i.value = 0
    dut.sel_p12_init_i.value = 1 if sel_p12 else 0
    n_round = 12 if sel_p12 else 6

    await ClockCycles(dut.clk_i, 2)
    dut.en_i.value = 1
    dut.load_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.load_i.value = 0
    await ClockCycles(dut.clk_i, n_round-1)
    assert dut.n_last_rnd_o.value == 1, 'test failure: before last round not detected!'
    await ClockCycles(dut.clk_i, 1)


@cocotb.test()
async def test_round_counter_p6(dut):
    # run the clock
    clk = Clock(dut.clk_i, PERIOD, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    await generate_round_sequence(dut, sel_p12=False)


@cocotb.test()
async def test_round_counter_p12(dut):
    # run the clock
    clk = Clock(dut.clk_i, PERIOD, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    await generate_round_sequence(dut, sel_p12=True)
