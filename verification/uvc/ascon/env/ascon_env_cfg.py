from pyuvm import uvm_object

from ..agents.core.core_agent_cfg import AsconCoreAgentConfig
from ..agents.round.round_agent_cfg import AsconRoundAgentConfig


class AsconEnvConfig(uvm_object):
    def __init__(self, name):
        super().__init__(name)
        self.core_cfg: AsconCoreAgentConfig = AsconCoreAgentConfig.create(
            "cfg_agent_core"
        )
        self.round_cfg: AsconRoundAgentConfig = AsconRoundAgentConfig.create(
            "cfg_agent_round"
        )
        self.check_rounds: bool = False
