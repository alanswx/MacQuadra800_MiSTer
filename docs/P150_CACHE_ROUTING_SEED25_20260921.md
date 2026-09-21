# P150 seed25 routing retry

Retry P147 qualified cache with unchanged P109 core/P120 pipeline at seed25. P147 seed24 placed successfully but failed routing from congestion. FITTER_AGGRESSIVE_ROUTABILITY_OPTIMIZATION was already ALWAYS, so this is a placement-seed experiment, not a newly enabled routing option. No CPU/cache behavior change. Development CD-ROM/audio and Ethernet remain omitted.

Use `scripts/cpu/fit_cache_response_seed25.sh` in this checkout; archive `scratch/p150_routing_seed25_fit_20260921`. Pins all three source hashes, seed25 and aggressive routability; refuses another live Quartus flow or reused archive; freezes tracked HDL/config through reporting and archives only fresh artifacts. Hardware testing requires a fresh result and timing review. A second routing failure would strengthen the case for reducing congestion rather than repeated seed trials.

Launched from commit49cc347 under `q800-p150-routing-seed25-fit-20260921.service`: wrapper566373, build_only566412, Quartus shell566424, mapper566521. Root independently observed wrapper/shell/map live and initial source_check_before.exit0. Maintain the complete tracked-source freeze through wrapper termination.

Root live audit while fitter573359 remained active verified all157 tracked HDL/QSF/QIP/SDC files unchanged and no manifest additions/removals. The entire wrapper remains frozen until terminal. Prepared hardware protocol `scratch/p150_routing_seed25_fit_20260921/HARDWARE_PLAN.md` requires fresh current safe-off verification, reviewed archived artifact/hash, same disposable slot/config, five distinct all-ten one-iteration runs and fresh visible shutdown. It deliberately omits a disk hash while the loaded core owns the image. This plan does not indicate a completed fit or hardware run.
