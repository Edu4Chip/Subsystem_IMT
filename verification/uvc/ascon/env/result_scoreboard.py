from pyuvm import ConfigDB, uvm_subscriber, uvm_tlm_analysis_fifo

from ..agents.core.core_agent_cfg import AsconCoreAgentConfig
from ..agents.core.core_seq_item import AsconCoreOpItem, AsconCoreResultItem
from ..utils.ascon_model import AsconModel


class ResultScoreboard(uvm_subscriber):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconCoreAgentConfig = None
        self.op_queue: uvm_tlm_analysis_fifo = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")
        self.op_queue = uvm_tlm_analysis_fifo("op_queue", self)

    def write(self, tt):
        assert isinstance(tt, AsconCoreResultItem)
        self.logger.info(f"[..] Check {tt!s}.")
        self.logger.debug(f"[<=] {tt!r}.")

        available_op, op = self.op_queue.try_get()
        assert available_op, f"FAILED: {tt!r}, missing op."
        assert isinstance(op, AsconCoreOpItem)
        self.logger.debug(f"[<=] {op!r}.")

        # Compute expected result
        key = int.to_bytes(op.key, length=16, byteorder=self.cfg.byteorder)
        nonce = int.to_bytes(op.nonce, length=16, byteorder=self.cfg.byteorder)
        ad = int.to_bytes(op.ad, length=op.ad_size, byteorder=self.cfg.byteorder)
        di = int.to_bytes(op.di, length=op.di_size, byteorder=self.cfg.byteorder)

        with AsconModel() as model:
            if op.decrypt == 0:
                do, tag = model.ascon_encrypt(key, nonce, ad, di)
            else:
                do, tag = model.ascon_decrypt(key, nonce, ad, di)

        # Check result
        tt_exp = tt.clone()
        tt_exp.do = int.from_bytes(do, byteorder=self.cfg.byteorder)
        tt_exp.do_size = len(do)
        tt_exp.tag = int.from_bytes(tag, byteorder=self.cfg.byteorder)

        assert tt == tt_exp, (
            f"FAILED: {tt!r}, tt != tt_exp.\n"
            f"+ where:\n"
            f"+     tt: {tt!s}\n"
            f"+ tt_exp: {tt_exp!s}"
        )
        self.logger.info(f"[OK] Check {tt!s}.")
