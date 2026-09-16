project_open MacQuadra800
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 12 -detail summary -to_clock {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -file worst_paths.txt
report_timing -setup -npaths 3 -detail path_only -to_clock {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -file worst_detail.txt
project_close
