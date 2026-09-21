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

## Expanded overlap matrix rejects the original P113 candidate

The root-authored `scratch/p113_posted_store_lookup_20260921/tb_cache_posted_read_matrix.sv`
warms both lines and tests 108 combinations: byte/word/long stores, four read
address relationships (same word, another word in the same line, another set,
and another tag in the same set), downstream delays 0/2/6, and no injection,
snoop, or snoop with CPU enable paused. An independent byte oracle checks the
read, RAM, cached store/guard words, and repeated reads. Each store must reach
RAM exactly once; reads must not acknowledge while the posted store is pending.

P112 passes all 108 cases (`pending=396 prepared=0`). Original P113 fails a
cached store/guard comparison. Logs are `tests_p112/post_matrix.log` and
`tests_p113/post_matrix.log`. The earlier `tb_posted_read.sv` report of 100
cases referred to inherited crossing-store tests plus only one extra cold
read overlap; it did not establish coverage of the new warm-cache path.
**Original P113 is rejected despite its workload speed gains.** P114 inherits
this issue and must not advance on those gains either.

Inspection identifies a likely cause: speculative data reads replace the RAM
outputs which an outstanding partial store still needs for its byte/word merge
at downstream acknowledgement. Isolated P113b in
`scratch/p113b_posted_store_snapshot_20260921/ap040_cache.v` captures the old word
on the first posted-store cycle and uses that snapshot for ordinary merges.
Directed tests and workload screening of this correction remain pending.
Production P112 inputs are unchanged while its FPGA build runs.

P113b directed checks pass: all108 overlap cases,396 pending/prepared-read
observations, existing snoop suite and100 crossing-store cases. Root inspected
all three logs under its scratch directory. The original P113 failure is a
byte store followed by another word in the same line, delay2, no injection:
cached word at0x5004 becomes0xd4xxxxxx instead of0xd4485562. This supports the
RAM-output lifetime diagnosis. P113b SHA256
b8a4feab3dd35b18411b2b25635b28580edb0de6f965f866d5efe3888c2c19be.
Unapplied `scripts/cpu/posted_store_lookup_snapshot.patch` preserves the
correction relative to P112. Workload reruns, broader integration and hardware
qualification are still pending.

Expanded matrix additionally enables same-cycle fast-store admission as well
as the registered posted acknowledgement path:216 cases pass on both P112
and P113b, with900 pending observations and0/900 prepared reads respectively.
Logs: tests_p112/post_matrix216.log and P113b/post_matrix216.log. Full workload
runs are still being monitored; an observation timeout is not a terminal
simulation result and no performance claim is made for P113b yet.
