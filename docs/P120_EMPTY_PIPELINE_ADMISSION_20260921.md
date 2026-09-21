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

Performance screens are recorded below. Promotion still requires
extended integration, standalone pipeline admission/stream/backpressure/CE/
flush tests, precise IRQ and fault replay, partial-register/forwarding cases,
and a timing/area fit. The new admission mux may affect timing and area.
P113b fitting has completed; P120 remains isolated and unpromoted.

Initial performance screens: Whetstone unchanged28,747,437 loop/28,748,087
return. Dhrystone improves120,954,440 ->119,854,443 loop clocks (0.9094%),
return119,855,331. Root verified all3/5 captures and non-pipeline identities
against P113b; independent Dhrystone checker passes. Logs under
scratch/{whetstone,dhrystone}_full_p120_20260921. Baseline Whetstone has no
S_EXPERIMENT_PIPE cycles, so its unchanged result does not exercise this
optimization. Extended integration and standalone admission coverage remain
pending; the gain alone does not qualify promotion.

Root integration audit (2026-09-21): selected source hashes match P120/P109/P113b; architectural trace matches the independent oracle; all 22 program logs pass with entries = commits + cancelled. Four interrupt/replay groups each exercise three injections, with 3/6 killed instructions and exactly three stores in the store/PEA tests. Evidence: scratch/p120_integration_20260921/{identity.json,root_audit.txt,*log}. The standalone prerequisite hardcoded the default P105 pipeline, so its six modes and mutation controls do not qualify P120. Candidate-specific standalone testing is being rerun with an explicit module override. No timing or hardware result exists for P120.

Candidate-specific standalone rerun completed: scratch/p120_prototype_override_20260921/results.json records the P120 hash. All six modes match 14,720 independent architectural snapshots per mode; both data and address forwarding mutation controls are rejected. The runner now accepts --pipeline-module for the candidate compile and both mutations. Numeric direct-admission coverage and dedicated boundary checks remain pending.

Admission boundary qualification completed: scratch/p120_admission_20260921/boundaries.log passes an independently checked MOVEQ retirement. A valid input on an empty pipeline cannot change ID/EX/WB under CE-off, flush or kill-younger; unsupported ILLEGAL enters the ordinary fallback without EX admission; retirement backpressure holds the expected PC/data and produces exactly one retirement when released. No internal signals are forced. Reproducible bench: scripts/cpu/tb_pipeline_admission_boundaries.sv (candidate-only direct_admit observation). Six monitored oracle modes record direct admissions 1/1/2/2/2/1; mode 1 includes 2,542 disabled-CE cycles. Pending-memory replay is covered by the real-core load/store/PEA IRQ and fault tests rather than this integer-only boundary bench.

P120 is qualified for an isolated FPGA fit with P109 core/P113b cache. P117 and P122 remain separate. The current P122 integration must finish before production pipeline source changes, because its later IRQ compiles still refer to the current production file.

P122 integration is terminal and root-audited. Promoted the exact P120 pipeline hash for the next FPGA fit, retaining P109 core and P113b cache. The unapplied-patch description above is historical; empty_pipeline_admit.patch is now applied. No FPGA result or hardware speedup is claimed yet.

Fit launched from commit a102f76 as q800-p120-empty-pipeline-admit-fit-20260921.service. Root confirmed wrapper PID 182559 and quartus_sh PID 182583 live. Archive: scratch/p120_empty_pipeline_admit_fit_20260921. Tracked HDL/QSF/QIP/SDC are frozen through terminal wrapper completion. No result yet.
