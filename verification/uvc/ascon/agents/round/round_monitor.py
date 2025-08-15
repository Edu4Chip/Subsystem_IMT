from enum import Enum

from cocotb.triggers import RisingEdge
from pyuvm import ConfigDB, uvm_analysis_port, uvm_component

from .round_agent_cfg import AsconRoundAgentConfig
from .round_seq_item import AsconRoundItem


class AsconRoundMonitorState(Enum):
    IDLE = 0
    READING = 1


class AsconRoundMonitor(uvm_component):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconRoundAgentConfig = None
        self.ap: uvm_analysis_port = None
        self.state: AsconRoundMonitorState = AsconRoundMonitorState.IDLE

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")
        self.ap = uvm_analysis_port("ap", self)

    def write_round(self):
        vif = self.cfg.vif_permutation
        phase = self.cfg.get_phase_info(self.cfg.vif_ctrl.phase_s.value)
        if phase.is_active:
            item = AsconRoundItem.create("round_item")
            assert isinstance(item, AsconRoundItem)
            item.phase = phase.value
            item.phase_name = phase.name
            item.round = self.cfg.vif_round_unit.round_i.value.integer
            item.add_state = vif.add_state_s.value.integer
            item.sub_state = vif.sub_state_s.value.integer
            item.diff_state = vif.diff_state_s.value.integer
            self.logger.info(f"[**] {item!s}")
            self.logger.debug(f"[=>] {item!r}")
            self.ap.write(item)

    async def run_phase(self):
        vif = self.cfg.vif_round_unit

        while True:
            if self.state == AsconRoundMonitorState.IDLE:
                if vif.is_enable_set():
                    self.state = AsconRoundMonitorState.READING
                    self.write_round()
            elif self.state == AsconRoundMonitorState.READING:
                self.write_round()
                if vif.is_enable_clear():
                    self.state = AsconRoundMonitorState.IDLE
            await RisingEdge(vif.clk)
