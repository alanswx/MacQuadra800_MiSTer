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
