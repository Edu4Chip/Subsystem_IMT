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


PERIOD = 100
TIMEOUT = (25, 'us')


class Reg(enum.IntEnum):
    CTRL = 0x00
    STATUS = 0x04
    KEY = 0x08
    NONCE = 0x18
    TAG = 0x28
    DATAIN = 0x38
    DATAOUT = 0x58


class Status(enum.Flag):
    READY = 0b0001
    DONE = 0b0010
    CT_READY = 0b0100
    DATA_REQ = 0b1000


class CtrlFlags(enum.Flag):
    NONE = 0b000
    START = 0b001
    VALID_DATA = 0b010
    ACK_READ = 0b100


@dataclasses.dataclass
class CtrlCfg:
    delay : int = 0
    ad_size : int = 0
    pt_size : int = 0


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


async def apb_write(dut, addr : int, data : bytes):
    """Write a register."""
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    dut.PWRITE.value = 1
    dut.PADDR.value = addr
    dut.PWDATA.value = LogicArray(
        int.from_bytes(data, byteorder='big', signed=False),
        Range(dut.APB_DW.value - 1, 'downto', 0)
    )
    await ClockCycles(dut.clk_in, 1)
    dut.PENABLE.value = 1
    await ClockCycles(dut.clk_in, 1)
    dut.PSEL.value = 0
    dut.PWDATA.value = 0
    log_tx(f'@ {addr:02x}', data)


async def apb_read_blocks(dut, addr: int, data_size: int):
    block_size = dut.APB_DW.value // 8
    recv = b''
    while data_size > 0:
        blk = await apb_read(dut, addr)
        recv += blk
        addr += block_size
        data_size -= block_size
    return recv


async def apb_write_blocks(dut, addr: int, data: bytes):
    block_size = dut.APB_DW.value // 8
    for _, blk in Blocks(data, block_size=block_size):
        await apb_write(dut, addr, blk)
        addr += block_size


async def apb_read_status(dut) -> Status:
    """Read the status register."""
    status = await apb_read_int(dut, Reg.STATUS)
    status = Status(status)
    cocotb.log.info(f'check dut: status = {status}...')
    return status


async def _wait_status(dut, flag: Status, level=1):
    """Wait for given flags in the status register."""
    status = await apb_read_status(dut)
    if level:
        while flag not in status:
            await ClockCycles(dut.clk_in, 1)
            status = await apb_read_status(dut)
    else:
        while flag in status:
            await ClockCycles(dut.clk_in, 1)
            status = await apb_read_status(dut)


async def wait_status(dut, flag: Status, level=1):
    """Wait for given flags in the status register before a fixed timeout."""
    await cocotb.triggers.with_timeout(_wait_status(dut, flag, level), *TIMEOUT)


async def apb_read_ctrl(dut) -> CtrlCfg:
    """Read the control register."""
    ctrl = await apb_read_int(dut, Reg.CTRL)
    return CtrlCfg(
        delay=(ctrl >> 8) & 0xFF,
        ad_size=(ctrl >> 16) & 0xFF,
        pt_size=(ctrl >> 24) & 0xFF,
    )


async def apb_write_ctrl(
        dut,
        flags: Optional[CtrlFlags] = CtrlFlags.NONE,
        cfg: Optional[CtrlCfg] = None
    ):
    """Write the control register."""
    if cfg is None:
        cfg = await apb_read_ctrl(dut)
    data = bytes([cfg.pt_size, cfg.ad_size, cfg.delay, flags.value])
    await apb_write(dut, Reg.CTRL, data)


async def test_ascon_vector(dut, vec: ascon_kat_vectors.Vector):
    """Simulate a transaction with the DUT given a test vector."""
    cocotb.log.info(f'running test Count = {vec.count}...')
    start_time = cocotb.utils.get_sim_time('ns')

    # log the encryption parameters
    log_params(vec)

    # initializes data queues
    buf_block_size = dut.BUF_DEPTH.value * 8
    data_buffer = collections.deque()
    data_buffer.extend(
        block.ljust(buf_block_size, b'\x00')
        for _, block in Blocks(vec.ad + vec.pt, block_size=buf_block_size)
    )
    cocotb.log.info(f'initialized data queue: {len(data_buffer)} {buf_block_size}-bytes blocks pending...')
    for i, blk in enumerate(data_buffer):
        cocotb.log.info(f'- data_buffer[{i:d}] = {Blocks(blk)!s}')
    ct_buffer = collections.deque()

    # wait for the device to be ready
    await wait_status(dut, Status.READY)
    cocotb.log.info('DUT is ready...')
    await ClockCycles(dut.clk_in, 1)

    # setup the parameters of the computation
    cocotb.log.info('configure encryption...')
    cocotb.log.info('...write KEY registers')
    await apb_write_blocks(dut, Reg.KEY, vec.key)
    cocotb.log.info('...write NONCE registers')
    await apb_write_blocks(dut, Reg.NONCE, vec.nonce)
    cocotb.log.info('...write DATAIN registers')
    blk = data_buffer.popleft()
    await apb_write_blocks(dut, Reg.DATAIN, blk)
    cocotb.log.info('...write CTRL register')
    cfg = CtrlCfg(
        ad_size=len(vec.ad) // 8,
        pt_size=len(vec.pt) // 8,
    )
    await apb_write_ctrl(dut, cfg=cfg)

    # start the computation
    cocotb.log.info('start encryption...')
    await apb_write_ctrl(dut, flags=CtrlFlags.START)
    await wait_status(dut, Status.READY, level=0)

    # send and receive data blocks
    status = await apb_read_status(dut)
    while Status.DONE not in status:
        if Status.CT_READY in status:
            cocotb.log.info('retrieve a block of ciphertext...')
            cocotb.log.info('...read DATAOUT registers')
            blk = await apb_read_blocks(dut, Reg.DATAOUT, buf_block_size)
            ct_buffer.append(blk)
            cocotb.log.info('...acknowledge reading')
            await apb_write_ctrl(dut, flags=CtrlFlags.ACK_READ)
        elif Status.DATA_REQ in status:
            cocotb.log.info('send a block of data...')
            cocotb.log.info('...write DATAIN registers')
            if not data_buffer:
                raise Exception('empty data buffer')
            blk = data_buffer.popleft()
            await apb_write_blocks(dut, Reg.DATAIN, blk)
            cocotb.log.info('...validate DATAIN registers')
            await apb_write_ctrl(dut, flags=CtrlFlags.VALID_DATA)
        status = await apb_read_status(dut)
    cocotb.log.info('encryption done.')
    # read the last block
    cocotb.log.info('retrieve a block of ciphertext...')
    blk = await apb_read_blocks(dut, Reg.DATAOUT, buf_block_size)
    ct_buffer.append(blk)
    ct = b''.join(ct_buffer)
    ct = ct[:vec.pt_size]
    # read the tag
    cocotb.log.info('retrieve the tag...')
    tag = await apb_read_blocks(dut, Reg.TAG, 16)

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


def get_int_param(key) -> Optional[int]:
    k = os.environ.get(key, '')
    return int(k) if str.isdecimal(k) else None


@cocotb.test()
async def test_ascon(dut):
    # run the clock
    clk = Clock(dut.clk_in, PERIOD, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    # retrieve KAT vectors from the Ascon reference implementation and test them
    sample_count = get_int_param('SAMPLE_COUNT')
    if sample_count is not None:
        vec = ascon_kat_vectors.get(sample_count)
        await cocotb.triggers.with_timeout(test_ascon_vector(dut, vec), *TIMEOUT)
    else:
        params = {
            'k': get_int_param('SAMPLE_SIZE'),
            'ad_size': get_int_param('AD_SIZE'),
            'pt_size': get_int_param('PT_SIZE'),
        }
        for vec in ascon_kat_vectors.select(**params):
            await cocotb.triggers.with_timeout(test_ascon_vector(dut, vec), *TIMEOUT)