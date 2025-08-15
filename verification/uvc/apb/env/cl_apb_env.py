from pyuvm import *

from ..agents.cl_apb_agent import cl_apb_agent
from .cl_apb_env_cfg import cl_apb_env_cfg


class cl_apb_env(uvm_env):
    def __init__(self, name, parent):
        super().__init__(name, parent)

        # Configuration object handle
        self.cfg: cl_apb_env_cfg = None

        # APB UVC
        self.apb_agent: cl_apb_agent = None

    def build_phase(self):
        super().build_phase()

        # Get the configuration object
        self.cfg = ConfigDB().get(self, "", "cfg")

        # Instantiate the APB UVC and pass handle to cfg
        name = "apb_agent"
        ConfigDB().set(self, name, "cfg", self.cfg.apb_cfg)
        self.apb_agent = cl_apb_agent(name, self)
