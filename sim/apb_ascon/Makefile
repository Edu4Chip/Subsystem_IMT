# Makefile

ROOT_DIR = $(PWD)/../../src/sv
SRC_DIR = $(ROOT_DIR)/rtl
INC_DIR = $(ROOT_DIR)/include

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

# dump waveforms
ifeq ($(SIM), verilator)
	EXTRA_ARGS += --trace --trace-structs
endif

# sources
VERILOG_SOURCES += $(SRC_DIR)/ascon_pack.sv
VERILOG_SOURCES += $(SRC_DIR)/apb_registers.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon_fsm.sv
VERILOG_SOURCES += $(SRC_DIR)/ascon_wrapper.sv
VERILOG_SOURCES += $(SRC_DIR)/block_padding.sv
VERILOG_SOURCES += $(SRC_DIR)/block_trunc.sv
VERILOG_SOURCES += $(SRC_DIR)/counter.sv
VERILOG_SOURCES += $(SRC_DIR)/fifo.sv
VERILOG_SOURCES += $(SRC_DIR)/permutation.sv
VERILOG_SOURCES += $(SRC_DIR)/top_ascon.v
VERILOG_INCLUDE_DIRS += $(INC_DIR)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = top_ascon

# MODULE is the basename of the Python test file
MODULE = test_apb_ascon

# by default, test KAT vectors sampled randomly
TESTCASE ?= test_sample

# test parameters: generic
KAT_PATH ?=

# test parameters: test_sample
SAMPLE_SIZE ?=

# test parameters: test_vector
ID ?=

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
