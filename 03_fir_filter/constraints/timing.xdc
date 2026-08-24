#===================================================================================================
# Project : FPGA Projects
# File    : timing.xdc
#
# Description:
#   Timing constraint for the 4-tap pipelined FIR filter.
#
#   Target clock frequency : 100 MHz
#   Clock period           : 10.000 ns
#
#===================================================================================================

#--------------------------------------------------
# Primary Clock
#--------------------------------------------------

create_clock -period 10.000 -name clk [get_ports clk]
