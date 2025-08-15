from cocotb.triggers import RisingEdge
from pyuvm import ConfigDB, uvm_driver

from .core_agent_cfg import AsconCoreAgentConfig
from .core_seq_item import AsconCoreOpItem


class AsconCoreDriver(uvm_driver):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconCoreAgentConfig = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")

    async def write_block(self, block):
        vif = self.cfg.vif
        vif.data_i.value = block
        vif.valid_i.value = 1
        await RisingEdge(vif.clk)
        while not vif.is_di_ready():
            await RisingEdge(vif.clk)
        vif.valid_i.value = 0

    async def run_phase(self):
        while True:
            req = await self.seq_item_port.get_next_item()
            assert isinstance(req, AsconCoreOpItem)
            self.logger.info(f"[RQ] {req!s}")
            self.logger.debug(f"[<=] {req!r}")

            # Creates clone of seq item
            rsp = req.clone()
            # Set the transaction ID
            rsp.set_id_info(req)
            # Set the response ID
            rsp.set_context(req)

            vif = self.cfg.vif

            # Stop previous computation
            vif.start_i.value = 0
            while vif.is_busy():
                await RisingEdge(vif.clk)

            # Setup parameters
            vif.delay_i.value = req.delay
            vif.ad_size_i.value = req.ad_size
            vif.di_size_i.value = req.di_size
            vif.key_i.value = req.key
            vif.nonce_i.value = req.nonce
            vif.decrypt_i.value = req.decrypt

            # Start computation
            vif.start_i.value = 1
            await RisingEdge(vif.clk)
            while not vif.is_busy():
                await RisingEdge(vif.clk)

            # Write ad
            for block in req.iter_ad_blocks(
                rate=self.cfg.rate,
                byteorder=self.cfg.byteorder,
            ):
                await self.write_block(block)

            # Write di
            for block in req.iter_di_blocks(
                rate=self.cfg.rate,
                byteorder=self.cfg.byteorder,
            ):
                await self.write_block(block)

            # Wait for completion
            while not vif.is_done():
                await RisingEdge(vif.clk)

            # Stop computation
            vif.start_i.value = 0
            while vif.is_busy():
                await RisingEdge(vif.clk)

            self.logger.info(f"[RP] {rsp!s}")
            self.logger.debug(f"[=>] {rsp!r}")
            self.seq_item_port.item_done(rsp)
