# P164 screen — 2026-09-21

P164 (chained non-final FMOVEM reads) was screened against the standard
Whetstone image with P151 cache and P120 pipeline. It returned exactly the
P162 result: 25,267,804 loop cycles and 25,268,432 returned cycles. No gain is
shown, so P164 remains unqualified and should not be promoted or included in
the next FPGA fit.

The run completed in `scratch/whetstone_full_p164_20260921`. This is a
differential performance screen only; no numerical or hardware claim follows
from it.
