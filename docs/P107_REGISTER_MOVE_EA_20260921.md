# P107 register-source MOVE store at completed EA

Isolated candidate over production P105, independent of P106.
Unapplied patch: scripts/cpu/register_move_ea_store.patch.
Candidate: scratch/p107_register_move_ea_20260921/ap040_core.v.

Extend the existing S_PIPE_DEA MOVE store path and its store hint to SK_REG.
S_PIPE_START captures the source in src_val before destination EA completion;
the fallback S_PIPE_SREG does the same. At S_PIPE_DEA the ALU uses src_val,
so MOVE can update flags and call the existing ordered mwr path there, just
as memory/immediate sources already do, instead of spending S_EXEC.
Read-modify-write operations and write-suppressed operations remain excluded.
Destination address updates and exception rollback remain in the EA engine.

Whetstone screening: 30,236,820 -> 30,226,369 loop clocks (0.0346% fewer),
with identical stack/globals/code captures. This is too small a Whetstone
benefit to prioritize for the next fit; other benchmark effects are unknown.
Dedicated pipeline_stores and pipeline_store_fault cases passed.
The --stores --force-decode handoff wrapper stopped at an exception accounting
assertion. An identical P105 baseline run reproduces the same counts:
entries=1518, commits=1515, cancelled=0, stores=420, although architectural
checks report ALL TESTS PASSED. No assertion was weakened. This particular
wrapper run is not a passing broad qualification gate for either candidate.
Artifacts: scratch/whetstone_full_p107_20260921/comparison.json and
scratch/p105_store_tests_20260921. P107 remains unpromoted.
No production RTL changes, fit or hardware qualification.
