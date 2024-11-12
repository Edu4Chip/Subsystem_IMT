import ascon_kat_vectors
import cocotb
import cocotb.triggers
import cocotb.utils
import collections
import dataclasses
import enum
import os

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
from cocotb.types import LogicArray, Range
from typing import Iterable, Optional


PERIOD = (100, 'ns')
TIMEOUT = (25, 'us')
PROG_DELAY = 10


class Reg(enum.IntEnum):
    CTRL = 0x00
    STATUS = 0x04
    KEY = 0x08
    NONCE = 0x18
    TAG = 0x28
    AD = 0x38
    PT = 0x40
    CT = 0x48


class Status(enum.Flag):
    CT_FULL = 1 << 7
    CT_EMPTY = 1 << 6
    PT_FULL = 1 << 5
    PT_EMPTY = 1 << 4
    AD_FULL = 1 << 3
    AD_EMPTY = 1 << 2
    TAG_VALID = 1 << 1
    READY = 1 << 0


class CtrlFlags(enum.Flag):
    START = 1


@dataclasses.dataclass
class CtrlCfg:
    flags : CtrlFlags = CtrlFlags(0) 
    delay : int = 0
    ad_size : int = 0
    pt_size : int = 0


def blocks(data: bytes, bs: int = 8):
    return (data[i:i+bs] for i in range(0, len(data), bs))


def blkstr(data: bytes, bs: int = 8):
    return ' '.join(blk.hex() for blk in blocks(data, bs=bs))


TRANS_FMT = '[{op:<8s}] {key:>22s} = {value}'


def _log(key: str, value: bytes, op: str):
    cocotb.log.info(TRANS_FMT.format(key=key, value=blkstr(value), op=op))


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
        cocotb.log.info(f'{i:<13s} = {blkstr(j)!s}')


async def reset_dut(dut):
    """Reset sequence for the DUT."""
    dut.reset_int.value = 0
    await Timer(25, units='ns')
    dut.reset_int.value = 1


async def apb_read_int(dut, addr : int) -> int:
    """Read a register."""
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    dut.PWRITE.value = 0
    dut.PADDR.value = addr
    await ClockCycles(dut.clk_in, 1)
    dut.PENABLE.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.PSEL.value = 0
    return dut.PRDATA.value.integer


async def apb_read(dut, addr : int) -> bytes:
    """Read a register."""
    value = await apb_read_int(dut, addr)
    data = int.to_bytes(value, length=dut.APB_DW.value // 8, byteorder='big')
    log_rx(f'@ {addr:02x}', data)
    return data


async def apb_read_blocks(dut, addr: int, data_size: int):
    bs = dut.APB_DW.value // 8
    recv = b''
    while data_size > 0:
        blk = await apb_read(dut, addr)
        recv += blk
        addr += bs
        data_size -= bs
    return recv


async def apb_read_status(dut) -> Status:
    """Read the status register."""
    status = await apb_read_int(dut, Reg.STATUS)
    status = Status(status)
    cocotb.log.info(f'check dut: status = {status}...')
    return status


async def apb_write_int(dut, addr : int, value : int):
    """Write a register."""
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    dut.PWRITE.value = 1
    dut.PADDR.value = addr
    dut.PWDATA.value = value # LogicArray(value, Range(dut.APB_DW.value - 1, 'downto', 0))
    await ClockCycles(dut.clk_in, 1)
    dut.PENABLE.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.PSEL.value = 0
    dut.PWDATA.value = 0


async def apb_write(dut, addr : int, data : bytes):
    value = int.from_bytes(data, byteorder='big', signed=False)
    await apb_write_int(dut, addr, value)
    log_tx(f'@ {addr:02x}', data)


async def apb_write_blocks(dut, addr: int, data: bytes):
    bs = dut.APB_DW.value // 8
    for blk in blocks(data, bs=bs):
        await apb_write(dut, addr, blk)
        addr += bs


async def apb_write_ctrl(dut, cfg: CtrlCfg):
    """Write the control register."""
    value = cfg.flags.value
    value |= cfg.ad_size << dut.u_apb_registers.ADSizeOffset.value
    value |= cfg.pt_size << dut.u_apb_registers.PTSizeOffset.value
    value |= cfg.delay << dut.u_apb_registers.DelayOffset.value
    await apb_write_int(dut, Reg.CTRL, value)


async def wait_ready(dut):
    """Wait for the ready flag in the status register."""
    status = await apb_read_status(dut)
    while Status.READY not in status:
        status = await apb_read_status(dut)


async def test_ascon_vector(dut, vec: ascon_kat_vectors.Vector, delay: int = 0, preload: bool = False):
    """Simulate a transaction with the DUT given a test vector."""
    cocotb.log.info(f'running test Count = {vec.count}...')
    start_time = cocotb.utils.get_sim_time('ns')

    # log the encryption parameters
    log_params(vec)

    # initializes data queues
    bs = 8
    ad_buffer = collections.deque(blocks(vec.ad, bs=bs))
    pt_buffer = collections.deque(blocks(vec.pt, bs=bs))
    ct_buffer = collections.deque()

    for i, blk in enumerate(ad_buffer):
        cocotb.log.info(f'- ad_buffer[{i:d}] = {blk.hex()}')
    for i, blk in enumerate(pt_buffer):
        cocotb.log.info(f'- pt_buffer[{i:d}] = {blk.hex()}')

    # wait for the device to be ready
    await wait_ready(dut)
    cocotb.log.info('DUT is ready...')
    await ClockCycles(dut.clk_in, 1)

    # setup the parameters of the computation
    cocotb.log.info('configure encryption...')
    cocotb.log.info('...write KEY registers')
    await apb_write_blocks(dut, Reg.KEY, vec.key)
    cocotb.log.info('...write NONCE registers')
    await apb_write_blocks(dut, Reg.NONCE, vec.nonce)
    cocotb.log.info('...write CTRL register and start encryption')
    cfg = CtrlCfg(
        flags=CtrlFlags.START,
        delay=delay,
        ad_size=len(vec.ad) // 8,
        pt_size=len(vec.pt) // 8,
    )
    await apb_write_ctrl(dut, cfg)
    if preload:
        cocotb.log.info('...write AD')
        for _ in range(dut.FifoDepth.value):
            if not ad_buffer:
                break
            data = ad_buffer.popleft()
            await apb_write_blocks(dut, Reg.AD, data)
        cocotb.log.info('...write PT')
        for _ in range(dut.FifoDepth.value):
            if not pt_buffer:
                break
            data = pt_buffer.popleft()
            await apb_write_blocks(dut, Reg.PT, data)
    else:
        cocotb.log.info('...skip preload')

    # send and receive data blocks
    while True:
        status = await apb_read_status(dut)
        if Status.TAG_VALID in status:
            break
        elif ad_buffer and (Status.AD_FULL not in status):
            data = ad_buffer.popleft()
            await apb_write_blocks(dut, Reg.AD, data)
        elif pt_buffer and (Status.PT_FULL not in status):
            data = pt_buffer.popleft()
            await apb_write_blocks(dut, Reg.PT, data)
        elif Status.CT_EMPTY not in status:
            blk = await apb_read_blocks(dut, Reg.CT, bs)
            ct_buffer.append(blk)
    cocotb.log.info('encryption done.')
    # read the last blocks
    while Status.CT_EMPTY not in status:
        blk = await apb_read_blocks(dut, Reg.CT, bs)
        ct_buffer.append(blk)
        status = await apb_read_status(dut)
    ct = b''.join(ct_buffer)
    ct = ct[:vec.pt_size]
    # read the tag
    cocotb.log.info('retrieve the tag...')
    tag = await apb_read_blocks(dut, Reg.TAG, 16)
    cocotb.log.info('terminate the encryption...')
    await apb_write_int(dut, Reg.CTRL, 0)
    await wait_ready(dut)

    # check the ciphertext and the tag against the KAT vector
    cocotb.log.info('check the results against the KAT vector...')
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


def get_int_param(key, default=None) -> Optional[int]:
    if key in os.environ:
        return int(os.environ[key])
    else:
        return default


@cocotb.test()
async def test_ascon(dut):
    # run the clock
    clk = Clock(dut.clk_in, *PERIOD)
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    # retrieve KAT vectors from the Ascon reference implementation and test them
    sample_count = get_int_param('SAMPLE_COUNT')
    test_params = {
        'delay': get_int_param('PROG_DELAY', 0),
        'preload': get_int_param('PRELOAD_DATA', 0),
    }
    if sample_count is not None:
        vec = ascon_kat_vectors.get(sample_count)
        await cocotb.triggers.with_timeout(test_ascon_vector(dut, vec, **test_params), *TIMEOUT)
    else:
        kwargs = {
            'k': get_int_param('SAMPLE_SIZE'),
            'ad_size': get_int_param('AD_SIZE'),
            'pt_size': get_int_param('PT_SIZE'),
        }
        for vec in ascon_kat_vectors.select(**kwargs):
            await cocotb.triggers.with_timeout(test_ascon_vector(dut, vec, **test_params), *TIMEOUT)