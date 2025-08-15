from pyuvm import uvm_object

from ..agents.apb_bridge_agent_cfg import APBBridgeAgentConfig


class APBBridgeEnvConfig(uvm_object):
    def __init__(self, name):
        super().__init__(name)
        self.apb_bridge_cfg: APBBridgeAgentConfig = APBBridgeAgentConfig.create(
            "apb_bridge_agent_cfg"
        )
