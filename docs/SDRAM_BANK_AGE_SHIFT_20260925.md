# SDRAM bank-age shift encoding

`rtl/sdram.sv` uses the per-bank age only to decide whether the five-cycle tRAS minimum has elapsed. The previous three-bit saturating count fed several `>= 5` comparators, including the critical `bank_age[0][1] -> chip` path (−0.697 ns in the routed 15a1449 fit). The new five-bit shift token sets bit 4 after five open-bank `clk_ram` edges, so the control checks use that bit directly. ACT, PRECHARGE, init, and age-update priority stay unchanged; the shift array retains `ramstyle="logic"`.

An exhaustive per-bank transition check covered 25 legal transitions across 10 reachable age/row states, including tick, close, ACT/reopen, and init overriding concurrent state updates. The SDRAM chip-model test passed 174 checks with no protocol errors. The posted/non-posted memory-path modes, the dedicated `tb_memory_path_registered_first_miss` bench (64 integrated sequential reads plus 2,048 mixed posted-write/read operations), and the DMA integration test also passed. Full logs, proof source, and the isolated map are retained under `scratch/sdram_age_shift_20260924/`.

Quartus 17.0.2 standalone bridge synthesis changed from 618 estimated ALMs/958 registers to 624/974 (+6 ALMs, +16 registers). The unchanged posted-write queue still maps to 488 MLAB bits in 61 MLAB cells; no M10K blocks were added. This area result and functional regressions do not establish a timing improvement. The first full fit on this candidate used seed 21 and took 15m20s total: placement used 39,193 actual ALMs, with 40,173 ALMs estimated needed (96%, 28,018 registers, 509/553 RAM blocks), but routing terminated for congestion after 4m58s. The wrapper exited 1; no fresh RBF was produced, and the older output RBF remained untouched. A single seed-28 retry is authorized with identical RTL, SDC, and feature assignments.


The first seed-28 retry crashed in Quartus analytical placement after reusing
synthesis. A fresh-database retry then ended with execution status 143 during
fitting, with no established cause and no terminal timing result. The current
`interim_mac_ageshift_s28detached` retry uses the same source `cd8da29`, seed,
and configuration with detached execution. As of 2026-09-25 03:52 UTC its
fitter was observed alive; no timing improvement is yet established. See the
[recovery checkpoint](../RESUME-fit-recovery-20260924.md) for process and archive
identities. The previously fitted source `15a1449` remains installed.

### Terminal seed-28 result

The detached clean retry later reached a terminal fitter failure; this supersedes the preceding in-progress checkpoint. Quartus placed the design, then terminated routing for congestion after 44m33s (router estimate: 48% average and 80% peak interconnect in the X45_Y23–X55_Y34 region). The fitter summary reports 39,342 ALMs used in final placement and 40,275 estimated ALMs needed, 4,184/4,191 LABs, 28,018 registers, and 509/553 RAM blocks. `Error (11802): Can't fit design in device`; fitter elapsed 50m07s and the wrapper elapsed 55m30s, exit 3. No successful route, STA, or timing improvement was measured. The wrapper recorded no fresh RBF; the existing output RBF remained SHA256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`. Tracked build inputs passed the source-after comparison. Full reports and logs are in `scratch/interim_mac_ageshift_s28detached_fit_20260924/`.

The earlier seed-28 attempt, which reused the synthesis database, ended in a Quartus fitter segment violation during placement/clustering after 1m56s, before fresh map/fit reports or an RBF. Its cause is unproven. The subsequent clean run was detached because a prior interactive session returned 143 without explanation; its generated partial database and marker were archived separately. No further fit retry is authorized by this experiment record.
