from pyuvm import ConfigDB, uvm_driver, uvm_sequencer
from uvc.ascon.agents.core.core_seq_item import AsconCoreOpItem

from ..sequences.ascon_apb_seq import AsconAPBOpSeq
from .apb_bridge_agent_cfg import APBBridgeAgentConfig


class APBBridgeDriver(uvm_driver):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: APBBridgeAgentConfig = None
        self.apb_seqr: uvm_sequencer = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")

    async def run_phase(self):
        assert self.apb_seqr is not None, "Missing APB sequencer."
        while True:
            op = await self.seq_item_port.get_next_item()
            assert isinstance(op, AsconCoreOpItem)
            self.logger.info(f"[RQ] {op!s}")
            self.logger.debug(f"[<=] {op!r}")
            seq_name, *_ = op.get_name().rsplit(".")
            seq = AsconAPBOpSeq.create(seq_name)
            assert isinstance(seq, AsconAPBOpSeq)
            seq.op.do_copy(op)
            seq.rate = self.cfg.core_cfg.rate
            seq.byteorder = self.cfg.core_cfg.byteorder
            seq.set_apb_width(self.cfg.apb_cfg.DATA_WIDTH)
            await seq.start(self.apb_seqr)
            self.seq_item_port.item_done()
