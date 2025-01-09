import os
import random
import enum
import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

class Reg(enum.Enum):
    """Register addresses"""
    CTRL = "CtrlAddr"
    STATUS = "StatusAddr"
    KEY = "KeyAddr"
    NONCE = "NonceAddr"
    TAG = "TagAddr"
    AD = "AdAddr"
    PT = "PtAddr"
    CT = "CtAddr"

class Status(enum.IntFlag):
    """Status register bits"""
    Ready = enum.auto()
    WaitAD = enum.auto()
    WaitPT = enum.auto()
    TagValid = enum.auto()
    ADFull = enum.auto()
    PTFull = enum.auto()
    CTEmpty = enum.auto()
    CTFull = enum.auto()

StatusOffset = {
    Status.Ready: "ReadyOffset",
    Status.WaitAD: "WaitAdOffset",
    Status.WaitPT: "WaitPtOffset",
    Status.TagValid: "TagValidOffset",
    Status.ADFull: "AdFullOffset",
    Status.PTFull: "PtFullOffset",
    Status.CTEmpty: "CtEmptyOffset",
    Status.CTFull: "CtFullOffset",
}

class Ctrl(enum.Enum):
    """Control register field offsets"""
    StartBit = "StartBitOffset"
    ADSize = "ADSizeOffset"
    PTSize = "PTSizeOffset"
    Delay = "DelayOffset"

class KATVector:
    """Known Answer Test vector"""
    def __init__(self, count=0, key=b'', nonce=b'', pt=b'', ad=b'', ct=b'', tag=b''):
        self.count = count
        self.key = key
        self.nonce = nonce
        self.pt = pt
        self.ad = ad
        self.ct = ct
        self.tag = tag

def reg_addr(dut, reg):
    """Get register address from DUT"""
    return int(getattr(dut.u_apb_registers, reg.value).value)

def status_offset(dut, flag):
    """Get status bit offset from DUT"""
    return int(getattr(dut.u_apb_registers, StatusOffset[flag.value]).value)

def ctrl_offset(dut, flag):
    """Get control bit offset from DUT"""
    return int(getattr(dut.u_apb_registers, flag.value).value)

def ctrl_width(dut, field):
    """Get control register field width from DUT"""
    if field in (Ctrl.ADSize, Ctrl.PTSize):
        return int(dut.u_apb_registers.DATA_AW.value)
    elif field == Ctrl.Delay:
        return int(dut.u_apb_registers.DELAY_WIDTH.value)
    else:  # StartBit is always 1 bit
        return 1

async def reset_dut(dut):
    """Reset the DUT"""
    dut.reset_int.value = 0
    await Timer(20, units="ns")
    dut.reset_int.value = 1
    await Timer(20, units="ns")

async def apb_write(dut, reg, data, offset=0):
    """Write to APB register using dynamic address"""
    addr = reg_addr(dut, reg) + offset
    dut.PSEL.value = 1
    dut.PWRITE.value = 1
    dut.PADDR.value = addr
    dut.PWDATA.value = data
    await RisingEdge(dut.clk_in)
    dut.PENABLE.value = 1
    await RisingEdge(dut.clk_in)
    while not dut.PREADY.value:
        await RisingEdge(dut.clk_in)
    dut.PSEL.value = 0
    dut.PENABLE.value = 0

async def apb_write_bytes(dut, reg, data, offset=0, byteorder='little'):
    """Write to APB register using dynamic address"""
    data = int.from_bytes(data, byteorder=byteorder)
    await apb_write(dut, reg, data, offset)

async def apb_read(dut, reg, offset=0):
    """Read from APB register using dynamic address"""
    addr = reg_addr(dut, reg) + offset
    dut.PSEL.value = 1
    dut.PWRITE.value = 0
    dut.PADDR.value = addr
    await RisingEdge(dut.clk_in)
    dut.PENABLE.value = 1
    await RisingEdge(dut.clk_in)
    while not dut.PREADY.value:
        await RisingEdge(dut.clk_in)
    data = dut.PRDATA.value.integer
    dut.PSEL.value = 0
    dut.PENABLE.value = 0
    return data

async def apb_read_bytes(dut, reg, offset=0, byteorder='little'):
    """Read from APB register using dynamic address"""
    data = await apb_read(dut, reg, offset)
    return int.to_bytes(data, dut.APB_DW.value // 8, byteorder=byteorder)

async def apb_cfg(dut, start=0, ad_size=0, pt_size=0, delay=0):
    """Configure control register using dynamic offsets and widths"""
    ctrl = 0
    
    # Build each field with dynamic offset and width
    for field, value in [
        (Ctrl.StartBit, start),
        (Ctrl.ADSize, ad_size),
        (Ctrl.PTSize, pt_size),
        (Ctrl.Delay, delay)
    ]:
        width = ctrl_width(dut, field)
        mask = (1 << width) - 1
        offset = ctrl_offset(dut, field)
        ctrl |= (value & mask) << offset

    await apb_write(dut, Reg.CTRL, ctrl)

async def apb_status(dut):
    """Read status register and create flag enum"""
    status_value = await apb_read(dut, Reg.STATUS)
    result = Status(0)
    
    # Build status flags dynamically using DUT offsets
    for flag in Status:
        if status_value & (1 << status_offset(dut, flag)):
            result |= flag
            
    return result

def load(filename, filt=None):
    """Load KAT vectors from file"""
    vectors = []
    current = {}
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                if current:
                    pt = bytes.fromhex(current.get('pt', ''))
                    total_ct = bytes.fromhex(current.get('ct', ''))
                    ct, tag = total_ct[:len(pt)], total_ct[len(pt):]
                    vec = KATVector(
                        count=int(current.get('count', '0')),
                        key=bytes.fromhex(current.get('key', '')),
                        nonce=bytes.fromhex(current.get('nonce', '')),
                        pt=pt,
                        ad=bytes.fromhex(current.get('ad', '')),
                        ct=ct,
                        tag=tag
                    )
                    if not filt or filt(vec):
                        vectors.append(vec)
                current = {}
                continue
                
            if '=' in line:
                key, value = map(str.strip, line.split('='))
                current[key.lower()] = value
                
    return vectors

def shuffle(vectors, size=None):
    """Get random sample of vectors"""
    if size is None:
        return vectors
    return random.sample(vectors, min(size, len(vectors)))

async def encrypt(dut, vector):
    """Perform encryption operation"""
    cocotb.log.info(f'testing vector with Count = {vector.count}...')

    n_bytes = dut.APB_DW.value // 8

    # Clear control register
    await apb_cfg(dut)
    
    # Wait for ready status
    while Status.Ready not in await apb_status(dut):
        await RisingEdge(dut.clk_in)
    
    # Write key and nonce
    for reg, data in [(Reg.KEY, vector.key), (Reg.NONCE, vector.nonce)]:
        for i in range(0, len(data), n_bytes):
            await apb_write_bytes(dut, reg, data[i:i+n_bytes], offset=i)
    
    # Configure control register
    await apb_cfg(dut, start=1, ad_size=len(vector.ad), pt_size=len(vector.pt))
    
    # Write AD and PT data
    for reg, data, full in [(Reg.AD, vector.ad, Status.ADFull), (Reg.PT, vector.pt, Status.PTFull)]:
        for i in range(0, len(data), 8):
            chunk = data[i:i+8].ljust(8, b'\x00')
            while full in await apb_status(dut):
                await RisingEdge(dut.clk_in)
            for i in range(0, len(chunk), n_bytes):
                await apb_write_bytes(dut, reg, chunk[i:i+n_bytes], offset=i)
    
    # Wait for completion
    while Status.TagValid not in await apb_status(dut):
        await RisingEdge(dut.clk_in)
    
    # Read ciphertext
    ct = bytearray()
    while len(ct) < len(vector.pt):
        while Status.CTEmpty in await apb_status(dut):
            await RisingEdge(dut.clk_in)
        for i in range(0, 8, n_bytes):
            ct.extend(await apb_read_bytes(dut, Reg.CT, offset=i))
    ct = bytes(ct[:len(vector.pt)])
    
    # Read tag
    tag = bytearray()
    for i in range(0, 16, n_bytes):
        tag.extend(await apb_read_bytes(dut, Reg.TAG, offset=i))
    tag = bytes(tag[:16])
    
    # Clear control register
    await apb_cfg(dut)
    
    # Wait for ready status
    while Status.Ready not in await apb_status(dut):
        await RisingEdge(dut.clk_in)
    
    # Verify results
    assert ct == vector.ct, f"CT mismatch: got {ct.hex()}, expected {vector.ct.hex()}"
    assert tag == vector.tag, f"Tag mismatch: got {tag.hex()}, expected {vector.tag.hex()}"

@cocotb.test()
async def test_vector(dut):
    """Test a single vector"""
    kat_file = os.environ.get('KAT_PATH', 'LWC_AEAD_KAT_128_128.txt')

    # Start clock
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Load and process vector
    count = int(os.environ.get('ID', '1'))
    vectors = load(kat_file, lambda v: v.count == count)
    if vectors:
        await encrypt(dut, vectors[0])
    else:
        cocotb.log.error(f'no vector found with Count = {count}.')

@cocotb.test()
async def test_sample(dut):
    """Test a random sample of vectors"""
    kat_file = os.environ.get('KAT_PATH', 'LWC_AEAD_KAT_128_128.txt')

    # Start clock
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Load and process vectors
    sample_size = os.environ.get('SAMPLE_SIZE', None)
    vectors = load(kat_file)
    vectors = shuffle(vectors, sample_size)
    for vector in vectors:
        await encrypt(dut, vector)