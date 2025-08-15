from pyuvm import ConfigDB, uvm_subscriber, uvm_tlm_analysis_fifo

from ..agents.core.core_agent_cfg import AsconCoreAgentConfig
from ..agents.core.core_seq_item import AsconCoreOpItem, AsconCoreResultItem
from ..agents.round.round_seq_item import AsconRoundItem
from ..utils.ascon_model import AsconModel


class RoundScoreboard(uvm_subscriber):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconCoreAgentConfig = None
        self.op_queue: uvm_tlm_analysis_fifo = None
        self.round_queue: uvm_tlm_analysis_fifo = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")
        self.op_queue = uvm_tlm_analysis_fifo("op_queue", self)
        self.round_queue = uvm_tlm_analysis_fifo("state_queue", self)

    def write(self, tt):
        assert isinstance(tt, AsconCoreResultItem)
        self.logger.info(f"[..] Check {tt!r}.")
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
                model.ascon_encrypt(key, nonce, ad, di)
            else:
                model.ascon_decrypt(key, nonce, ad, di)
            rounds = model.get_rounds()

        # Check states
        s_tt_prev = None
        for r in rounds:
            s_available, s_tt = self.round_queue.try_get()
            assert s_available, (
                "FAILED: missing round.\n",
                f"+ index={r.index}\n",
                f"+ round={r.round}",
            )
            self.logger.info(f"[..] Check {s_tt!r}.")
            self.logger.debug(f"[<=] {s_tt!r}")
            assert isinstance(s_tt, AsconRoundItem)
            s_tt_exp = s_tt.clone()
            s_tt_exp.round = r.round
            s_tt_exp.add_state = r.add_state
            s_tt_exp.sub_state = r.sub_state
            s_tt_exp.diff_state = r.diff_state
            if s_tt_prev is not None:
                assert s_tt == s_tt_exp, (
                    f"FAILED: {s_tt!r}, state != exp_state.\n",
                    "+ where:\n",
                    f"+     state: {s_tt!s}\n",
                    f"+ exp_state: {s_tt_exp!s}\n",
                    f"+      diff: {s_tt ^ s_tt_exp!s}\n",
                    f"+ prev_diff: {s_tt_prev ^ s_tt!s}",
                )
            else:
                assert s_tt == s_tt_exp, (
                    f"FAILED: {s_tt!r}, state != exp_state.\n",
                    "+ where:\n",
                    f"+     state: {s_tt!s}\n",
                    f"+ exp_state: {s_tt_exp!s}\n",
                    f"+      diff: {s_tt ^ s_tt_exp!s}\n",
                )
            self.logger.info(f"[OK] Check {s_tt!r}.")
            s_tt_prev = s_tt
        self.logger.info(f"[OK] Check {tt!r}.")
