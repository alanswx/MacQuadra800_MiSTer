# CPU-clock path families for the 2x builds (66/33/99 and 60/30/90, both on
# general[2]): the 3000 worst register pairs as a summary only, for
# scripts/cpu/path_families.py to group by start and end register.
set cpu {emu|pll|pll_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk}
project_open MacQuadra800
create_timing_netlist
read_sdc
update_timing_netlist
file mkdir scratch
report_timing -setup -npaths 3000 -pairs_only -detail summary -from_clock $cpu -to_clock $cpu -file scratch/cpu_pairs3000.txt
report_timing -setup -npaths 100 -pairs_only -detail full_path -from_clock $cpu -to_clock $cpu -file scratch/dual_cpu_top100.txt
report_clock_fmax_summary -file scratch/dual_fmax.txt
project_close
