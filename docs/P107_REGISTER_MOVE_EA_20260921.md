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

Whetstone screening and directed register-store correctness gates pending.
No production RTL changes, fit or hardware qualification.
