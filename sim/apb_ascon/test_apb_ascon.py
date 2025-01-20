import os
import random
import enum
import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


class AsconException(Exception):
    pass

class Ascon:
    @staticmethod
    def get_param_value(dut, attr):
        """Get parameter value from DUT APB register module"""
        return getattr(dut.u_apb_registers, attr).value

    class Reg:
        """Register addresses"""
        def __init__(self, ctrl, status, key, nonce, tag, ad, pt, ct):
            self.ctrl = ctrl
            self.status = status
            self.key = key
            self.nonce = nonce
            self.tag = tag
            self.ad = ad
            self.pt = pt
            self.ct = ct

    class Status(enum.IntFlag):
        """Status register flags"""
        READY = enum.auto()
        WAIT_AD = enum.auto()
        WAIT_PT = enum.auto()
        TAG_VALID = enum.auto()
        AD_FULL = enum.auto()
        PT_FULL = enum.auto()
        CT_EMPTY = enum.auto()
        CT_FULL = enum.auto()

    class StatusFields:
        """Status register bit offsets"""
        def __init__(self, ready, wait_ad, wait_pt, tag_valid, ad_full, pt_full, ct_empty, ct_full):
            self.flags = [
                (Ascon.Status.READY, (1 << ready)),
                (Ascon.Status.WAIT_AD, (1 << wait_ad)),
                (Ascon.Status.WAIT_PT, (1 << wait_pt)),
                (Ascon.Status.TAG_VALID, (1 << tag_valid)),
                (Ascon.Status.AD_FULL, (1 << ad_full)),
                (Ascon.Status.PT_FULL, (1 << pt_full)),
                (Ascon.Status.CT_EMPTY, (1 << ct_empty)),
                (Ascon.Status.CT_FULL, (1 << ct_full)),
            ]

        def from_int(self, status_value):
            """Create flag enum"""
            result = Ascon.Status(0)
            
            # Build status flags dynamically using DUT offsets
            for flag, mask in self.flags:
                if status_value & mask:
                    result |= flag
                    
            return result

    class CtrlFields:
        """Control register field offsets"""
        def __init__(self, startbit, ad_size, pt_size, delay, data_width, delay_width):
            self.startbit = startbit
            self.ad_size = ad_size
            self.pt_size = pt_size
            self.delay = delay
            self.size_mask = (1 << data_width) - 1
            self.delay_mask = (1 << delay_width) - 1

        def to_int(self, start=0, ad_size=0, pt_size=0, delay=0):
            """Get the integer value for the control register"""
            ctrl = 0
            ctrl |= (start & 1) << self.startbit
            ctrl |= (ad_size & self.size_mask) << self.ad_size
            ctrl |= (pt_size & self.size_mask) << self.pt_size
            ctrl |= (delay & self.delay_mask) << self.delay
            return ctrl

    def __init__(self, dut):
        self.dut = dut
        self.n_bytes = self.dut.APB_DW.value // 8
        self.reg = self.Reg(
            ctrl=self.get_param_value(dut, "CtrlAddr"),
            status=self.get_param_value(dut, "StatusAddr"),
            key=self.get_param_value(dut, "KeyAddr"),
            nonce=self.get_param_value(dut, "NonceAddr"),
            tag=self.get_param_value(dut, "TagAddr"),
            ad=self.get_param_value(dut, "AdAddr"),
            pt=self.get_param_value(dut, "PtAddr"),
            ct=self.get_param_value(dut, "CtAddr"),
        )
        self.status = self.StatusFields(
            ready=self.get_param_value(dut, "ReadyOffset"),
            wait_ad=self.get_param_value(dut, "WaitAdOffset"),
            wait_pt=self.get_param_value(dut, "WaitPtOffset"),
            tag_valid=self.get_param_value(dut, "TagValidOffset"),
            ad_full=self.get_param_value(dut, "AdFullOffset"),
            pt_full=self.get_param_value(dut, "PtFullOffset"),
            ct_empty=self.get_param_value(dut, "CtEmptyOffset"),
            ct_full=self.get_param_value(dut, "CtFullOffset"),
        )
        self.ctrl = self.CtrlFields(
            startbit=self.get_param_value(dut, "StartBitOffset"),
            ad_size=self.get_param_value(dut, "ADSizeOffset"),
            pt_size=self.get_param_value(dut, "PTSizeOffset"),
            delay=self.get_param_value(dut, "DelayOffset"),
            data_width=self.get_param_value(dut, "DATA_AW"),
            delay_width=self.get_param_value(dut, "DELAY_WIDTH"),
        )
        self.buf_size = dut.FifoDepth.value * 8

    async def read(self, addr):
        """Read from APB register"""
        self.dut.PSEL.value = 1
        self.dut.PWRITE.value = 0
        self.dut.PADDR.value = addr
        await RisingEdge(self.dut.clk_in)
        self.dut.PENABLE.value = 1
        await RisingEdge(self.dut.clk_in)
        while not self.dut.PREADY.value:
            await RisingEdge(self.dut.clk_in)
        data = self.dut.PRDATA.value.integer
        self.dut.PSEL.value = 0
        self.dut.PENABLE.value = 0
        cocotb.log.info(f'read {data:08x} @ {addr:02x}')
        return data

    async def write(self, addr, data):
        """Write to APB register"""
        cocotb.log.info(f'write {data:08x} @ {addr:02x}')
        self.dut.PSEL.value = 1
        self.dut.PWRITE.value = 1
        self.dut.PADDR.value = addr
        self.dut.PWDATA.value = data
        await RisingEdge(self.dut.clk_in)
        self.dut.PENABLE.value = 1
        await RisingEdge(self.dut.clk_in)
        while not self.dut.PREADY.value:
            await RisingEdge(self.dut.clk_in)
        self.dut.PSEL.value = 0
        self.dut.PENABLE.value = 0

    async def read_seq(self, addr, n_bytes, byteorder='little'):
        """Read from consecutive APB registers"""
        buf = bytearray()
        for i in range(0, n_bytes, self.n_bytes):
            value = await self.read(addr + i)
            chunk = int.to_bytes(value, self.n_bytes, byteorder=byteorder)
            buf.extend(chunk)
        return bytes(buf[:n_bytes])

    async def write_seq(self, addr, data, n_bytes, byteorder='little'):
        """Write to consecutive APB registers"""
        for i in range(0, n_bytes, self.n_bytes):
            value = int.from_bytes(data[i:i+self.n_bytes], byteorder=byteorder)
            await self.write(addr + i, value)

    async def wait(self, flag, timeout):
        """Wait for status"""
        for _ in range(timeout):
            status = await self.read(self.reg.status)
            if flag in self.status.from_int(status):
                break
        else:
            raise AsconException(f'{flag.name} timeout after {timeout} trials')

    async def fast_encrypt(self, vector, timeout=100):
        """Perform a fast encryption operation"""
        if len(vector.ad) > self.buf_size or len(vector.pt) > self.buf_size:
            raise AsconException(f'input vector too large for fast_encrypt: ad={len(vector.ad)} B, pt={len(vector.pt)} B')

        # Clear control register
        await self.write(self.reg.ctrl, 0)
        
        # Wait for ready status
        await self.wait(self.Status.READY, timeout=timeout)

        # Write key and nonce
        await self.write_seq(self.reg.key, vector.key, len(vector.key))
        await self.write_seq(self.reg.nonce, vector.nonce, len(vector.nonce))
        
        # Configure control register
        ctrl_value = self.ctrl.to_int(
            start=1,
            ad_size=len(vector.ad),
            pt_size=len(vector.pt)
        )
        await self.write(self.reg.ctrl, ctrl_value)
        
        # Write AD
        buf = vector.ad
        while buf:
            chunk, buf = buf[:8], buf[8:]
            await self.write_seq(self.reg.ad, chunk, 8)

        # Write PT
        buf = vector.pt
        while buf:
            chunk, buf = buf[:8], buf[8:]
            await self.write_seq(self.reg.pt, chunk, 8)

        # Read CT
        ct = bytearray()
        while len(ct) < len(vector.pt):
            status = await self.read(self.reg.status)
            status = self.status.from_int(status)
            if self.Status.TAG_VALID in status:
                raise AsconException('bit TAG_VALID set before the end of the encryption')
            elif self.Status.CT_EMPTY not in status:
                chunk = await self.read_seq(self.reg.ct, 8)
                ct.extend(chunk)
        ct = bytes(ct[:len(vector.pt)])

        # Wait for completion of the encryption
        await self.wait(self.Status.TAG_VALID, timeout=timeout)

        # Read tag
        tag = await self.read_seq(self.reg.tag, 16)

        # Clear control register
        await self.write(self.reg.ctrl, 0)
        
        # Wait for ready status
        await self.wait(self.Status.READY, timeout=timeout)

        # Return results
        return ct, tag

    async def reset(self):
        """Reset the DUT"""
        self.dut.reset_int.value = 0
        await Timer(20, units="ns")
        self.dut.reset_int.value = 1
        await Timer(20, units="ns")

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

    @classmethod
    def load(cls, filename, filt=None, sample_size=None):
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
                        vec = cls(
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
                    
        if sample_size is not None:
            vectors = random.sample(vectors, min(sample_size, len(vectors)))

        return vectors

def check_results(ct, tag, vector):
    """Verify results"""
    assert ct == vector.ct, f"CT mismatch: got {ct.hex()}, expected {vector.ct.hex()}"
    assert tag == vector.tag, f"Tag mismatch: got {tag.hex()}, expected {vector.tag.hex()}"

@cocotb.test()
async def test_vector(dut):
    """Test a single vector"""
    # Start clock
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())

    ascon = Ascon(dut)
    
    # Reset DUT
    await ascon.reset()
    
    # Load and process a single vector
    kat_file = os.environ.get('KAT_PATH', 'LWC_AEAD_KAT_128_128.txt')
    count = int(os.environ.get('ID', '1'))
    vectors = KATVector.load(kat_file, lambda v: v.count == count)
    if vectors:
        cocotb.log.info(f'testing vector with Count = {vectors[0].count}...')
        ct, tag = await ascon.fast_encrypt(vectors[0])
        check_results(ct, tag, vectors[0])
    else:
        cocotb.log.error(f'no vector found with Count = {count}.')

@cocotb.test()
async def test_sample(dut):
    """Test a random sample of vectors"""
    # Start clock
    clock = Clock(dut.clk_in, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    ascon = Ascon(dut)

    # Reset DUT
    await ascon.reset()
    
    # Load and process a sample of vectors
    kat_file = os.environ.get('KAT_PATH', 'LWC_AEAD_KAT_128_128.txt')
    sample_size = os.environ.get('SAMPLE_SIZE', None)
    for vector in KATVector.load(kat_file, sample_size=sample_size):
        cocotb.log.info(f'testing vector with Count = {vector.count}...')
        ct, tag = await ascon.fast_encrypt(vector)
        check_results(ct, tag, vector)