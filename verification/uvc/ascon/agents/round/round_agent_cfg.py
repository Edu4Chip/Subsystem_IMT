from dataclasses import dataclass
from typing import Dict, Set

from pyuvm import uvm_active_passive_enum, uvm_object

from .round_if import (
    AsconCtrlInterface,
    AsconPermutationInterface,
    AsconRoundUnitInterface,
)


@dataclass
class AsconRoundPhaseInfo:
    value: int
    name: str
    is_active: bool


class AsconRoundAgentConfig(uvm_object):
    def __init__(self, name):
        super().__init__(name)
        self.vif_round_unit: AsconRoundUnitInterface = None
        self.vif_ctrl: AsconCtrlInterface = None
        self.vif_permutation: AsconPermutationInterface = None
        self.is_active = uvm_active_passive_enum.UVM_PASSIVE
        self._phase_names: Dict[int, str] = {}
        self._active_phases: Set[str] = set()

    def get_phase_info(self, phase: int) -> AsconRoundPhaseInfo:
        name = self._phase_names.get(phase, "Unknown")
        is_active = name in self._active_phases
        return AsconRoundPhaseInfo(phase, name, is_active)

    def set_phase_names(self, *names: str):
        self._phase_names.clear()
        self._phase_names.update(enumerate(names))

    def set_active_phases(self, *names):
        self._active_phases.clear()
        self._active_phases.update(names)
