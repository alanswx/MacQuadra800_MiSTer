# P126 instruction and spanning-read acknowledgements

UNQUALIFIED isolated composition of P122 instruction-hit acknowledgement with P124 spanning data-read acknowledgement, using P109 core and P120 pipeline. No production RTL changes. Source scratch/p126_combined_lookup_ack_20260921/ap040_cache.v SHA256 f7b3e4f12aaaf71e68f63265e0b9cb2197e75949751ca6d24816296893c6b81e. Patch scripts/cpu/combined_lookup_ack.patch applies to the P124 cache.

The acknowledgement OR and read-data selector include the disjoint instruction and spanning-data paths. Each path retains its original eligibility and duplicate-registered-ack suppression. Original workload screens must compare with the P120/P124 combination, not the older P113b baseline. No additive gain is assumed.

If the screen gains cycles and preserves outputs, qualification still requires both instruction early-ack branches, spanning exact-once/no-gap tests, targeted instruction-line snoop overlap at admission/lookup/CE pause, ordinary cache/store regressions, full integration and FPGA timing/area. P122's global data-snoop counts did not establish the targeted instruction-snoop coverage. Hardware speed remains unproven.
