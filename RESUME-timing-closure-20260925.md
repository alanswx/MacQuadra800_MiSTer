# Timing closure and parallel disk profiling — September 25

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
