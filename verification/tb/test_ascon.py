import cocotb
from pyuvm import uvm_root

from .tests import (
    AsconFullRefEncTest,
    AsconRandomSampleEncTest,
    AsconSingleEncTest,
    AsconSingleRefEncTest,
)


@cocotb.test(timeout_time=10000, timeout_unit="ns")
async def test_random_enc(dut):
    await uvm_root().run_test(AsconRandomSampleEncTest)


@cocotb.test(timeout_time=1000, timeout_unit="ns")
async def test_single_enc(dut):
    await uvm_root().run_test(AsconSingleEncTest)


@cocotb.test(timeout_time=1_000_000, timeout_unit="ns")
async def test_full_ref_enc(dut):
    await uvm_root().run_test(AsconFullRefEncTest)


@cocotb.test(timeout_time=1000, timeout_unit="ns")
async def test_single_ref_enc(dut):
    await uvm_root().run_test(AsconSingleRefEncTest)
