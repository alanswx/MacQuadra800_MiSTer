# Timing closure and parallel disk profiling — September 25

## Current checkpoint

The second fit, `brf_addr_tras_seed21_20260925` on `aff6dfd`, failed routing
congestion after successful placement. Its fresh fit summary reports 39,875
ALMs needed (95%), 28,006 registers and 509 M10Ks. Source-after checks passed;
no fresh RBF or timing result exists. Its full map was 38,640 ALMs.

The next selected CPU is the validated unused-address-X variant, retaining
the tested SDRAM ready bits. Its CPU-only map is 25,410 ALMs (-104 versus
baseline, -53 versus address-only), with unchanged registers/memory. Active
loop/IRQ and full strict legacy replay passed. It leaves only the unused
per-cycle temporary address unspecified; every consuming request sets a known
address. No state/output is assigned X. Seed, clocks and all features remain.

Disk profiling is complete; MiSTer remains on the original tested core at the
Speedometer completion dialog, using the disposable disk. The first larger
early-payload fit also failed routing and will not be retried.

User requested continued timing work and a new PR once timing passes. Existing
PR #6 is ready for review and preserves the tested interim artifact; do not
advance its branch with unvalidated timing experiments. Progress remains on
`add-ethernet`, with a new review branch to be created after timing closure.

Baseline source HEAD before this task: `165e2a7`; build inputs match fitted
`15a1449`. Installed RBF SHA256:
`4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`.
CPU/RAM/HDMI setup: -2.406/-0.697/-0.426 ns. All Mac features remain enabled.
Do not weaken clock constraints or mask functional paths to claim closure.

## First candidate: early resident branch-refill payload

`rtl/ap68040/rtl/ap040_core.v` prepares the dgo refill lane words and count
from `dbrf_a_early` outside the clocked process. The final seed write keeps
`brf_seed_req`, then selects the early payload for dgo and retains the existing
generic payload for other callers. Seed writes remain after append/line offer,
with their existing priority. No new architectural cycle is intended.

Archived tested-artifact CPU path is `ifr_addr[16] -> epf_data[6][0]`,
28 logic levels, 71% interconnect, setup -2.406 ns. Use
`scratch/interim_mac_wqmlab_fit_20260924/cpu_timing/worst_detail.txt`.
The untracked root `worst_detail.txt` is a DIFFERENT build (-0.862 ns);
do not use it as the installed core's report.

This candidate is not yet validated or fitted. Separate early payload logic
may cost too much area or move the critical path; no improvement is claimed.
Luna interim_validation owns scratch equivalence/regression tests; Luna
alu_rotate_sharing owns sequential baseline/candidate CPU mapping. Root owns
RTL and full-fit launch decisions. Never kill Quartus blindly.

## Parallel disk profiling

User explicitly authorized a Luna profiler. Agent luna_disk_profile owns
hardware on mister.local (10.3.89.233), current disposable HDA only. It must
coordinate before core replacement/shutdown; root must coordinate before
new build deployment. No Main replacement/restart or mounted HDA hashing.
Physical audio/OSD checks remain deferred; A/UX remains Dani's check.

Baseline disk Performance Rating .565 versus real 3.443, FPU average .681
versus real 1.011. New profile goes in `docs/DISK_PROFILE_20260925.md` with
measurements/limits, without editing RTL or selecting a disk redesign yet.

## Next decisions

1. Check equivalence including no-seed dgo, count masks, wrapping and queue
   write priority; distinguish active pipeline coverage from legacy coverage.
2. Reject excessive area growth before a full fit. If plausible, commit exact
   inputs, build with durable logs and manifests, and archive all timing paths.
3. Address measured remaining CPU, SDRAM and HDMI failures in turn. Prior
   SDRAM five-bit age shift failed routing twice; do not repeat blindly.
4. After passing setup/hold and crossing checks, coordinate hardware ownership,
   test boot/peripherals and performance with the disposable disk, then open
   the requested timing-fix PR. Keep user-deferred physical checks explicit.

## Candidate 1 screen and full-fit decision

Focused extracted seed miter passed 55,296 cases, including dgo and generic
payloads, wrap, count masks, overlapping writes and no-seed no-op. Wrong-lane
negative control is rejected. Corrected generic alignment fixture passed
8,320 cases on both baseline and candidate. The old fixture incorrectly
modeled a 128-byte rather than 64-byte refill buffer. Full CPU regressions
are still running; no hardware deployment is authorized by these checks alone.

CPU-only map: baseline 25,514 ALMs, candidate 25,955 (+441), both 8,966
registers, 296,960 block-memory bits and 4,352 MLAB bits. Candidate core SHA256
`4c7f8685` prefix; full hashes in `scratch/dgo_area_sources.sha256`.
A single full fit is selected to measure actual path improvement and routability.
Area growth is a real risk with 4,182/4,191 LABs occupied in the baseline.
Do not start a blind seed sweep if it fails. Preserve this candidate's reports
before evaluating a shared-selector alternative.

## Full fit launched

Source `6bd3c330f6a82594cc9cfe6fb699c45b00f6ca01`, tag
`brf_dgo_seed21_20260925`, seed21 unchanged. Detached wrapper PID2434701;
Quartus flow PID2434745 at launch. Archive
`scratch/brf_dgo_seed21_20260925_fit_20260925/`, wrapper output
`scratch/brf_dgo_seed21_20260925_wrapper.out`. Pre-build source manifest passed.
Luna alu_rotate_sharing monitors; do not edit build inputs while running.

Active production-macro loops/IRQ test baseline and candidate passed with
identical phase cycle counts 138988/161098/161098 and matching 15030 dgo seed
events and 13796 dgo/fill overlaps. Integrated dgo-no-seed coverage is zero;
the focused miter covers its no-write guard. Candidate full legacy suite still
pending at this checkpoint. No measured timing improvement yet.

## Validation and alternatives checkpoint

Both full legacy CPU suites passed. Integrated active pipeline priority checks
passed with identical cycles, 15030 dgo seeds, 13796 fill overlaps and109534
seeded slots checked. Initial focused-miter assertion/wrapper had a delta-cycle
sampling/reporting bug; the corrected strict reusable CLI now independently
passes all55296 cases and rejects the intended lane mutation. Root reran it
successfully; use only those final results, not the intermediate report.

Opcode-sharing variant in scratch passed active loops/priority and strict
miter; CPU-only map25782 ALMs (-173 from candidate1, +268 from baseline),
registers/RAM unchanged. Address-only fallback passed active loops with a
one-issue_ifetch-per-edge assertion; its map is running in a separate DB.
Neither fallback is promoted. Full fit remains on6bd3c33.

## First fit terminal; smaller replacement selected

`brf_dgo_seed21_20260925` failed routing congestion after16m31 overall,
11m14 fitter. Estimated/required40865ALMs, placed39438, LAB4178/4191,
509M10Ks,27986regs. No freshRBF/STA; old output RBF is still the installed
4687167a... artifact. Source-after manifest passed. Do not mistake placement
success for fit/timing success and do not repeat this larger candidate blindly.

The address-only fallback maps25463ALMs (-51 vs baseline25514),8966regs,
296960block bits,4352MLAB bits. It passed active loop/IRQ equivalence including
same cycle counts and a test-only at-most-one-issue_ifetch assertion. Full
legacy fallback tests are now running. This smaller core replaces the rejected
early-payload duplication; opcode-sharing variant remains scratch-only.

SDRAM ready-bit candidate passes87direct invariant checks,174chip-model checks
with identical baseline latency summaries, registered-first-miss64reads plus
2048mixed ops, and lineDMA20512reads/5381stores/11423DMA beats with zero errors.
A standalone area screen is running before deciding whether to combine it
with the address-only core in the next full fit. Current installed core stays
unchanged; Luna disk profiler retains hardware ownership.

## Second candidate: address carrier plus SDRAM ready bits

Standalone SDRAM bridge map: baseline 618 ALMs / 958 registers, ready-bit
candidate 622 ALMs / 966 registers (+4 / +8). Both retain 488 MLAB bits in
61 MLAB cells and zero M10Ks. Evidence: `scratch/sdram_ready_area_20260925/`.
The tested ready-bit controller is now promoted alongside the smaller
address-only CPU. CPU source SHA324abb6e... and SDRAM source SHAa7117892...
match the separately validated snapshots. No constraints/features changed.
The next full fit will use this combined candidate, with its exact source
commit recorded at launch. Address-only full legacy suite remains pending;
no hardware deployment until correctness and timing checks complete.

## Second full fit running

Source `aff6dfd09dc755fd826cebd92ffc8485747bb440`; tag
`brf_addr_tras_seed21_20260925`; detached wrapper PID 2486252.
Archive: `scratch/brf_addr_tras_seed21_20260925_fit_20260925/`.
Preflight: `scratch/brf_addr_tras_seed21_20260925_preflight.txt`.
Tracked input precheck passed. Core SHA `324abb6e...6a19b89`, SDRAM SHA
`a7117892...8146f7ae`, queue SHA `6b49355a...f5f9937ba`. Seed 21 and normal
feature settings unchanged. No earlier Quartus job was active at launch.
Luna alu_rotate_sharing monitors and will archive corrected MLAB hierarchy
coverage and all clock/crossing reports if fitting succeeds. Inputs frozen.

Luna disk profiler completed a Disk+Math run (CPU/Graphics unchecked), one
iteration: Disk 0.589, Math 20.873. Its sampler missed the workload, so no I/O
attribution is claimed. Another run is planned with sampling armed first.
MiSTer still runs the original tested artifact and disposable disk.

The address-only full legacy CPU suite has now passed with its test-only
one-issue_ifetch-per-edge assertion. Updated evidence is in
`docs/TIMING_BRF_EARLY_20260925.md` and
`docs/TIMING_SDRAM_READY_20260925.md`. Combined candidate fit remains running;
no timing result is claimed.

## Disk profile preserved

`docs/DISK_PROFILE_20260925.md` and `docs/perf/disk_profile_20260925/` now
preserve two Disk+Math ratings (0.589/0.585), synchronized Main/device counters,
actual O_SYNC descriptor flags, screenshots, and instrumentation limits.
Run2 observed 4596736 device bytes written, 3682 device writes, 14019ms summed
write time and 15728ms I/O time; these are device aggregates, not guest bandwidth
or measured Main blocking time. Physical read counters were flat. No bottleneck
is proven yet. Luna is now measuring backend write batch-size cost with a new
exclusive temporary host file, never an HDA, while the guest is idle.

## Strict CPU test-runner revalidation

Luna found that the legacy shell runner piped vvp through tee and grep -q,
which could hide a simulator failure after a pass banner. Root changed the
runner to wait for vvp, require exit0 plus the positive marker and reject fatal
or failure markers. Negative controls require a nonzero exit and their intended
TEST FAILED diagnostic. Seven mocked runner cases pass, including a pass banner
followed by a fatal. No HDL/configuration changed. Luna is replaying the existing
compiled address-only and X-variant suites with strict exit checks; prior
aggregate banners alone are provisional until that replay completes.

## Disk profiling complete; fallback strict replay passed

Host-only O_SYNC overwrite tests on a unique temporary file measured the same
4 MiB in 31.327 seconds at 512-byte writes, 3.636 seconds at 4 KiB writes, and
1.426 seconds at 16 KiB writes. The file/directory were removed successfully.
The actual filesystem is mounted sync/dirsync; removing O_SYNC alone would
not make it asynchronous. These are single-pass host backend measurements,
not guest throughput. Next disk investigation should measure actual request
and flush batch sizes before choosing a coalescing change or DDR redesign.
Evidence and limits: docs/DISK_PROFILE_20260925.md.

The unused-address-X fallback's strict legacy replay completed exit 0 with all
positive tests and three intended negative controls passing. Source SHA256
6dface16365ae0c0d820897ffb8dfcfd7ef9161a63f3ed64b273fb7933d47a0f; logs and
explicit replay script in scratch/brf_unused_address_dc_20260925/legacy_check_retry/.
This supersedes the invalid initial masked-fatal run. Address-only replay is
still pending; the current full fit continues unchanged on aff6dfd.

## Third candidate selected after routing failure

Promoted exact validated core SHA256
`6dface16365ae0c0d820897ffb8dfcfd7ef9161a63f3ed64b273fb7933d47a0f`,
restoring address assignment inside the hit guard and making only its unused
default a synthesis don't-care. SDRAM remains the tested ready-bit controller.
The second fit's archive completed with build exit 3, source-after exit 0, and
STA skipped correctly for the unrouted design. Average estimated routing use
was 47%, peak 75% at X45_Y11–X55_Y22. Next full fit will test this smaller form;
there is no timing-improvement claim from CPU-only area or simulation results.

Both address-only and X-default strict legacy replays are now complete with
exit 0; all positive tests and all three intended negative controls passed.
The next fit source is `a75b300`, tag `brf_dc_tras_seed21_20260925`.

## Third full fit launched

Tag `brf_dc_tras_seed21_20260925`; wrapper PID 2570932; source HEAD at launch
`8cbbe45edff83d6c3fb0920e64ab490b05ae8f63` (docs follow-up to RTL a75b300).
Archive `scratch/brf_dc_tras_seed21_20260925_fit_20260925/`; source precheck 0.
Luna alu_rotate_sharing owns monitoring and post-fit reporting. Inputs frozen.
If successful, collect CPU/RAM/HDMI setup and hold path details, crossings,
and corrected MLAB hierarchy reports before any new build overwrites the DB.

Previous failure used 4,190/4,191 LABs and 39,463 actual placed ALMs despite
39,875 required ALMs (95%). Final reported routing usage was 65.6% average,
91.1% peak; the earlier 47%/75% numbers were router estimates. Thus logic-block
packing/routing remains a concern even when total ALMs decrease. Its archived
RESULTS.md records the terminal details. No new RBF exists.

Additional parallel work is scratch-only: interim_validation is evaluating one
further refill mux simplification, and luna_disk_profile is measuring existing
cache flush grouping under controlled simulated write arrival gaps. Neither
is authorized to alter frozen production build inputs.
