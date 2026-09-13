# Operand extension request overlap fixture

Run against complete immutable AP RTL in a fresh output directory:

```
VASM=/tmp/wombat-vasm/vasmm68k_mot sh scripts/fixtures/operand_overlap/run.sh COMPLETE_AP_RTL NEW_OUTPUT baseline
VASM=/tmp/wombat-vasm/vasmm68k_mot sh scripts/fixtures/operand_overlap/run.sh COMPLETE_AP_RTL NEW_OUTPUT candidate
```

`source` and `destination` select assertions for the one-caller ablations.
The candidate argument means both ordinary operand callers overlap EA selection
with extension-request setup. It does not select or change any RTL.

The runner copies inputs into NEW_OUTPUT and refuses to overwrite existing
outputs. The ordinary test extends indexed_stage's 14 checks to 27, covering
all six extension mode forms, d16 source/destination, immediate ALU and bit
operations through EA setup, postincrement source dependency, both absolute-long
alignments, PC-relative extension bases, and the original full-format, indirect,
and banked-stack cases. Both ordinary and pending RF/ISP fallback runs are used.

A second program places extension words at page boundaries: d16 source at
0x1000, second absolute-long word at 0x2000, immediate-ALU destination extension
at 0x3000, indexed source at 0x4000, and PC-relative source at 0x5000. One-shot
instruction bus errors must produce format-7/vector-2 frames with the original
instruction PC, exact fault address, program function code and clear ATC bit.
The handler checks the source destination register and memory remain unchanged,
then RTE restarts the instruction. Each program runs with fast and varied bus
ready timing in the established program harness.

The read-only cycle probe checks bookkeeping at every eligible entry, including
pre-extension PC, x_ext preservation, extension length/return, and register
selection. It checks those registers remain stable on every CE-disabled edge
and reports resident/forwarded/waiting extension observations. The optional
pending-write probe forces only architecturally neutral writes, outside normal
regression/production builds. No test probe is instantiated in production RTL.

Initial baseline and two-caller candidate runs passed all programs/probes:
baseline core 16fc1cc1f7f7e4295cbacf6c5449f2aa485d72290f27d75a3af687a2c7c8c79e,
candidate core 75eb6faa4ab1cf8f6ede2c02cbf4122e02304fa7fb29776c322a70f634054c41.
The fixture is correctness evidence, not an FPGA timing or performance result.

The source-only ablation is selected for further gates; the two-caller and
destination-only variants remain experimental and unadopted. Source-only core
SHA256 is `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
Its complete RTL is `/tmp/cpu-ea-request-overlap.ZTs0sO/source-rtl`. The exact
accepted-to-source-only patch is
`docs/checkpoints/cpu-operand-source-overlap-experimental-20260912.patch`.

```
VASM=/tmp/wombat-vasm/vasmm68k_mot sh scripts/fixtures/operand_overlap/run.sh /tmp/cpu-ea-request-overlap.ZTs0sO/source-rtl /tmp/operand-source-fresh-output source
```

Source-only directed tests passed with actual exit zero in
`/tmp/cpu-ea-request-overlap.ZTs0sO/check-source/tb/build`: both architectural
programs in all three bus phases, CE/setup assertions, and pending RF/ISP
fallback. In source mode the probe checks accelerated source entry and legacy
destination entry. The coverage line's `candidate=0` means the two-caller flag
is disabled; the runner enables source-only assertions with `+overlap_source`.
