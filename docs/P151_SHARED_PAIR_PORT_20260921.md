# P151 shared cache write/read port experiment

Unqualified scratch cache over P147: `scratch/p151_shared_pair_port_20260921/ap040_cache.v`, SHA256 `b8e59ae3ee53141a4709fa9a3bd4a41db80fffbe9d0b1e450b834049382a8836`; patch `scripts/cpu/shared_pair_port.patch`. Production remains frozen for P150 seed25.

P147 routing failed at96%ALMs/502RAMblocks. This experiment removes the mirrored paired-read arrays and shares each primary bank's write port with the paired lookup. Writes retain priority; a registered validity flag disables fast paired acknowledgements following a write collision until a clean paired read occurs. Ordinary word/line reads keep the independent port. Existing slow span paths handle unavailable pair data.

The intended benefit is less RAM duplication and routing fanout, with possible extra cycles after write collisions. Actual block-RAM inference, area and timing are unproven until a future Quartus run; never start one beside P150. First require cache data/control/snoop/error/CE/no-gap tests, original workload captures/cycles, then full CPU integration. No speed, fit or correctness claim yet.

Original Whetstone screen: 26,395,651 loop / 26,396,279 returned cycles versus P147 26,243,771 / 26,244,399: 151,880 additional cycles (0.579%). Root verified all three captures, all non-cache identity fields and all source hashes (`scratch/whetstone_full_p151_20260921/root_audit.txt`). This is a performance regression accepted only for further investigation of potential RAM/routing savings; actual inference and fit remain unproven. Broader cache/CPU qualification remains pending.

Root reviewed clean Icache/snoop coverage (20requests/20acks, I-SNOOP/I-CINV/data-snoop windows/CE pause), XSTORE100cases and posted-read216cases logs. Compiled vvp files name the P151 cache; its live hash matches the preserved candidate. Evidence `scratch/p151_shared_pair_port_20260921/root_additional_cache_audit.txt`; these runs do not have a contemporaneous full source-hash manifest, so that is not claimed. Full CPU integration and original Dhrystone are running separately.

Full P109/P120/P151 CPU integration independently audited by root:22programs and4IRQ/replay cases pass, handoff accounting balances, exact oracle trace matches and all recorded source hashes verify (`scratch/p151_full_integration_20260921/root_audit.txt`). Original Dhrystone remains pending. RAM inference/area/routing still require a future exclusive Quartus flow after P150 ends.
