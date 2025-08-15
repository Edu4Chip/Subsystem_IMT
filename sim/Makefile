# -------------------------------------------------------------------------------
# NOT COCOTB ARGS
# -------------------------------------------------------------------------------

ROOT_DIR = $(shell pwd)/..

# Defining paths
SRC_DIR = $(ROOT_DIR)/src
FILELIST = $(SRC_DIR)/hdl-files.list

export PYTHONPATH := $(ROOT_DIR)/verification

# ------------------------------------------------------------------------------
# COCOTB ARGS
# ------------------------------------------------------------------------------

# Defaults
SIM ?= modelsim
TOPLEVEL_LANG ?= verilog

# Read Verilog source files from filelist.txt
VERILOG_SOURCES = $(addprefix $(SRC_DIR)/, $(shell cat $(FILELIST)))

# VERILOG_INCLUDE_DIRS += $(SRC_DIR)/include

# TOPLEVEL is the DUT instance
TOPLEVEL := ascon_top

# MODULE is the basename of the Python test file
MODULE   ?= tb.test_ascon

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
