import vsc
from pyuvm import uvm_sequence

from ..agents.core.core_seq_item import AsconCoreOpItem


@vsc.randobj
class AsconSingleEncSeq(uvm_sequence):
    def __init__(self, name):
        super().__init__(name)
        self.ad = b""
        self.di = b""
        self.key = b""
        self.nonce = b""
        self.byteorder = "little"

    async def body(self):
        item_cls = AsconCoreOpItem
        item = item_cls.create(f"{self.get_name()}.op_item")
        assert isinstance(item, item_cls)
        await self.start_item(item)
        with item.randomize_with() as it:
            assert isinstance(it, item_cls)
            it.key == int.from_bytes(self.key, byteorder=self.byteorder)
            it.nonce == int.from_bytes(self.nonce, byteorder=self.byteorder)
        item.decrypt = 0
        item.ad_size = len(self.ad)
        item.di_size = len(self.di)
        item.ad = int.from_bytes(self.ad, byteorder=self.byteorder)
        item.di = int.from_bytes(self.di, byteorder=self.byteorder)
        await self.finish_item(item)


@vsc.randobj
class AsconRandEncSeq(uvm_sequence):
    def __init__(self, name):
        super().__init__(name)
        self.di = vsc.rand_bit_t(128)
        self.di_size = 16
        self.byteorder = "little"

    async def body(self):
        item_cls = AsconCoreOpItem
        item = item_cls.create(f"{self.get_name()}.op_item")
        assert isinstance(item, item_cls)
        await self.start_item(item)
        item.randomize()
        item.decrypt = 0
        item.ad_size = 0
        item.di_size = self.di_size
        item.ad = 0
        item.di = self.di
        await self.finish_item(item)


@vsc.randobj
class AsconRefEncSeq(uvm_sequence):
    ref = bytes(range(32))
    key = ref[:16]
    nonce = ref[16:]

    def __init__(self, name):
        super().__init__(name)
        self.ad_size = vsc.rand_bit_t(8)
        self.di_size = vsc.rand_bit_t(8)
        self.byteorder = "little"

    async def body(self):
        item_cls = AsconCoreOpItem
        item = item_cls.create(f"{self.get_name()}.op_item")
        assert isinstance(item, item_cls)
        await self.start_item(item)
        with item.randomize_with() as it:
            assert isinstance(it, item_cls)
            it.delay == 0
            it.key == int.from_bytes(self.key, byteorder=self.byteorder)
            it.nonce == int.from_bytes(self.nonce, byteorder=self.byteorder)
        item.decrypt = 0
        item.ad_size = self.ad_size
        item.di_size = self.di_size
        item.ad = int.from_bytes(self.ref[: self.ad_size], byteorder=self.byteorder)
        item.di = int.from_bytes(self.ref[: self.di_size], byteorder=self.byteorder)
        await self.finish_item(item)


@vsc.randobj
class AsconKATFullEncSeq(uvm_sequence):
    def __init__(self, name):
        super().__init__(name)
        self.byteorder = "little"

    async def body(self):
        for ad_size in range(32):
            for di_size in range(32):
                seq_cls = AsconRefEncSeq
                seq = seq_cls.create(f"{self.get_name()}.op_item")
                assert isinstance(seq, seq_cls)
                seq.ad_size = ad_size
                seq.di_size = di_size
                seq.byteorder = self.byteorder
                await seq.start(self.sequencer)
