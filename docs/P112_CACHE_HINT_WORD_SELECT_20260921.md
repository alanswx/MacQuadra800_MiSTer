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

## Qualified for timing evaluation

The selector check passes all8256cases. Original Whetstone remains29,048,277
loop cycles and Dhrystone121,404,444; root verified every captured output,
fixture/ROM/flags/latency and all non-cache sources against P109. Dhrystone's
independent derived end-state checker also passes. Artifacts under
scratch/whetstone_full_p112_20260921, scratch/dhrystone_full_p112_500m_20260921
and scratch/p112_cache_hint_word_select_20260921/select_check.

P109's whole wrapper is terminal and no Quartus process remains. The exact
screened cache is now applied to production for the next single seed23 fit;
the patch is historical/APPLIED. Core and pipeline remain P109/P105. This is
a timing experiment with unchanged simulated speed, not a measured speedup.
