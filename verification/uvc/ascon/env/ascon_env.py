from pyuvm import ConfigDB, uvm_env

from ..agents.core.core_agent import AsconCoreAgent
from ..agents.round.round_agent import AsconRoundAgent
from .ascon_env_cfg import AsconEnvConfig
from .result_scoreboard import ResultScoreboard
from .round_scoreboard import RoundScoreboard


class AsconEnv(uvm_env):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.cfg: AsconEnvConfig = None
        self.agent_core: AsconCoreAgent = None
        self.agent_round: AsconRoundAgent = None
        self.scoreboard_result: ResultScoreboard = None
        self.scoreboard_round: RoundScoreboard = None

    def build_phase(self):
        self.cfg = ConfigDB().get(self, "", "cfg")

        name = "agent_core"
        ConfigDB().set(self, name, "cfg", self.cfg.core_cfg)
        self.agent_core = AsconCoreAgent.create(name, self)

        if self.cfg.check_rounds:
            name = "agent_round"
            ConfigDB().set(self, name, "cfg", self.cfg.round_cfg)
            self.agent_round = AsconRoundAgent.create(name, self)

            name = "scoreboard_round"
            ConfigDB().set(self, name, "cfg", self.cfg.core_cfg)
            self.scoreboard_round = RoundScoreboard.create(name, self)
        else:
            name = "scoreboard_result"
            ConfigDB().set(self, name, "cfg", self.cfg.core_cfg)
            self.scoreboard_result = ResultScoreboard.create(name, self)

    def connect_phase(self):
        if self.cfg.check_rounds:
            self.agent_core.monitor_op.ap.connect(
                self.scoreboard_round.op_queue.analysis_export
            )
            self.agent_core.monitor_result.ap.connect(
                self.scoreboard_round.analysis_export
            )
            self.agent_round.monitor.ap.connect(
                self.scoreboard_round.round_queue.analysis_export
            )
        else:
            self.agent_core.monitor_op.ap.connect(
                self.scoreboard_result.op_queue.analysis_export
            )
            self.agent_core.monitor_result.ap.connect(
                self.scoreboard_result.analysis_export
            )
