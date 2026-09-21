# P131 ordinary data lookup acknowledgement

Isolated, unqualified experiment over P124, with explicit P109 core and P120 pipeline. Cache SHA256 af6a5f02bfd44b7feebf74212f2673edc24f406163d610387350082da7f8337e, source `scratch/p131_data_lookup_ack_20260921/ap040_cache.v`, unapplied patch `scripts/cpu/data_lookup_ack.patch`.

The hinted C_IDLE data fast path already returns immediately. Ordinary non-spanning data hits that reach C_LOOK still register their acknowledgement for the next cycle. P131 acknowledges the settled lookup word in C_LOOK and suppresses the duplicate registered acknowledgement. It excludes instruction, spanning and crossing transactions and retains request/read, hit, snoop and error guards. Data selection uses registered transaction state; accepted data must remain unchanged.

Original Whetstone/Dhrystone screens are queued against P120/P124 (27,949,845 and 114,804,374 loop cycles respectively). No gain is claimed yet. If useful, qualification needs exact-once and no-gap reads, actual new-path coverage, same-row snoops at admission/lookup/CE pause, partial accesses, errors, ordinary cache/store matrices, full CPU/IRQ regressions and FPGA timing/area before hardware use.

P129 scope correction: the hot normal memory-to-memory MOVE acknowledgement already starts the destination EA in S_MRD. Its new S_PIPE_SDONE bypass targets remaining buffered/split or unsupported destination paths. Whetstone's completed screen is unchanged at 27,949,845 loop / 27,950,495 returned cycles; Dhrystone and output audit remain pending. Do not infer a gain from the hot opcode frequency alone.

First original workload result: Whetstone 27,631,544 loop / 27,632,194 returned cycles, saving 318,301 loop cycles (1.13884%) versus P120/P124. Root verified all three output captures and every non-cache identity field. Dhrystone remains live; this result alone does not qualify the cache or establish hardware speed.

Dhrystone screen completed: 112,804,309 loop / 112,805,195 returned, saving 2,000,065 loop cycles (1.74215%). Root verified all five Dhrystone captures and all non-cache identity fields, then ran the independent 50,000-iteration checker successfully. Original Whetstone and Dhrystone screens therefore both preserve their checked outputs. Full integration and directed data-snoop/acknowledgement qualification remain in progress; no production promotion or hardware result yet.

Root audited full integration at `scratch/p131_full_integration_20260921`: all 22 program and four IRQ/replay cases pass, HANDOFF accounting holds, the reference trace matches exactly and all recorded source hashes match. Each IRQ case has three injections; store/PEA each commit exactly three stores. Targeted data-cache acknowledgement/snoop tests remain pending.
