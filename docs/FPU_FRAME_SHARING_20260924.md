# FPU frame sharing area experiments

Two independent scratch prototypes against b421ab7 (same CPU source as
normal-feature baseline becb472). Neither is installed in production RTL.

- `scripts/cpu/frestore_shared.patch` normalizes BUSY and UNIMP payload
  indices to share restore-field decoding. It retains the separate frame
  counters, memory reads, BUSY-only fields and final architectural commit.
- `scripts/cpu/fsave_shared.patch` shares the save payload mux and its call
  site across BUSY and UNIMP frames. No memory operation or cycle is removed.

Luna reports that both pass `t_fpu_frames` and `t_fpu_resume`, phases 0/1/2,
for revision 41. The restore variant also passes both fixtures for revision
40. Evidence lives under `scratch/interim_fsave_shared_decode_20260924/`:
`run`, `save_mux_run`, and the revision-40 run logs. These checks cover
format errors, copied frames, payload mappings, pointer adjustment,
ET15/FPT15, deferred exceptions and resume behavior. They do not inject a
bus error during a partial payload transfer. Architectural restore still
commits at the final FRESTORE strobe; that statement is source inspection,
not an injected-fault test result.

The save mux now returns zero for unreachable UNIMP indices above the
valid frame length where the old function defaulted to ETEMP low. Compare
reachable frame words when checking equivalence, and verify counter bounds
before promotion.

Area is unmeasured. Shared decode introduces index arithmetic and muxing;
shorter source does not establish smaller logic. Separate CPU synthesis
experiments will screen both against the frozen becb472 baseline before
considering full-design fitting. Timing and hardware remain untested.

FSAVE-only CPU synthesis result:29,063 ALMs/8,966 registers,39 ALMs larger
than29,024 baseline. Reject promotion. Successful map report/log under
scratch/cpu_area/p_fsave_shared_sep24 and
scratch/interim_fsave_shared_decode_20260924/area/fsave_map.log.
FRESTORE-only remains independent and pending.
