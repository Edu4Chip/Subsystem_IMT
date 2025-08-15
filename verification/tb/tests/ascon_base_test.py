import logging
import os
import re
from datetime import datetime

import cocotb
import vsc
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from pyuvm import ConfigDB, uvm_active_passive_enum, uvm_sequencer, uvm_test
from uvc.apb.agents.apb_common import DriverType
from uvc.apb.agents.cl_apb_interface import cl_apb_interface, signal_placeholder
from uvc.apb.env import APBEnv, APBEnvConfig
from uvc.apb_bridge.env import APBBridgeEnv, APBBridgeEnvConfig
from uvc.ascon.agents.core import AsconCoreInterface
from uvc.ascon.env import AsconEnv, AsconEnvConfig


class AsconBaseTest(uvm_test):
    def __init__(self, name, parent):
        super().__init__(name, parent)
        self.dut = None
        self.ascon_env: AsconEnv = None
        self.apb_env: APBEnv = None
        self.apb_bridge_env: APBBridgeEnv = None
        self.clk_gen_100MHz: Clock = None
        self.sequencer: uvm_sequencer = None

    def end_of_elaboration_phase(self):
        # set log level
        log_level_name = os.getenv("LOG_LEVEL", "INFO")
        log_level = getattr(logging, log_level_name)
        self.set_logging_level_hier(log_level)

        # Set log file
        filename_stem = re.sub(r"(?<!^)(?=[A-Z])", "_", self.__class__.__name__).lower()
        current_date = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        filename = f"{current_date}_{filename_stem}.log"
        filename = os.getenv("LOGFILE", filename)
        file_handler = logging.FileHandler(filename, mode="w")
        self.add_logging_handler_hier(file_handler)

    def build_phase(self):
        self.dut = cocotb.top
        self.clk_gen_100MHz = Clock(self.dut.clk, 10, "ns")

        # Configure bridge
        env_cfg_cls = APBBridgeEnvConfig
        bridge_cfg = env_cfg_cls.create("apb_bridge_env_cfg")
        assert isinstance(bridge_cfg, env_cfg_cls)
        bridge_cfg.apb_bridge_cfg.is_active = uvm_active_passive_enum.UVM_ACTIVE

        name = "apb_bridge_env"
        ConfigDB().set(self, name, "cfg", bridge_cfg)
        self.apb_bridge_env = APBBridgeEnv.create(name, self)

        # Configure Ascon environment
        env_cfg_cls = AsconEnvConfig
        cfg = env_cfg_cls.create("ascon_env_cfg")
        assert isinstance(cfg, env_cfg_cls)

        cfg.core_cfg.is_active = uvm_active_passive_enum.UVM_PASSIVE
        cfg.core_cfg.byteorder = "little"
        cfg.core_cfg.rate = 16
        cfg.check_rounds = False
        cfg.core_cfg.vif = AsconCoreInterface.from_dut(self.dut.u_ascon_core)

        name = "ascon_env"
        ConfigDB().set(self, name, "cfg", cfg)
        self.ascon_env = AsconEnv.create(name, self)
        bridge_cfg.apb_bridge_cfg.core_cfg = cfg.core_cfg

        # Configure APB environment
        env_cfg_cls = APBEnvConfig
        cfg = env_cfg_cls.create("apb_env_cfg")
        assert isinstance(cfg, env_cfg_cls)

        cfg.apb_cfg.is_active = uvm_active_passive_enum.UVM_ACTIVE
        cfg.apb_cfg.driver = DriverType.PRODUCER
        cfg.apb_cfg.create_default_coverage = True
        cfg.apb_cfg.enable_masked_data = False
        cfg.apb_cfg.set_width_parameters(
            addr_width=int(cocotb.top.APB_AW),
            data_width=int(cocotb.top.APB_DW),
        )
        apb_if = cl_apb_interface(self.dut.clk, self.dut.rst_n)
        apb_if._set_width_parameters(
            cfg.apb_cfg.ADDR_WIDTH,
            cfg.apb_cfg.DATA_WIDTH,
        )
        apb_if.connect(
            wr_signal=self.dut.PWRITE,
            sel_signal=self.dut.PSEL,
            enable_signal=self.dut.PENABLE,
            addr_signal=self.dut.PADDR,
            wdata_signal=self.dut.PWDATA,
            strb_signal=signal_placeholder("strb"),
            rdata_signal=self.dut.PRDATA,
            ready_signal=self.dut.PREADY,
            slverr_signal=self.dut.PSLVERR,
        )
        cfg.apb_cfg.vif = apb_if
        bridge_cfg.apb_bridge_cfg.apb_cfg = cfg.apb_cfg

        name = "apb_env"
        ConfigDB().set(self, name, "cfg", cfg)
        self.apb_env = APBEnv.create(name, self)

    def connect_phase(self):
        self.apb_bridge_env.apb_bridge_agent.driver.apb_seqr = (
            self.apb_env.apb_agent.sequencer
        )
        self.sequencer = self.apb_bridge_env.apb_bridge_agent.sequencer

    def start_clock(self):
        cocotb.start_soon(self.clk_gen_100MHz.start())

    async def reset_system(self):
        self.logger.info("[..] Reset system.")
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 10)
        self.logger.info("[OK] Reset system.")

    def report_phase(self):
        super().report_phase()

        # Writing coverage report in txt-format
        f = open(f"sim_build/{self.get_type_name()}_cov.txt", "w")
        f.write(f"Coverage report for {self.get_type_name()} \n")
        f.write("------------------------------------------------\n \n")
        vsc.report_coverage(fp=f, details=True)
        f.close()

        # Writing coverage report in xml-format
        vsc.write_coverage_db(f"sim_build/{self.get_type_name()}_cov.xml")
