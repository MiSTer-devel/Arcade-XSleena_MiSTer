derive_pll_clocks
derive_clock_uncertainty

# core specific constraints
#set_multicycle_path -from {emu|sdram|*} -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -start -setup 2
#set_multicycle_path -from {emu|sdram|*} -to [get_clocks {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}] -start -hold 1
