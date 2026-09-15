# Trimmed hardware validation and combined-CPU retry

## Trimmed source-only build

Tree: `/tmp/MacQuadra800_features_seed24.UNORIQ/trim`.
CPU SHA256: `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
RBF SHA256: `9aba3ebf973312b0b3313c1c553cadd0cb04a98ab209a935cb1c2e990c8836dd`.
Build log: `output_files/build_20260913_132841.log`; actual exit 0.

Full fitting succeeded: 36,538 ALMs, 4,061/4,191 LABs, 23,046 registers,
459 RAM blocks, 3,435,654 memory bits and 31 DSP blocks. Versus the accepted
CD-off source-only fit, this saves 1,465 fitted ALMs and increases free LABs
from 98 to 130. This is implementation headroom, not a CPU speed result.
All reported TNS values are zero; minimum setup slack +0.542 ns, hold +0.213 ns.
Quartus still warns that the design is not fully constrained. Successful
reported timing does not prove unconstrained paths meet requirements.

## Hardware gate

User requested Luna validate this RBF and collect Speedometer 4.02 results
before retrying the combined CPU build. Use all ten CPU Mix tests, one
iteration, three independently started sets; baseline 0.458/0.459/0.459,
mean 0.458666667. Follow the completion-modal and 135-second quiet-interval
rules in `AGENT_TESTING_WORKFLOW.md`.

Evidence directory: `scratch/perf_features_seed24_20260913`.
Unique target: `/media/fat/_Unstable/MacQuadra800_features_seed24_20260913.rbf`.
The initial handoff incorrectly named `_Computer`; the lifecycle guard
rejected that path before deployment. Corrected the handoff, not the guard.
Hardware results and post-test Menu/disposable restoration remain pending.

## Subsequent build gate

After reviewing hardware validation, retry the preserved combined CPU
`21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`
with the identical trimmed profile and seed 24 in a separate build tree.
Its correctness gates are recorded in `CPU_OVERLAP_FOLLOWUP_20260913.md`;
the untrimmed seed-24 routing failure and seed-25 unexpected fitter exit
do not establish a result for this trimmed retry. Do not modify the accepted
CPU or claim a combined hardware improvement before fitting and testing it.
