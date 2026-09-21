# P114 cached read completion during a posted store

UNTESTED isolated follow-up over P113, not production. Candidate
scratch/p114_cached_read_during_post_20260921/ap040_cache.v SHA256
70729a5abe7b4e96779e8a85c05d96c67e1d9dc6a3565275885463561be7f610.
Unapplied patch scripts/cpu/cached_read_during_post.patch depends on P113.

P113 prepares a lookup during a posted store but accepts it only in C_IDLE.
P114 additionally permits the existing fast data-read hit in ordinary posted
C_PASS, only when the prepared hint's set differs from the store's set. All
MMU hint qualification, data/tag validity, snoop, error and invalidation gates
remain. It routes such acknowledgements to fast_data instead of the pass bus's
m_rdata. No miss or uncacheable read uses this path. Same-set reads remain
serialized, even when their physical tags differ.

This explicitly changes P113's no-read-ack-while-post-active rule. P113 tests
must retain that assertion; P114 needs a separate acceptance contract and must
not be made to pass by weakening P113 checks. Before qualification, verify
allowed cached read values/acknowledgement counts and forbidden same-set,
MMIO, miss and invalidation cases; check consecutive reads while the posted
write stalls, CE pauses, snoops, CINV/reset and eventual exactly-once store
completion. The host-qualified posting contract excludes architectural write
faults; unexpected downstream errors still need defensive testing. Ordering
relative to subsequent memory requests must be reviewed in the full wrapper.
No performance result, simulation qualification, fit or hardware test yet.

## P114b rebase onto the corrected store snapshot

Original P114 inherits P113's partial-store corruption and is not qualified.
P114b instead builds on P113b's saved merge word. Isolated candidate
scratch/p114b_cached_read_during_post_20260921/ap040_cache.v SHA256
c52f0ed3ca36edadfbdcb08a4d5799a6614225be5c06336f3c8d2f142b3797e8.
Unapplied patch scripts/cpu/cached_read_during_post_snapshot.patch depends
on P113b, not the rejected original P113.

Its separate warm-cache216-case bench passes, observing15 early read
acknowledgements. The bench permits those only for the independently selected
other-set address0x5014; same-word, same-line and same-set/different-tag reads
must still wait. It checks oracle data, cached guard bytes, exactly-once RAM
writes, latency0/2/6, byte/word/long stores, both posted admission paths,
snoops and CE pauses. Root inspected p114b.log. Original P113b's strict
no-early-ack matrix is unchanged. This is initial coverage, not full
qualification: consecutive reads, uncached/MMIO/miss/error/invalidation
contracts and full-wrapper checks remain outstanding. Workload screening
is running separately; production remains frozen for the live P112 fit.
