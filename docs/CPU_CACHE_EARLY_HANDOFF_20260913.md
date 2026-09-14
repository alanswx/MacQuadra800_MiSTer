# Resume here: registered cache-hit prototype

## Checkout and ownership

Use `/home/alans/mister/MacQuadra800_MiSTer`, NOT the old default
`/home/alans/mister/wombat33_MiSTer`. Branch `profile-speedometer402-20260909`,
parent HEAD `50ca69b`. Read `AGENTS.md` and `docs/AGENT_TESTING_WORKFLOW.md`:
Astra owns RTL/design/diagnosis, Luna runs established tests/builds/hardware.
Use explicit absolute working directories and source hash checks throughout.

No commit or push was requested for this handoff. Preserve all existing dirty
files and AP submodule untracked build directories. Feature toggles and these
records remain uncommitted. Active CPU and cache are still the accepted pair:

- CPU: `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`
- Cache: `55b94aeebca640cb8418eb88c2df0ca6707e7e016a0700f375ae61a6b338599b`

## Current experiment and measured result

Candidate tree `/tmp/cache-early-hit.2goe86`, baseline
`/tmp/cache-hit-latency.ZBuCjk`. Candidate changes only ap040_cache.v:
`77882b83f738f711ff16f923688a06031b6b0d86373214fb4bb0d75b040f162b`.
Patch SHA256: `c2e22d2feabee10880629f8fda117f369dc59327c92e6f206d8c`.

The cache reads its existing tag/data RAM while translation is pending.
It registers completion at admission only when fresh read metadata matches
the current request and its physical tag/permissions are qualified. Otherwise
it retains the normal C_LOOK path. Existing instruction lookahead has priority.
RAM-write/invalidate/snoop conflicts invalidate reuse conservatively. Estimated
addition is 18 metadata bits plus control/comparison logic; FPGA cost unknown.
There is no new combinational CPU acknowledge, extra data RAM or second decoder.

Actual integrated fixture (wombat_cpu/MMU/cache/store buffer, deterministic
memory rather than SDRAM timing): **2,188 -> 2,127 clocks**, exactly 61 eligible
hits saved (53 instruction, eight data). Warm translated data hits **4 -> 3
clocks**; first walk followed by cache hit **20 -> 19**. TC-off/TTR data,
uncached passes and existing instruction-lookahead latency are unchanged in
this fixture. CE pause, snoop-forced miss and error/RTE restart checks pass.
This is mechanism evidence, NOT a Speedometer or representative-workload gain.

## Honest test status

- Integrated diagnostic: PASS, actual exit 0.
- Additional collision/byte/word/stale-index/physical-tag/CE-snoop bench: PASS,
  actual exit 0, both `EARLY_ADMISSION_TESTS_COMPLETE` and `ALL TESTS PASSED`.
- Unmodified all-11 AP suite: **exit 1**, not all-green. Ten suites pass.
  Original cache_snoop T12 has two latency assertions requiring lookahead to
  beat an ordinary repeated seed. That seed now accelerates too, tying at two
  clocks; checked data remains correct. An isolated adjusted test deliberately
  changes the idle RAM word to force normal fallback, retains the strict
  predictor-faster assertion, and passes. Do not silently relax or hide the
  original failures; review/update the test contract explicitly before adoption.
- Patch check and independent apply/hash roundtrip passed. No FPGA compile,
  fitted area, STA, application profile or hardware score exists for this cache.

## Durable artifacts and reproduction

Preserved under `scripts/fixtures/cache_early_handoff/`: baseline and candidate
program/runner/bench, summarizer, candidate patch and original detailed README.
Logs: `scratch/cache_early_handoff_20260913/`. Original README describes the
initial /tmp locations; use fresh isolated copies when those are unavailable.

Do NOT run the candidate runner directly without installing candidate RTL:
its convenience fallback copies active baseline RTL and verifies CPU only.
For each fresh fixture directory, copy the corresponding preserved fixture
files plus the complete active `rtl/` tree. Verify baseline CPU/cache hashes.
In the candidate directory only, apply `cache-early.patch` from that directory
with `git apply`; verify resulting cache SHA above before running `run.py`.
Run baseline/candidate separately using explicit workdirs. Summarize both logs
with baseline `summarize.py`. No preserved script needs the old build output.

Required local tools currently referenced by runners:
`/tmp/wombat-vasm/vasmm68k_mot`, `/home/alans/verilator5/bin/verilator`, Python3;
adjust tool paths explicitly if unavailable, never substitute workload bytes.
The detailed candidate README has the Icarus command and all-11 suite command.
The legacy cache bench can exit zero despite failures: inspect PASS markers.

## Next work, in order

1. Review the RTL diff and the latency-oracle adjustment. Keep candidate isolated.
2. Run broader architectural/corpus and representative workload gates, including
   real cache/SDRAM integration, multiple alignments, translation and permissions,
   instruction/data mixes, self-modifying code and snoop/write collisions.
   Do not extrapolate the deliberately constructed 61-hit fixture to CPU Mix.
3. If correctness and coverage justify it, prepare a matched trimmed seed-24
   build from `/tmp/MacQuadra800_features_seed24.UNORIQ/trim`, changing ONLY the
   cache (not the rejected combined CPU). Run full-machine compile, synthesis,
   fit and all timing checks; preserve original constraints and registered ack.
4. Hardware only after parent fit/STA review, through the mandatory lifecycle
   guard. Compare the same feature configuration and reject impossible timings.

## Other results and blockers to retain

Optional YC/MT32-pi/shadowmask/output-IIR removal profile is opt-in; defaults
remain unchanged. Trimmed source-only fit: 36,538 ALMs, 4,061 LABs (130 free),
31 DSPs; RBF `9aba3ebf...`. Hardware 0.463/0.464/INVALID is not an accepted mean.
The combined CPU overlap `21d408fa...` fits when trimmed, but hardware
0.460/0.461/INVALID did not show a gain. **Do not adopt it.** Latest accepted
untrimmed/CD-off source-only mean remains 0.458667. See the corresponding
`CPU_TRIM_SPEEDOMETER` and `CPU_COMBINED_TRIM_HARDWARE` records.

The recurring negative-timing anomaly predates these experiments. A validated
simulator-only observer is preserved in `scripts/fixtures/speedometer_timing_observer`.
Its tests and full-machine adapter compile pass; it has not captured the actual
anomaly. The first fresh normal-ROM run hit its 900-second wall limit after
about 1.31 billion half-edges, exit 124, with no screenshots/navigation and no
usable timer trace. Do not infer that Finder was reached or failed to boot.
Future runs need planned local screenshots, deliberate normal exit/trace flush,
and sufficient boot budget; any fastboot ROM choice must be explicit and hashed.

MiSTer last verified at MENU after guarded restore. Main unchanged MD5
`dfb5937ba47720c3ae20abc8f381c462`; restored disposable MD5
`16790b0577e13b45782214433d34954b`. No agent owns the FPGA now. Verify current
state before future actions. No benchmark or Quartus job is pending for this
prototype at handoff; old temporary trees/logs are evidence, not active jobs.
