class AsconCoreInterface:
    @classmethod
    def from_dut(cls, dut) -> "AsconCoreInterface":
        return AsconCoreInterface(
            clk=dut.clk,
            rst_n=dut.rst_n,
            start_i=dut.start_i,
            decrypt_i=dut.decrypt_i,
            ad_size_i=dut.ad_size_i,
            di_size_i=dut.di_size_i,
            delay_i=dut.delay_i,
            key_i=dut.key_i,
            nonce_i=dut.nonce_i,
            idle_o=dut.idle_o,
            done_o=dut.done_o,
            valid_i=dut.data_valid_i,
            data_i=dut.data_i,
            ready_o=dut.data_ready_o,
            data_o=dut.data_o,
            valid_o=dut.data_valid_o,
            tag_o=dut.tag_o,
            tag_valid_o=dut.tag_valid_o,
        )

    def __init__(
        self,
        clk,
        rst_n,
        start_i,
        decrypt_i,
        ad_size_i,
        di_size_i,
        delay_i,
        key_i,
        nonce_i,
        idle_o,
        done_o,
        valid_i,
        data_i,
        ready_o,
        data_o,
        valid_o,
        tag_o,
        tag_valid_o,
    ):
        self.clk = clk
        self.rst_n = rst_n
        self.start_i = start_i
        self.decrypt_i = decrypt_i
        self.ad_size_i = ad_size_i
        self.di_size_i = di_size_i
        self.delay_i = delay_i
        self.key_i = key_i
        self.nonce_i = nonce_i
        self.idle_o = idle_o
        self.done_o = done_o
        self.valid_i = valid_i
        self.data_i = data_i
        self.ready_o = ready_o
        self.data_o = data_o
        self.valid_o = valid_o
        self.tag_o = tag_o
        self.tag_valid_o = tag_valid_o

    def reset_signals(self):
        self.start_i.value = 0
        self.decrypt_i.value = 0
        self.ad_size_i.value = 0
        self.di_size_i.value = 0
        self.delay_i.value = 0
        self.key_i.value = 0
        self.nonce_i.value = 0
        self.valid_i.value = 0
        self.data_i.value = 0

    def is_busy(self) -> bool:
        return self.idle_o.value.binstr == "0"

    def is_done(self) -> bool:
        return self.done_o.value.binstr == "1"

    def is_di_ready(self) -> bool:
        return self.ready_o.value.binstr == "1"

    def is_di_accepted(self) -> bool:
        return self.ready_o.value.binstr == "1" and self.valid_i.value.binstr == "1"

    def is_do_written(self) -> bool:
        return self.valid_o.value.binstr == "1"

    def is_tag_valid(self) -> bool:
        return self.tag_valid_o.value.binstr == "1"
