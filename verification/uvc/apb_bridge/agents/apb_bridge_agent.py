from pyuvm import (
    ConfigDB,
    uvm_active_passive_enum,
    uvm_agent,
    uvm_sequencer,
)

from .apb_bridge_agent_cfg import APBBridgeAgentConfig
from .apb_bridge_driver import APBBridgeDriver


class APBBridgeAgent(uvm_agent):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: APBBridgeAgentConfig = None
        self.sequencer: uvm_sequencer = None
        self.driver: APBBridgeDriver = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")

        if self.cfg.is_active == uvm_active_passive_enum.UVM_ACTIVE:
            name = "driver"
            ConfigDB().set(self, name, "cfg", self.cfg)
            self.driver = APBBridgeDriver.create(name, self)

            self.sequencer = uvm_sequencer.create("sequencer", self)

    def connect_phase(self):
        if self.cfg.is_active == uvm_active_passive_enum.UVM_ACTIVE:
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)
