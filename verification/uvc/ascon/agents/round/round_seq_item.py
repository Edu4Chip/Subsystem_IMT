import vsc
from pyuvm import uvm_sequence_item


@vsc.randobj
class AsconRoundItem(uvm_sequence_item):
    def __init__(self, name):
        super().__init__(name)
        self.phase = vsc.bit_t(5)
        self.phase_name = ""
        self.round = vsc.bit_t(4)
        self.add_state = vsc.bit_t(320)
        self.sub_state = vsc.bit_t(320)
        self.diff_state = vsc.bit_t(320)

    def do_copy(self, rhs: "AsconRoundItem"):
        super().do_copy(rhs)
        self.phase = rhs.phase
        self.phase_name = rhs.phase_name
        self.round = rhs.round
        self.add_state = rhs.add_state
        self.sub_state = rhs.sub_state
        self.diff_state = rhs.diff_state

    def __eq__(self, value: "AsconRoundItem"):
        return (
            super().__eq__(value)
            and self.round == value.round
            and self.add_state == value.add_state
            and self.sub_state == value.sub_state
            and self.diff_state == value.diff_state
        )

    @staticmethod
    def to_str(value: int):
        s = []
        for i in range(5):
            s.append(f"S[{i}]=0x{value & 0xFFFFFFFFFFFFFFFF:016x}")
            value >>= 64
        return " ".join(s)

    def __xor__(self, rhs: "AsconRoundItem"):
        item = self.clone()
        item.add_state = item.add_state ^ rhs.add_state
        item.sub_state = item.sub_state ^ rhs.sub_state
        item.diff_state = item.diff_state ^ rhs.diff_state
        return item

    def __str__(self):
        args = ", ".join(
            [
                f"id=0x{self.get_transaction_id():08x}",
                f"name='{self.get_name()}'",
                f"phase=({self.phase_name}: {self.phase})",
                f"round={self.round}",
                f"add_state=({self.to_str(self.add_state)})",
                f"sub_state=({self.to_str(self.sub_state)})",
                f"diff_state=({self.to_str(self.diff_state)})",
            ]
        )
        return args

    def __repr__(self):
        cls_name = self.__class__.__name__
        return f"<{cls_name}(name='{self.get_name()}'), id=0x{self.get_transaction_id():08x}>"
