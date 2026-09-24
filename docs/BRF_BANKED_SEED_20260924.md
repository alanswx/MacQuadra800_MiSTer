# Branch refill seed mux experiment

Status: scratch prototype, not promoted. CPU source baseline b421ab7;
normal-feature integration baseline becb472. Patch:
`scripts/cpu/brf_banked_seed.patch`.

The eight output halfwords are consecutive addresses within the 32-halfword
branch-refill sector. Instead of eight independent 32-way selects, select
one halfword from each of eight lanes (four rows per lane), then rotate
the eight lane outputs. A lane below the starting lane uses the next row;
row and lane arithmetic wrap exactly like the old five-bit sector index.
No added state, register stage, queue write or change to enable/count rules.

Standalone RTL comparison: 128 random sectors, all 32 starting addresses,
counts 0 through 8, 147456 selected-word comparisons passed. A planted
less-than-or-equal wrap condition fails immediately. Evidence:
`scratch/brf_banked_20260924/{tb.sv,equivalence.log,negative.log}`.
This tests data selection, not the entire CPU or physical timing.

Luna is running CPU and integer kernel regressions on a separate snapshot.
CPU-only baseline and candidate synthesis are running sequentially via
`scratch/measure_brf_area_20260924.sh`, separate from the active full Mac fit.
Their source trees are frozen. No area saving or performance benefit is
claimed before reading fresh results; compiler sharing may erase the gain.
Full-design fitting and timing remain required before hardware.

Controlled CPU synthesis completed Sep24 16:14:54:

| Variant | Estimated ALMs | Registers |
| --- | ---: | ---: |
| becb472 baseline | 29,024 | 8,966 |
| Banked BRF seed mux only | 27,879 | 8,966 |

Saving: 1,145 ALMs (3.9% of CPU estimate). Both flows exited0. Source-tree
comparison finds only ap040_core.v differs; generated QSFs differ only in
snapshot paths. No extra registers or inferred latches were reported.
Reports: scratch/cpu_area/p_brf_{base,banked}_sep24. This CPU-only experiment
uses its own synthesis settings; do not subtract the saving from full
fitter utilization as a prediction. Full CPU regression and full-feature
fit/timing remain required. The normal full-feature baseline failed at
43,806 / 41,910 ALMs, a 1,896-ALM deficit.
