from enum import IntEnum, IntFlag

import vsc
from pyuvm import uvm_sequence
from uvc.apb.agents.apb_common import OpType
from uvc.apb.agents.cl_apb_seq_item import cl_apb_seq_item
from uvc.ascon.agents.core.core_seq_item import AsconCoreOpItem, AsconCoreResultItem
from uvc.ascon.utils.ascon_model import AsconModel


class RegAddr(IntEnum):
    STATUS = 0
    CTRL = 4
    ACK = 8
    CONFIG = 12
    KEY = 16
    NONCE = 32
    TAG = 48
    DI = 64
    DO = 80


class AsconCtrlOp(IntEnum):
    STOP = 0
    START_ENC = 1
    START_DEC = 3


class AsconStatus(IntFlag):
    BUSY = 1 << 0
    DONE = 1 << 1
    DI_READY = 1 << 2
    DO_VALID = 1 << 3
    TAG_VALID = 1 << 4


class AsconAck(IntFlag):
    DI_VALID = 1 << 0
    DO_READY = 1 << 1


def build_config_words(ad_size: int, di_size: int, delay: int) -> int:
    return (delay << 16) | (di_size << 8) | ad_size


@vsc.randobj
class AsconAPBOpSeq(uvm_sequence):
    def __init__(self, name):
        super().__init__(name)
        self.op: AsconCoreOpItem = vsc.attr(AsconCoreOpItem.create(f"{name}.op_item"))
        self.apb_word_len = 4
        self.ascon_rate = 16
        self.byteorder = "little"

    def set_apb_width(self, data_width):
        self.apb_word_len = data_width // 8

    def iter_apb_words(self, data: bytes):
        for offset in range(0, len(data), self.apb_word_len):
            word = data[offset : offset + self.apb_word_len]
            yield offset, word

    async def write(self, item_name: str, addr: int, data: int):
        item = cl_apb_seq_item.create(item_name)
        await self.start_item(item)
        with item.randomize_with() as it:
            assert isinstance(it, cl_apb_seq_item)
            it.op == OpType.WR
            it.addr == addr
            it.data == data
        await self.finish_item(item)
        # response ID is not unique and may conflict with another request
        # the response must be read to avoid this issue
        rsp = await self.get_response()
        assert rsp.slverr == 0, f"FAILED: write error: {rsp!s}"

    async def write_seq(self, item_prefix: str, base_addr: int, data: bytes):
        for i, (offset, word) in enumerate(self.iter_apb_words(data)):
            await self.write(
                f"{item_prefix}.wr_item({i})",
                base_addr + offset,
                int.from_bytes(word, byteorder=self.byteorder),
            )

    async def read(self, item_name: str, addr: int) -> int:
        item = cl_apb_seq_item.create(item_name)
        await self.start_item(item)
        with item.randomize_with() as it:
            assert isinstance(it, cl_apb_seq_item)
            it.op == OpType.RD
            it.addr == addr
        await self.finish_item(item)
        rsp = await self.get_response()
        assert rsp.slverr == 0, f"FAILED: read error: {rsp!s}"
        return rsp.data

    async def read_seq(self, item_prefix: str, base_addr: int, size: int) -> bytes:
        data = b""
        for i, offset in enumerate(range(0, size, self.apb_word_len)):
            word = await self.read(f"{item_prefix}.rd_item({i})", base_addr + offset)
            data += int.to_bytes(
                word,
                length=self.apb_word_len,
                byteorder=self.byteorder,
            )
        return data[:size]

    async def wait_flag_set(self, flag: AsconStatus):
        is_set = False
        while not is_set:
            status = await self.read("status.rd_item", RegAddr.STATUS)
            is_set = flag in AsconStatus(status)

    async def wait_flag_clr(self, flag: AsconStatus):
        is_clr = False
        while not is_clr:
            status = await self.read("status.rd_item", RegAddr.STATUS)
            is_clr = flag not in AsconStatus(status)

    async def body(self):
        # Stop previous computation
        await self.write("stop.wr_item", RegAddr.CTRL, AsconCtrlOp.STOP)
        await self.wait_flag_clr(AsconStatus.BUSY)

        # Write key
        key = int.to_bytes(self.op.key, length=16, byteorder=self.byteorder)
        await self.write_seq("key", RegAddr.KEY, key)

        # Write nonce
        nonce = int.to_bytes(self.op.nonce, length=16, byteorder=self.byteorder)
        await self.write_seq("nonce", RegAddr.NONCE, nonce)

        # Write config
        config = build_config_words(self.op.ad_size, self.op.di_size, self.op.delay)
        await self.write("config.wr_item", RegAddr.CONFIG, config)

        # Start operation
        if self.op.decrypt == 0:
            await self.write("start_enc.wr_item", RegAddr.CTRL, AsconCtrlOp.START_ENC)
        else:
            await self.write("start_dec.wr_item", RegAddr.CTRL, AsconCtrlOp.START_DEC)
        await self.wait_flag_set(AsconStatus.BUSY)

        # Write AD
        for i, block in enumerate(
            self.op.iter_ad_blocks(rate=self.ascon_rate, byteorder=self.byteorder)
        ):
            await self.wait_flag_set(AsconStatus.DI_READY)
            data = int.to_bytes(block, length=self.ascon_rate, byteorder=self.byteorder)
            await self.write_seq(f"ad({i})", RegAddr.DI, data)
            await self.write("ack.wr_item", RegAddr.ACK, AsconAck.DI_VALID)

        # Write DI and read DO
        do = b""
        for i, block in enumerate(
            self.op.iter_di_blocks(rate=self.ascon_rate, byteorder=self.byteorder)
        ):
            await self.wait_flag_set(AsconStatus.DI_READY)
            data = int.to_bytes(block, length=self.ascon_rate, byteorder=self.byteorder)
            await self.write_seq(f"di({i})", RegAddr.DI, data)
            await self.write("ack.wr_item", RegAddr.ACK, AsconAck.DI_VALID)
            await self.wait_flag_set(AsconStatus.DO_VALID)
            do += await self.read_seq(f"do({i})", RegAddr.DO, self.ascon_rate)
            await self.write("ack.wr_item", RegAddr.ACK, AsconAck.DO_READY)

        # Wait for completion
        await self.wait_flag_set(AsconStatus.TAG_VALID | AsconStatus.DONE)

        # Read tag
        tag = await self.read_seq("tag", RegAddr.TAG, 16)

        # Stop computation
        await self.write("stop.wr_item", RegAddr.CTRL, AsconCtrlOp.STOP)
        await self.wait_flag_clr(AsconStatus.BUSY)

        # Compute expected result
        key = int.to_bytes(self.op.key, length=16, byteorder=self.byteorder)
        nonce = int.to_bytes(self.op.nonce, length=16, byteorder=self.byteorder)
        ad = int.to_bytes(self.op.ad, length=self.op.ad_size, byteorder=self.byteorder)
        di = int.to_bytes(self.op.di, length=self.op.di_size, byteorder=self.byteorder)

        with AsconModel() as model:
            if self.op.decrypt == 0:
                exp_do, exp_tag = model.ascon_encrypt(key, nonce, ad, di)
            else:
                exp_do, exp_tag = model.ascon_decrypt(key, nonce, ad, di)

        assert do == exp_do, (
            "FAILED: do != exp_do\n",
            "+ where:\n",
            f"+   do     = {do.hex()}\n",
            f"+   exp_do = {exp_do.hex()}\n",
        )

        assert tag == exp_tag, (
            "FAILED: tag != exp_tag\n",
            "+ where:\n",
            f"+   tag     = {tag.hex()}\n",
            f"+   exp_tag = {exp_tag.hex()}\n",
        )
