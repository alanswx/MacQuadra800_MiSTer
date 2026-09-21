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
