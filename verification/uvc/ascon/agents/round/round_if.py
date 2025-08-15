class AsconRoundUnitInterface:
    @classmethod
    def from_dut(cls, dut) -> "AsconRoundUnitInterface":
        return AsconRoundUnitInterface(
            clk=dut.clk,
            rst_n=dut.rst_n,
            en_i=dut.en_i,
            round_i=dut.round_i,
        )

    def __init__(
        self,
        clk,
        rst_n,
        en_i,
        round_i,
    ):
        self.clk = clk
        self.rst_n = rst_n
        self.en_i = en_i
        self.round_i = round_i

    def is_enable_set(self):
        return self.en_i.value.binstr == "1"

    def is_enable_clear(self):
        return self.en_i.value.binstr == "0"


class AsconCtrlInterface:
    @classmethod
    def from_dut(cls, dut) -> "AsconCtrlInterface":
        return AsconCtrlInterface(
            clk=dut.clk,
            rst_n=dut.rst_n,
            phase_s=dut.phase_q,
        )

    def __init__(
        self,
        clk,
        rst_n,
        phase_s,
    ):
        self.clk = clk
        self.rst_n = rst_n
        self.phase_s = phase_s


class AsconPermutationInterface:
    @classmethod
    def from_dut(cls, dut) -> "AsconPermutationInterface":
        return AsconPermutationInterface(
            add_state_s=dut.state_add_s,
            sub_state_s=dut.state_sub_s,
            diff_state_s=dut.state_diff_s,
        )

    def __init__(
        self,
        add_state_s,
        sub_state_s,
        diff_state_s,
    ):
        self.add_state_s = add_state_s
        self.sub_state_s = sub_state_s
        self.diff_state_s = diff_state_s
