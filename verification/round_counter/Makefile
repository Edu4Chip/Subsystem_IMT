# Makefile

ROOT_DIR = $(PWD)/../../src/sv
SRC_DIR = $(ROOT_DIR)/rtl

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog
# dump waveforms
EXTRA_ARGS += --trace --trace-structs

VERILOG_SOURCES += $(SRC_DIR)/round_counter.sv

VERILOG_INCLUDE_DIRS += $(ROOT_DIR)/include

# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = round_counter

# MODULE is the basename of the Python test file
MODULE = test_round_counter

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
