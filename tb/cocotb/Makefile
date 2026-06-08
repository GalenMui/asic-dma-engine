SIM ?= icarus
TOPLEVEL_LANG = verilog

RTL_DIR := $(abspath ../../rtl)

VERILOG_SOURCES = \
	$(RTL_DIR)/dma_pkg.sv \
	$(RTL_DIR)/axi_lite_regs.sv \
	$(RTL_DIR)/dma_core.sv \
	$(RTL_DIR)/dma_top.sv

TOPLEVEL ?= dma_top
MODULE ?= test_dma_smoke

EXTRA_ARGS += -g2012

include $(shell cocotb-config --makefiles)/Makefile.sim
