from cocotb.triggers import RisingEdge
from pyuvm import ConfigDB, uvm_analysis_port, uvm_component

from .core_agent_cfg import AsconCoreAgentConfig
from .core_seq_item import AsconCoreOpItem, AsconCoreResultItem


class AsconCoreBaseMonitor(uvm_component):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconCoreAgentConfig = None
        self.ap: uvm_analysis_port = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")
        self.ap = uvm_analysis_port("ap", self)

    async def read_stream(self, size, read_block) -> int:
        stream = b""
        for _ in range(0, size, self.cfg.rate):
            stream += await read_block()
        return int.from_bytes(stream, byteorder=self.cfg.byteorder)


class AsconCoreOpMonitor(AsconCoreBaseMonitor):
    async def read_input_block(self) -> bytes:
        vif = self.cfg.vif
        while not vif.is_di_accepted():
            await RisingEdge(vif.clk)
        block = vif.data_i.value.integer
        await RisingEdge(vif.clk)
        return int.to_bytes(block, length=self.cfg.rate, byteorder=self.cfg.byteorder)

    async def run_phase(self):
        vif = self.cfg.vif

        while True:
            # Detect the start of a computation
            await RisingEdge(vif.start_i)
            item = AsconCoreOpItem.create("op_item")
            assert isinstance(item, AsconCoreOpItem)

            # Read settings
            item.delay = vif.delay_i.value.integer
            item.decrypt = vif.decrypt_i.value.integer
            item.ad_size = vif.ad_size_i.value.integer
            item.di_size = vif.di_size_i.value.integer
            item.key = vif.key_i.value.integer
            item.nonce = vif.nonce_i.value.integer

            # Read AD
            item.ad = await self.read_stream(item.ad_size, self.read_input_block)

            # Read DI
            item.di = await self.read_stream(item.di_size, self.read_input_block)

            self.logger.info(f"[**] {item!s}")
            self.logger.debug(f"[=>] {item!r}")
            self.ap.write(item)


class AsconCoreResultMonitor(AsconCoreBaseMonitor):
    async def read_output_block(self) -> bytes:
        vif = self.cfg.vif
        while not vif.is_do_written():
            await RisingEdge(vif.clk)
        block = vif.data_o.value.integer
        await RisingEdge(vif.clk)
        return int.to_bytes(block, length=self.cfg.rate, byteorder=self.cfg.byteorder)

    async def run_phase(self):
        vif = self.cfg.vif

        while True:
            # Detect the start of a computation
            await RisingEdge(vif.start_i)

            item = AsconCoreResultItem.create("result_item")
            assert isinstance(item, AsconCoreResultItem)

            # Read settings
            item.do_size = vif.di_size_i.value.integer

            # Read DO
            item.do = await self.read_stream(item.do_size, self.read_output_block)

            # Read tag
            while not vif.is_tag_valid():
                await RisingEdge(vif.clk)
            item.tag = vif.tag_o.value.integer

            self.logger.info(f"[**] {item!s}")
            self.logger.debug(f"[=>] {item!r}")
            self.ap.write(item)
