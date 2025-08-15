from pyuvm import (
    ConfigDB,
    uvm_active_passive_enum,
    uvm_agent,
    uvm_sequencer,
)

from .core_agent_cfg import AsconCoreAgentConfig
from .core_driver import AsconCoreDriver
from .core_monitor import AsconCoreOpMonitor, AsconCoreResultMonitor


class AsconCoreAgent(uvm_agent):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconCoreAgentConfig = None
        self.sequencer: uvm_sequencer = None
        self.driver: AsconCoreDriver = None
        self.monitor_op: AsconCoreOpMonitor = None
        self.monitor_result: AsconCoreResultMonitor = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")

        name = "monitor_op"
        ConfigDB().set(self, name, "cfg", self.cfg)
        self.monitor_op = AsconCoreOpMonitor.create(name, self)

        name = "monitor_result"
        ConfigDB().set(self, name, "cfg", self.cfg)
        self.monitor_result = AsconCoreResultMonitor.create(name, self)

        if self.cfg.is_active == uvm_active_passive_enum.UVM_ACTIVE:
            name = "driver"
            ConfigDB().set(self, name, "cfg", self.cfg)
            self.driver = AsconCoreDriver.create(name, self)

            self.sequencer = uvm_sequencer.create("sequencer", self)

    def connect_phase(self):
        if self.cfg.is_active == uvm_active_passive_enum.UVM_ACTIVE:
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
