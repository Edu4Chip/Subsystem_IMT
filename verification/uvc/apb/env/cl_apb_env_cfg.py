from pyuvm import uvm_object

from ..agents.cl_apb_config import cl_apb_config


class cl_apb_env_cfg(uvm_object):
    def __init__(self, name):
        super().__init__(name)

        # Handle to APB configuration
        self.apb_cfg: cl_apb_config = cl_apb_config.create("apb_cfg")
