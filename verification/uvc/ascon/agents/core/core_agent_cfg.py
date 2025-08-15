from pyuvm import uvm_active_passive_enum, uvm_object

from .core_if import AsconCoreInterface


class AsconCoreAgentConfig(uvm_object):
    def __init__(self, name):
        super().__init__(name)
        self.vif: AsconCoreInterface = None
        self.is_active: uvm_active_passive_enum = uvm_active_passive_enum.UVM_PASSIVE
        self.rate: int = 16
        self.byteorder: str = "little"
