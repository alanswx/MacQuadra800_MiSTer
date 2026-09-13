# Indexed-EA stage directed tests

```sh
VASM=/tmp/wombat-vasm/vasmm68k_mot \
sh scripts/fixtures/indexed_stage/run.sh COMPLETE_AP_RTL /tmp/new-indexed-test
```

The wrapper creates an isolated tree and refuses an existing output path.
Run against accepted baseline and candidate with separate paths. It requires
Icarus Verilog and VASM; all three artificial memory timing phases are tested.

Fourteen architectural checks cover signed word and long/scaled indexes,
An and same base/index operands, register RAW, source postincrement affecting
an indexed destination, ISP/MSP/USP A7, PC-relative addressing, full-format
direct/suppressed displacement and pre/postindexed memory indirection.
Existing all11/corpus gates additionally cover illegal/full-format exceptions.

The second invocation explicitly enables a simulation-only no-op write to A0,
then ISP, precisely on an indexed-extension completion edge. The observer
requires the original S_EA_EXTW fallback on both edges. Architectural values
are unchanged, so the same assembly oracle must still pass. This forces only
the isolated directed run; production RTL and ordinary regressions have no
such injection. The script requires both injection markers and normal
completion, rejecting missing coverage or errors.

Candidate patch and reasoning are in
[the handoff](../../../docs/checkpoints/CPU_INDEXED_STAGE_HANDOFF_20260912.md).
The candidate is not automatically applied by this runner.
