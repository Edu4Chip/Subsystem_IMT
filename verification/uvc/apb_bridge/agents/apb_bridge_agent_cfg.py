from pyuvm import uvm_active_passive_enum, uvm_object
from uvc.apb.agents.cl_apb_config import cl_apb_config
from uvc.ascon.agents.core.core_agent_cfg import AsconCoreAgentConfig


class APBBridgeAgentConfig(uvm_object):
    def __init__(self, name):
        super().__init__(name)
        self.core_cfg: AsconCoreAgentConfig = AsconCoreAgentConfig.create("ascon_cfg")
        self.apb_cfg: cl_apb_config = cl_apb_config.create("apb_cfg")
        self.is_active: uvm_active_passive_enum = uvm_active_passive_enum.UVM_ACTIVE
