from pyuvm import ConfigDB, uvm_env

from ..agents.apb_bridge_agent import APBBridgeAgent
from .apb_bridge_env_cfg import APBBridgeEnvConfig


class APBBridgeEnv(uvm_env):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: APBBridgeEnvConfig = None
        self.apb_bridge_agent: APBBridgeAgent = None

    def build_phase(self):
        super().build_phase()
        self.cfg = ConfigDB().get(self, "", "cfg")

        name = "apb_bridge_agent"
        ConfigDB().set(self, name, "cfg", self.cfg.apb_bridge_cfg)
        self.apb_bridge_agent = APBBridgeAgent.create(name, self)
