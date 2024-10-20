"""Testbench of module ascon_top.

The testbench uses the ascon_top module to perform encryptions on known anwsert test (KAT) vectors.
It can be parametrized with one of the two sets of environment variables.

Option 1:
- SAMPLE_COUNT: test the KAT vector identified by the provided 'SAMPLE_COUNT'

Option 2:
- SAMPLE_SIZE: test a random sample of size 'SAMPLE_SIZE'
- AD_SIZE: get samples from the KAT database that match the provided 'AD_SIZE'
- PT_SIZE: get samples from the KAT database that match the provided 'PT_SIZE'
"""
import ascon_kat_vectors
import cocotb
import cocotb.triggers
import cocotb.utils
import os

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
from cocotb.types import LogicArray, Range
from typing import Iterable, Optional



PERIOD = 100
TIMEOUT = (12, 'us')


class Blocks:
    def __init__(self, data: bytes, block_size: int = 4):
        self._data = data
        self._block_size = block_size
    def __str__(self):
        return ' '.join(blk.hex() for _, blk in iter(self))
    def __iter__(self) -> Iterable[bytes]:
        return enumerate(
            self._data[i:i+self._block_size]
            for i in range(0, len(self._data), self._block_size)
        )


TRANS_FMT = '[{op:<8s}] {key:>22s} = {value}'


def _log(key: str, value: bytes, op: str):
    cocotb.log.info(TRANS_FMT.format(key=key, value=str(Blocks(value)), op=op))


def log_rx(key: str, value: bytes):
    _log(key, value, '<= read')


def log_tx(key: str, value: bytes):
    _log(key, value, '=> write')


def log_params(vec: ascon_kat_vectors.Vector):
    """Log the encryption parameters."""
    params = [
        ('key', vec.key),
        ('nonce', vec.nonce),
        (f'ad ({vec.ad_size} B)', vec.ad),
        (f'pt ({vec.pt_size} B)', vec.pt),
        ('ct', vec.ct),
        ('tag', vec.tag),
    ]
    for i, j in params:
        cocotb.log.info(f'{i:<13s} = {Blocks(j)!s}')


async def reset_dut(dut):
    """Reset sequence for the DUT."""
    dut.rst_n_i.value = 0
    await Timer(25, units='ns')
    dut.rst_n_i.value = 1


def setup_enc(dut, vec: ascon_kat_vectors.Vector):
    """Setup the parameters of the encryption."""
    data = LogicArray(int.from_bytes(vec.key, byteorder='big', signed=False), Range(127, 'downto', 0))
    dut.key_i.value = data
    log_tx('key[127:0]', vec.key)
    data = LogicArray(int.from_bytes(vec.nonce, byteorder='big', signed=False), Range(127, 'downto', 0))
    dut.nonce_i.value = data
    log_tx('nonce[127:0]', vec.nonce)
    dut.data_valid_i.value = 0
    dut.data_i.value = 0
    # set the sizes of the padded inputs
    ad_size = len(vec.ad) // 8
    pt_size = len(vec.pt) // 8
    dut.delay_i.value = 0
    dut.ad_size_i.value = ad_size
    dut.pt_size_i.value = pt_size


async def _wait_signal(dut, signal, level=1):
    """Wait for a signal to be asserted."""
    while signal.value != level:
        await ClockCycles(dut.clk_i, 1)


async def wait_signal(dut, signal, level=1):
    """Wait for a signal to be asserted before a fixed timeout."""
    await cocotb.triggers.with_timeout(_wait_signal(dut, signal, level=level), *TIMEOUT)


async def gen_start_pulse(dut):
    """Generate a single-cycle pulse which start the computation."""
    dut.start_i.value = 0
    await ClockCycles(dut.clk_i, 1)
    dut.start_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.start_i.value = 0


async def write_data(dut, data: bytes):
    """Write a data block."""
    data = LogicArray(int.from_bytes(data, byteorder='big', signed=False), Range(63, 'downto', 0))
    dut.data_i.value = data
    dut.data_valid_i.value = 1
    await ClockCycles(dut.clk_i, 1)
    dut.data_i.value = 0
    dut.data_valid_i.value = 0
    await ClockCycles(dut.clk_i, 1)


def to_bytes(signal, block_size: int) -> bytes:
    """Convert a signal integer value to its big-endian representation in bytes."""
    data = int.to_bytes(signal.value.integer, length=block_size, byteorder='big')
    return data


async def read_tag(dut) -> bytes:
    """Collect the tag computed by the DUT."""
    await wait_signal(dut, dut.tag_valid_o)
    tag = to_bytes(dut.tag_o, block_size=16)
    log_rx('tag[127:0]', tag)
    return tag


async def send_ad(dut, vec: ascon_kat_vectors.Vector, latency: int = 0):
    """Send multiple data blocks of associated data."""
    for i, ad in Blocks(vec.ad, block_size=8):
        # wait for a data request
        await wait_signal(dut, dut.data_req_o)
        await ClockCycles(dut.clk_i, 1)
        # emulate the latency of the completer
        for _ in range(latency):
            await ClockCycles(dut.clk_i, 1)
        # write a data block
        await write_data(dut, ad)
        log_tx(f'ad[{i}][63:0]', ad)


async def enc_pt(dut, vec: ascon_kat_vectors.Vector, latency: int = 0) -> bytes:
    """Send multiple data blocks of plaintext and collect the ciphertext data blocks."""
    recv = b''
    for i, pt in Blocks(vec.pt, block_size=8):
        # wait for a data request
        await wait_signal(dut, dut.data_req_o)
        await ClockCycles(dut.clk_i, 1)
        # emulate the latency of the completer
        for _ in range(latency):
            await ClockCycles(dut.clk_i, 1)
        # write a plaintext data block
        await write_data(dut, pt)
        log_tx(f'pt[{i}][63:0]', pt)
        assert dut.ct_valid_o.value == 1
        # read a ciphertext data block
        ct = to_bytes(dut.ct_o, block_size=8)
        log_rx(f'ct[{i}][63:0]', ct)
        recv += ct
    recv = recv[:vec.pt_size]
    return recv


async def test_ascon_vector(dut, vec: ascon_kat_vectors.Vector, latency: int = 0):
    """Simulate a transaction with the DUT given a test vector."""
    cocotb.log.info(f'running test Count = {vec.count}...')
    # log the computation parameters
    log_params(vec)
    # setup the parameters of the computation
    setup_enc(dut, vec)
    # wait for the device to be ready
    await wait_signal(dut, dut.ready_o)
    cocotb.log.info('DUT is ready...')
    await ClockCycles(dut.clk_i, 1)
    # start the computation
    cocotb.log.info('start encryption...')
    start_time = cocotb.utils.get_sim_time('ns')
    await gen_start_pulse(dut)
    # send associated data
    cocotb.log.info('send AD...')
    await send_ad(dut, vec, latency=latency)
    # send the plaintext and receive the ciphertext
    cocotb.log.info('send the PT...')
    ct = await enc_pt(dut, vec, latency=latency)
    # receive the tag
    cocotb.log.info('receive the tag...')
    tag = await read_tag(dut)
    # wait for the completion of the computation
    cocotb.log.info('wait for completion...')
    await wait_signal(dut, dut.done_o)
    cocotb.log.info('encryption done.')
    # check the ciphertext and the tag against the KAT vector
    log_rx('ct (sim)', ct)
    log_rx('ct (ref)', vec.ct)
    assert ct == vec.ct, f'ciphertext comparison failed!'
    log_rx('tag (sim)', tag)
    log_rx('tag (ref)', vec.tag)
    assert tag == vec.tag, f'tag comparison failed!'
    # this line is not reached if the test fails
    test_duration = cocotb.utils.get_sim_time('ns') - start_time
    cocotb.log.info('test completed successfully!')
    cocotb.log.info(f'runtime = {test_duration} ns')


def get_int_param(key) -> Optional[int]:
    k = os.environ.get(key, '')
    return int(k) if str.isdecimal(k) else None


@cocotb.test()
async def test_ascon(dut):
    # run the clock
    clk = Clock(dut.clk_i, PERIOD, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    # retrieve KAT vectors from the Ascon reference implementation and test them
    sample_count = get_int_param('SAMPLE_COUNT')
    if sample_count is not None:
        vec = ascon_kat_vectors.get(sample_count)
        await test_ascon_vector(dut, vec)
    else:
        params = {
            'k': get_int_param('SAMPLE_SIZE'),
            'ad_size': get_int_param('AD_SIZE'),
            'pt_size': get_int_param('PT_SIZE'),
        }
        for vec in ascon_kat_vectors.select(**params):
            await test_ascon_vector(dut, vec)