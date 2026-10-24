# Design settings shared by every technology and mode (reference flow, TGT-6).
# VERILOG_FILES and VERILOG_INCLUDE_DIRS come from the generated config.mk.
export DESIGN_NAME = cva6
export SYNTH_HDL_FRONTEND = slang
export VERILOG_DEFINES += -D HPDCACHE_ASSERT_OFF
export SYNTH_MEMORY_MAX_BITS = 65536
export SYNTH_CANONICALIZE_TCL = $(CVA6_FLOW_DIR)/orfs/canonicalize.tcl
export SDC_FILE = $(CVA6_FLOW_DIR)/orfs/constraints.sdc
export CORE_UTILIZATION = 55
export CORE_MARGIN = 2
export SKIP_REPORT_METRICS = 0
