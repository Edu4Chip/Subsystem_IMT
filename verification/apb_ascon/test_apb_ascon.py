import ascon_kat
import cocotb
import cocotb.triggers
import cocotb.utils
import collections
import dataclasses
import enum
import os

from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
from typing import Optional, Tuple


ascon_kat.read_kat('LWC_AEAD_KAT_128_128.txt')


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


def blocks(data: bytes, bs: int = 8, pad=False):
    if pad:
        return (data[i:i+bs].ljust(bs, b'\x00') for i in range(0, len(data), bs))
    else:
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


def log_vec(vec: ascon_kat.Vector):
    """Log the encryption parameters."""
    cocotb.log.info(f'== COUNT {vec.count:<4d} ==')
    cocotb.log.info(f'- key     = {blkstr(vec.key)}')
    cocotb.log.info(f'- nonce   = {blkstr(vec.nonce)}')
    cocotb.log.info(f'- ad      = {blkstr(vec.ad)}')
    cocotb.log.info(f'- pt      = {blkstr(vec.pt)}')
    cocotb.log.info(f'- ct      = {blkstr(vec.ct)}')
    cocotb.log.info(f'- tag     = {blkstr(vec.tag)}')
    cocotb.log.info(f'- ad size = {len(vec.ad):4d} Bytes')
    cocotb.log.info(f'- pt size = {len(vec.pt):4d} Bytes')


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
    return Status(status)


async def apb_write_int(dut, addr : int, value : int):
    """Write a register."""
    dut.PSEL.value = 1
    dut.PENABLE.value = 0
    dut.PWRITE.value = 1
    dut.PADDR.value = addr
    dut.PWDATA.value = value
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


async def configure_ascon(dut, key, nonce):
    cocotb.log.info('start configuration...')

    # wait for the device to be ready
    cocotb.log.info('Wait DUT...')
    await apb_write_int(dut, Reg.CTRL, 0)
    status = await apb_read_status(dut)
    while Status.READY not in status:
        status = await apb_read_status(dut)
    cocotb.log.info('DUT is ready.')

    # setup the parameters of the computation
    cocotb.log.info('write KEY registers...')
    await apb_write_blocks(dut, Reg.KEY, key)
    cocotb.log.info('write NONCE registers...')
    await apb_write_blocks(dut, Reg.NONCE, nonce)

    cocotb.log.info('configuration done.')


async def encrypt(dut, ad: bytes, pt: bytes, delay: int = 0) -> Tuple[bytes, bytes]:
    # initializes data queues
    bs = 8
    ad_buffer = collections.deque(blocks(ad, bs=bs, pad=True))
    pt_buffer = collections.deque(blocks(pt, bs=bs, pad=True))
    ct_buffer = collections.deque()

    # abort pending encryptions and wait for the device to be ready
    cocotb.log.info('Wait DUT...')
    await apb_write_int(dut, Reg.CTRL, 0)
    status = await apb_read_status(dut)
    while Status.READY not in status:
        status = await apb_read_status(dut)
    cocotb.log.info('DUT is ready.')
    
    # start encryption
    cocotb.log.info('write CTRL...')
    cfg = CtrlCfg(
        flags=CtrlFlags.START,
        delay=delay,
        ad_size=len(ad),
        pt_size=len(pt),
    )
    await apb_write_ctrl(dut, cfg)

    # send AD blocks
    status = await apb_read_status(dut)
    while ad_buffer:
        if Status.TAG_VALID in status:
            raise Exception('unexpected termination of encryption')
        if Status.AD_FULL not in status:
            cocotb.log.info('write AD FIFO...')
            data = ad_buffer.popleft()
            await apb_write_blocks(dut, Reg.AD, data)
        status = await apb_read_status(dut)
    
    # send PT blocks, retrieve CT blocks if any
    while pt_buffer:
        if Status.TAG_VALID in status:
            raise Exception('unexpected termination of encryption')
        if Status.CT_EMPTY not in status:
            cocotb.log.info('read CT FIFO...')
            blk = await apb_read_blocks(dut, Reg.CT, bs)
            ct_buffer.append(blk)
        if Status.PT_FULL not in status:
            cocotb.log.info('write PT FIFO...')
            data = pt_buffer.popleft()
            await apb_write_blocks(dut, Reg.PT, data)
        status = await apb_read_status(dut)

    # retrieve the tag
    cocotb.log.info('wait for the tag...')
    while Status.TAG_VALID not in status:
        if Status.CT_EMPTY not in status:
            cocotb.log.info('read CT FIFO...')
            blk = await apb_read_blocks(dut, Reg.CT, bs)
            ct_buffer.append(blk)
        status = await apb_read_status(dut)
    
    # retrive the remaining CT blocks
    cocotb.log.info('read CT FIFO...')
    while Status.CT_EMPTY not in status:
        blk = await apb_read_blocks(dut, Reg.CT, bs)
        ct_buffer.append(blk)
        status = await apb_read_status(dut)

    cocotb.log.info('retrieve the tag...')
    tag = await apb_read_blocks(dut, Reg.TAG, 16)

    cocotb.log.info('encryption done.')
    ct = b''.join(ct_buffer)
    ct = ct[:len(pt)]
    return (ct, tag)


def check_result(sim_ct, sim_tag, ref_ct, ref_tag):
    """Check the ciphertext and the tag against the KAT vector."""
    _log('ct', sim_ct, 'sim')
    _log('ct', ref_ct, 'ref')
    assert sim_ct == ref_ct, f'ciphertext comparison failed!'
    _log('tag', sim_tag, 'sim')
    _log('tag', ref_tag, 'ref')
    assert sim_tag == ref_tag, f'tag comparison failed!'


async def test_sample(dut, vec, delay: int = 0):
    log_vec(vec)
    await configure_ascon(dut, vec.key, vec.nonce)
    ct, tag = await encrypt(dut, vec.ad, vec.pt, delay)
    check_result(ct, tag, vec.ct, vec.tag)


def get_int_param(key, default=None) -> Optional[int]:
    try:
        return int(os.environ[key])
    except (KeyError, TypeError):
        return default


@cocotb.test()
async def test_single(dut):
    # run the clock
    clk = Clock(dut.clk_in, 100, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    # retrieve KAT vectors from the Ascon reference implementation and test them
    sample_count = get_int_param('SAMPLE_COUNT')
    test_params = {
        'delay': get_int_param('PROG_DELAY', 0)
    }
    if sample_count is not None:
        vec = ascon_kat.get(sample_count)
        await cocotb.triggers.with_timeout(test_sample(dut, vec, **test_params), 25, 'us')
    else:
        kwargs = {
            'k': 1,
            'ad_size': get_int_param('AD_SIZE'),
            'pt_size': get_int_param('PT_SIZE'),
        }
        for vec in ascon_kat.select(**kwargs):
            await cocotb.triggers.with_timeout(test_sample(dut, vec, **test_params), 25, 'us')


@cocotb.test()
async def test_sequence(dut):
    # run the clock
    clk = Clock(dut.clk_in, 100, 'ns')
    cocotb.start_soon(clk.start())
    cocotb.start_soon(reset_dut(dut))
    # retrieve KAT vectors from the Ascon reference implementation and test them
    test_params = {
        'delay': get_int_param('PROG_DELAY')
    }
    kwargs = {
        'k': get_int_param('SAMPLE_SIZE'),
    }
    for vec in ascon_kat.select(**kwargs):
        await cocotb.triggers.with_timeout(test_sample(dut, vec, **test_params), 25, 'us')