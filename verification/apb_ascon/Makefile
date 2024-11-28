# Makefile

ROOT_DIR = $(PWD)/../../src/sv
SRC_DIR = $(ROOT_DIR)/rtl

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
# dump waveforms
EXTRA_ARGS += --trace --trace-structs
# disable warnings due to the Ascon state representation
EXTRA_ARGS += --Wno-ASCRANGE

VERILOG_SOURCES += $(SRC_DIR)/ascon_pack.sv
VERILOG_SOURCES += $(SRC_DIR)/top_ascon.v
VERILOG_SOURCES += $(SRC_DIR)/apb_registers.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon_wrapper.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon_fsm.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon.sv
VERILOG_SOURCES += $(SRC_DIR)/permutation.sv
VERILOG_SOURCES += $(SRC_DIR)/block_padding.sv
VERILOG_SOURCES += $(SRC_DIR)/block_trunc.sv
VERILOG_SOURCES += $(SRC_DIR)/counter.sv
VERILOG_SOURCES += $(SRC_DIR)/fifo.sv

VERILOG_INCLUDE_DIRS += $(ROOT_DIR)/include

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = top_ascon

# MODULE is the basename of the Python test file
MODULE = test_apb_ascon
# by default, test a single KAT vector
TESTCASE ?= test_single
SAMPLE_COUNT ?=
AD_SIZE ?= 
PT_SIZE ?= 
SAMPLE_SIZE ?= 
PROG_DELAY ?= 0

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
