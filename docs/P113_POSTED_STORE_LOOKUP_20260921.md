# P113 prepare cache lookup while a posted store drains

Isolated cache candidate over P112, keeping P109 core/pipeline unchanged.
Production inputs remain frozen for the P112 fit. Candidate:
scratch/p113_posted_store_lookup_20260921/ap040_cache.v SHA256
2378da304f0de74599bdc6db5a76a5fa4fac3b8e6bfd6b34b6f10e96c3062e9f.
Unapplied patch scripts/cpu/posted_store_lookup.patch.

The P109 strcpy profile shows one PASS and one LOOK clock for nearly every
MOVE.B source read. The cache's tag port A remains on the preceding store's
row until that store drains, so the next read cannot use a prepared lookup.
P113 uses tag port B's otherwise-unused read output to prepare the hinted row
while port A serves the store. Invalidations keep priority on port B, and any
port write invalidates the corresponding prepared-tag qualification.

Data RAM reads may run during an ordinary posted C_PASS transfer, excluding
spanning/crossing stores and outstanding invalidation work. A simultaneous
cache-data write permits the prepared read only when its row differs from the
hinted row; same-row writes retain the conservative invalidation behavior.
The fast-hit data path uses the independent hinted tag read. Its request,
MMU permission/cacheability, error, snoop and C_IDLE acceptance guards remain.
No read acknowledges before the previous posted store leaves C_PASS.

Original workload performance/output screening is pending. This changes
cache behavior and needs directed same-row/different-row store-read, snoop,
invalidate, reset, CE-pause, MMU protection and error checks, plus integration
and boot evidence before qualification. Synthesis must also confirm the tag
memory remains a dual-port M10K with the expected latency and resource usage.

## Initial workload evidence

P112 -> P113 original Whetstone loop clocks29,048,277 ->28,747,437
(1.0357% fewer). Root verified byte-identical captured stack/globals/code,
fixture, ROM, flags, latency and all non-cache source hashes. Evidence:
scratch/whetstone_full_p113_20260921. This is a controlled-latency simulation,
not a hardware score, and the Whetstone independent numerical oracle remains
pending. Dhrystone and directed posted-store/coherence checks are assigned to
Luna. Candidate is not promoted; P112's whole FPGA wrapper remains active.

Original Dhrystone completes in120,954,440 loop clocks, compared with
P112's121,404,444 (0.3707% fewer). Luna reports independent end-state PASS
and all five captures identical. Directed cache/coherence qualification
remains pending; the gain alone does not qualify this cache change.

Root independently verified Dhrystone's five captures and all supporting
identities except the cache against P112. Existing standalone cache-snoop
and cross-store suites pass for P112 and P113 (cross-store100cases covering
posting, residency, byte lanes, set wrap, CE-frozen snoops and partial errors).
Evidence: tests_p112/{snoop,xstore}.log and tests_p113/{snoop,xstore}.log under
the P113 scratch directory. The initial attempts to run the entire CPU suite
exited127 because the assembler was absent from PATH; those logs are not
passing qualification. Standalone cache benches require no assembler.
The new directed ordinary posted-store/read overlap bench is still pending;
the existing suites do not prove all of its new acceptance/validity cases.
