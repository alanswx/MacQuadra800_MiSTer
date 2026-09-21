# P150 seed25 routing retry

Retry P147 qualified cache with unchanged P109 core/P120 pipeline at seed25. P147 seed24 placed successfully but failed routing from congestion. FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION was already ALWAYS, so this is a placement-seed experiment, not a newly enabled routing option. No CPU/cache behavior change. Development CD-ROM/audio and Ethernet remain omitted.

Use `scripts/cpu/fit_cache_response_seed25.sh` in this checkout; archive `scratch/p150_routing_seed25_fit_20260921`. Pins all three source hashes, seed25 and aggressive routability; refuses another live Quartus flow or reused archive; freezes tracked HDL/config through reporting and archives only fresh artifacts. Hardware testing requires a fresh result and timing review. A second routing failure would strengthen the case for reducing congestion rather than repeated seed trials.
