# P112 cache hint word selection timing experiment

Isolated over P109 core with the original production cache (not P111).
Candidate scratch/p112_cache_hint_word_select_20260921/ap040_cache.v SHA256
a32d35894f3c4b866678a0e255512b1745cb12782a60377bdf2c43bebba26cb2.
Unapplied patch scripts/cpu/cache_hint_word_select.patch.

P109's worst CPU path traverses the late tag match, priority-encoded way,
way-plus-word-offset adder, then data selection and pipeline flags/branch
refill. P112 prepares four rotated word views using only the registered word
offset, then selects them with priority-qualified tag hits. It preserves the
original priority and no-hit default. Acknowledgements, tags, cache state,
permissions, invalidations and memory ordering are unchanged.

check_cache_hint_select.py extracts the candidate's actual mux declarations
and checks16hitpatterns,4wordoffsets and129zero/single-bit data bases against
the original priority-way-plus-offset selection. Since selection is bitwise,
these8256cases cover each data input bit under every selector combination.
The check and original-workload screens are pending; they must be cycle- and
output-identical to P109. No timing improvement is claimed until a new fit.
