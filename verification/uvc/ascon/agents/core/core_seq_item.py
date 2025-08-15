import vsc
from pyuvm import uvm_sequence_item


@vsc.randobj
class AsconCoreOpItem(uvm_sequence_item):
    max_stream_size = 2048

    @classmethod
    def iter_blocks(cls, value: int, size: int, rate: int, byteorder: str):
        buf = int.to_bytes(value, length=cls.max_stream_size // 8, byteorder=byteorder)
        buf = buf[:size]
        for i in range(0, size, rate):
            yield int.from_bytes(buf[i : i + rate], byteorder=byteorder)

    def __init__(self, name):
        super().__init__(name)
        self.delay = vsc.rand_bit_t(16)
        self.decrypt = vsc.bit_t(1)
        self.ad_size = vsc.bit_t(8)
        self.di_size = vsc.bit_t(8)
        self.key = vsc.rand_bit_t(128)
        self.nonce = vsc.rand_bit_t(128)
        self.ad = vsc.bit_t(self.max_stream_size)
        self.di = vsc.bit_t(self.max_stream_size)

    def iter_ad_blocks(self, rate: int, byteorder: str):
        yield from self.iter_blocks(self.ad, self.ad_size, rate, byteorder)

    def iter_di_blocks(self, rate: int, byteorder: str):
        yield from self.iter_blocks(self.di, self.di_size, rate, byteorder)

    @vsc.constraint
    def c_delay(self):
        self.delay < 16

    def do_copy(self, rhs: "AsconCoreOpItem"):
        super().do_copy(rhs)
        self.delay = rhs.delay
        self.decrypt = rhs.decrypt
        self.ad_size = rhs.ad_size
        self.di_size = rhs.di_size
        self.key = rhs.key
        self.nonce = rhs.nonce
        self.ad = rhs.ad
        self.di = rhs.di

    def __eq__(self, value: "AsconCoreOpItem"):
        return (
            super().__eq__(value)
            and self.delay == value.delay
            and self.decrypt == value.decrypt
            and self.ad_size == value.ad_size
            and self.di_size == value.di_size
            and self.key == value.key
            and self.nonce == value.nonce
            and self.ad == value.ad
            and self.di == value.di
        )

    def __str__(self):
        args = ", ".join(
            [
                f"id=0x{self.get_transaction_id():08x}",
                f"name='{self.get_name()}'",
                f"delay={self.delay}",
                f"decrypt={self.decrypt}",
                f"ad_size={self.ad_size}",
                f"di_size={self.di_size}",
                f"key=0x{self.key:032x}",
                f"nonce=0x{self.nonce:032x}",
                f"ad=0x{self.ad:0{2 * self.ad_size}x}",
                f"di=0x{self.di:0{2 * self.di_size}x}",
            ]
        )
        return args

    def __repr__(self):
        cls_name = self.__class__.__name__
        return f"<{cls_name}(name='{self.get_name()}'), id=0x{self.get_transaction_id():08x}>"


class AsconCoreResultItem(uvm_sequence_item):
    def __init__(self, name):
        super().__init__(name)
        self.do_size = vsc.bit_t(8)
        self.do = vsc.bit_t(2048)
        self.tag = vsc.bit_t(128)

    def do_copy(self, rhs: "AsconCoreResultItem"):
        super().do_copy(rhs)
        self.do_size = rhs.do_size
        self.do = rhs.do
        self.tag = rhs.tag

    def __eq__(self, value: "AsconCoreResultItem"):
        return (
            super().__eq__(value)
            and self.do == value.do
            and self.tag == value.tag
            and self.do_size == value.do_size
        )

    def __str__(self):
        args = ", ".join(
            [
                f"id=0x{self.get_transaction_id():08x}",
                f"name='{self.get_name()}'",
                f"do_size={self.do_size}",
                f"do=0x{self.do:0{2 * self.do_size}x}",
                f"tag=0x{self.tag:032x}",
            ]
        )
        return args

    def __repr__(self):
        cls_name = self.__class__.__name__
        return f"<{cls_name}(name='{self.get_name()}'), id=0x{self.get_transaction_id():08x}>"
