from pyuvm import ConfigDB, uvm_active_passive_enum, uvm_agent

from .round_agent_cfg import AsconRoundAgentConfig
from .round_monitor import AsconRoundMonitor


class AsconRoundAgent(uvm_agent):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconRoundAgentConfig = None
        self.monitor: AsconRoundMonitor = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")
        assert self.cfg.is_active == uvm_active_passive_enum.UVM_PASSIVE, (
            "Active round agent not supported."
        )

        name = "monitor"
        ConfigDB().set(self, name, "cfg", self.cfg)
        self.monitor = AsconRoundMonitor.create(name, self)
