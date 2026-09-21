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
