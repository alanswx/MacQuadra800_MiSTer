# P120 direct admission to an empty pipeline

UNQUALIFIED isolated candidate over P105 pipeline, screened with P109 core
and P113b cache. Does not include P116 displacement-load support or P117's
separate timing edit. Candidate
scratch/p120_empty_pipeline_admit_20260921/ap040_pipeline_integer.sv SHA256
41539493f5e0506e32af7dd46a7f14e1e22c5cb06e6410d1e29afcd82541df70.
Unapplied patch scripts/cpu/empty_pipeline_admit.patch.

When ID/EX/WB are all empty and there is no pending, completed or discarded
memory transaction, a supported valid input can decode directly into EX.
Reset, CE, flush and kill-younger guards remain. Input opcode/extension/PC
and decoded controls use the admission record; the redundant ID copy is
marked invalid. A populated pipeline and any retained transaction use the
existing ID path. This targets the startup clock paid at each pipeline entry
without expanding opcode support or changing the memory execution stage.

Original Whetstone/Dhrystone screens are pending. A gain would still require
extended integration, standalone pipeline admission/stream/backpressure/CE/
flush tests, precise IRQ and fault replay, partial-register/forwarding cases,
and a timing/area fit. The new admission mux may affect timing and area.
Production remains frozen for the P113b fit; no promotion is implied.
