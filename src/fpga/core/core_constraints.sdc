#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#
# PLL outputs (derive_pll_clocks in apf_constraints.sdc creates them):
#   general[0]  clk_sys     28.375 MHz
#   general[1]  clk_sys_90  28.375 MHz, 90 degrees (APF video only)
#
# clk_74a <-> clk_sys crossings all go through synchronisers, or (the
# cartridge buffer and its size) are only read while the bridge side is
# idle, so the domains are treated as asynchronous.

set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group [get_clocks {ic|mp1|altera_pll_i|*general[0]*}] \
 -group [get_clocks {ic|mp1|altera_pll_i|*general[1]*}]
