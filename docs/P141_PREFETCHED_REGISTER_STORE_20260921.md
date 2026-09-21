# P141 prefetch-qualified register store

Unqualified isolated follow-up over P140, core SHA256 `29d6e2363edc4993be137ac632427199ac5efcea1daea719b9818ec66e54bbc9`, source `scratch/p141_prefetched_register_store_20260921/ap040_core.v`, patch `scripts/cpu/prefetched_register_store.patch`.

P140's Whetstone screen returns identical captures and unchanged non-core identities but takes 26,285,658 loop clocks versus P137's 26,243,771 (41,887 more). Root profile comparison finds 115,058 fewer S_EXEC clocks and 39,809 fewer S_MWR clocks, offset by more fetch (+67,257), immediate fetch (+49,815), decode (+42,127), and EA work. This suggests earlier data-port occupancy can disrupt instruction prefetch; the profile does not prove causality.

P141 requires epf_ready_pc2 before using P140's early register-store preparation. It retains the original S_EXEC path when the next two instruction words are not ready. Screen P120/P136 original workloads against both P137 and P140; no benefit or correctness claim yet. All prior store forwarding/flags/fault/side-effect and full integration gates remain required. Production HDL unchanged.
