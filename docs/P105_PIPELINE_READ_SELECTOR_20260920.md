# P105 registered pipeline register selector

P104 fit complete: 39,542 ALMs, 25,691 registers, 482 RAM, 42 DSP.
CPU -1.019 ns (TNS -41.624), HDMI -.269, RAM +.141. All archive checks
completed. No hardware deployment. Worst path ex_opcode[14] -> instruction
classification -> register-file selector -> effective address -> ALU flags
-> branch/refill selection -> epf_data[7][9], 27 levels, 30.636 ns data.

P105 computes and registers the four-bit port-B selector at ID-to-EX transfer.
It substitutes ID operands for the exact old EX expression. Reset is zero;
the selector advances under the same enable as ex_opcode/ex_extension/ex_dst
and ex_pea, so stalls, CE pauses and flushes preserve the relationship.
No additional instruction cycles or changed architectural ordering intended.
Timing improvement remains unproven until fitting.

Candidate and patch are isolated under scratch/p105_pipeline_read_selector_20260920.
Production remains P104. Both Whetstone and integration runners accept an
isolated --pipeline-module. Luna owns Whet/integration/first-100 corpus tests;
results pending. Do not weaken comparison identity checks for changed pipeline;
explicitly verify only that module differs when comparing with P104.

Original P104 full guest booted Finder/Game Sprocket but had only wait/shot/quit
commands; it never launched Speedometer. Lack of benchmark evidence was an
operator omission, not a demonstrated CPU failure. Luna owns a fresh disposable
retry under scratch/p104_fullguest_retry_20260920 with screenshot verification.
No new hardware result; best P96 median remains 1.211, goal 1.8 unmet.

## Qualification completed and candidate promoted

Luna completed all three gates with exit 0. Whetstone loop 30,236,820 and
returned 30,237,470 cycles exactly match P104. Captured stack/globals/code
are byte-identical; supporting source hashes and fixture/ROM/flags match,
with only the intended pipeline module changed. This is differential evidence,
not an independent Whetstone numerical oracle.

Extended real-core integration passed including all IRQ/replay gates.
First-100 corpus: 1,900 field groups match, zero differences, 28,528,316 cycles;
artifacts /tmp/cpu-corpus100-gate.lCDKmE. This is not the full corpus.
Evidence: scratch/p105_pipeline_read_selector_20260920/qualification_summary.txt
and integration.log; Whetstone artifacts scratch/whetstone_full_p105_20260920.

The exact qualified module SHA256
9b0e3e00e544e05c29c9b46611a1d2cad9f5aaba144b58d753d889ac22786dbc
is now applied to production. scripts/cpu/pipeline_read_selector.patch is
historical/applied. Luna will launch the next fit after this commit is pushed;
freeze all build inputs through its full wrapper/archive/timing sequence.
No hardware performance or timing improvement is yet claimed.

First retry of fullguest was invalid: the operator used too-short boot waits
and incorrect navigation. Root has constrained the next retry to ONLY
wait 1200000000 and shot, no keys/quit, awaiting root screenshot review.
