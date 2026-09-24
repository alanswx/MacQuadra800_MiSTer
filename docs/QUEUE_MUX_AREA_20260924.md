# Queue fill and rotate area screens

Independent prototypes against becb472, not promoted to production RTL.
Normal-feature fitting of the separate BRF banked mux continues unchanged.

The static line-fill patch (`scripts/cpu/line_fill_static.patch`) replaces
eight dynamically addressed queue writes with one write per fixed slot.
The original maps source offset i to slot (fill+i) modulo 8. For a fixed
slot the inverse is distance=(slot-fill) modulo 8, enabled if distance<n.
Since n is at most 8-tail, every enabled source tail+distance is within the
line; truncating its index to three bits cannot change a selected value.
The mapping is one-to-one because n never exceeds eight. Counts, fetch
requests, write ordering and later same-cycle overrides remain unchanged.

Exact original and replacement blocks passed 589,824 slot comparisons,
including held slots, over all fill/tail/count positions with 128 random
payloads. Replacing subtraction with addition fails the negative control.
Evidence: scratch/line_fill_static_20260924/{prepare.py,tb.sv,equivalence.log,
negative.log}. Full CPU regression and physical results remain pending.

The rotate patch (`scripts/cpu/rotate_concat.patch`) expresses rotl32 as
the upper half of ({value,value} << amount), replacing opposing shifts,
OR and a zero-count select. Only the used left-rotate function changes.
For each shift 0..31, every one-hot input and 1,024 random words passed:
33,792 comparisons. An off-by-one output slice fails the negative control.
Evidence: scratch/rotate_concat_20260924/{prepare.py,tb.sv,equivalence.log,
negative.log}. Quartus may already optimize the old form; area is unknown.

Luna owns independent CPU synthesis screens. Promote only measured useful
changes with CPU regression evidence, then check the full-feature fit and
timing; CPU-only savings do not predict full fitter utilization exactly.

Static line-fill synthesis completed Sep24 16:23:53: 28,853 ALMs and8,966
registers versus29,024 and8,966 in the identical becb472 CPU baseline.
Saving171 ALMs. RTL tree comparison confirms only ap040_core.v differs.
Reports: scratch/cpu_area/p_line_fill_static_sep24. Memory296,960 bits,
13 DSPs; no storage growth. Not yet promoted: combined BRF+line-fill
regression is assigned to Luna with explicit line-offer path counters,
because the basic CPU program bench does not exercise that sideband.
The real-cache six-kernel harness must exercise it and preserve BRF-only
cycle counts and oracle results before the combined candidate is fitted.

Combined BRF+static line-fill validation completed: full CPU self-tests and
all six fixture oracles/negative controls pass. Every cycle count matches
BRF-only. Each fixture's bound monitor sees nonzero fills and wrapped
writes (Sieve has1 wrap). Source and evidence:
scratch/brf_linefill_20260924/{tree,cpu_tests/run.log,suite,line_fill_cov.sv}.
This candidate remains scratch until the active fitter experiment ends.

Static line-fill is now promoted on top of BRF, after the failed fitter
setting experiment ended. Production core matches the tested combined
snapshot byte-for-byte. No extra cycles or feature cuts; combined physical
savings and timing still need a new fit.
