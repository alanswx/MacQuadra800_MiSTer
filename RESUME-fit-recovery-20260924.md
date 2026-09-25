# Power-loss recovery and next-step strategy

Written September 24, 2026 (Toronto); state checked September 25 at 00:51 UTC.
Read this first, then the linked detailed records. Recheck live state before acting.

## Status at handoff

**No new full-feature RBF has successfully routed yet.** We have reduced logic,
validated the CPU changes, and prepared MiSTer, but have not run hardware tests
on this interim candidate. The goal is still active and incomplete.

The current full build is **`interim_mac_divsqrt_borrow`**, launched at
`2026-09-24T23:23:13Z`, from source commit
`7af6a295683771e9463f88c9df42972e783fada3` on branch `add-ethernet`.
At the final pre-commit check it had run about 91 minutes overall. The fitter was still
live and accumulating CPU time. The last flushed log message is physical
synthesis after register retiming; do not assume the log identifies its exact
current internal operation. There is no terminal result or source-after check yet.

- Archive: `scratch/interim_mac_divsqrt_borrow_fit_20260924/`.
- Launch command: `bash scripts/cpu/fit_dev.sh interim_mac_divsqrt_borrow --allow-other-projects`.
- Luna monitor: `/root/interim_validation`; tool session `69047`.
- Observed PIDs: wrapper `1793732`, Quartus flow `1793792`, fitter `1798838`.
  These are historical identifiers after reboot; verify command lines and cwd.
- Fresh synthesis estimate: **39,021 ALMs**, down 292 from the preceding
  full-system estimate of 39,313. This does not prove placement or routing.
- Last pushed HEAD before this document: `b64a77c`; commits after `7af6a29`
  only updated documentation. The source snapshot is recorded in `commit.txt`
  and `tracked_before.sha256` inside the build archive.

**Do not edit tracked HDL, QSF, QIP, SDC, or TCL while this flow runs.** The
wrapper owns the checkout through its STA/report generation and source-after
check, not just through the fitter process. Documentation edits are safe.
Never deploy the existing `output_files/MacQuadra800.rbf` merely because it
exists: the previous artifact is stale (the old P232 build).

## What is being built

Normal Mac/MiSTer functionality, including Ethernet, CD-ROM, CD audio, audio
output, OSD and Y/C, with hard-disk caching enabled. Neither development nor
release-lite profile is sourced. QSF uses `CACHE_SMALL=1` and `CACHE_CD_OFF=1`:
CD caching is bypassed, but the CD device/audio and hard-disk cache remain enabled.
CPU caches use SETW=7 (8 KB instruction and 8 KB data). Experimental pipeline
loads/stores/PEA/P6, memory entry, compare, early drain, LEA and XSTORE remain on.

Seed 21; placement effort 1.0; aggressive routability ALWAYS; balanced
optimization with AREA technique. Performance physical combinational synthesis
and area-oriented physical combinational synthesis are both ON. Retiming is ON;
performance register duplication is OFF. Clock constraints have not been relaxed.

Exact current input SHA-256 values:

| Input | SHA-256 |
| --- | --- |
| `MacQuadra800.qsf` | `79c19e048ee7890dc6f73f3d054cd3a890866ebfb9bdfcaa345e9c32735424d6` |
| `rtl/ap68040/rtl/ap040_fpu.v` | `2d53db3ae4a04310add04eeb7919f0219197a98827ed92e410e6d4a4a90f5465` |
| `rtl/ap68040/rtl/ap040_core.v` | `2b92366c91720f49ba7e16b740169b7e6601dc2d833960aa874037b3b265b63e` |
| `rtl/ap68040/experimental/ap040_pipeline_integer.sv` | `92ea4d96a5b2da0784e65fe2015118e4889353a7df83e4ccca8bf6a1e7059435` |

The complete tracked-input manifest is authoritative; this table is a quick check.

## Recovery after reconnect or power loss

1. Inspect `git status`, recent commits, actual processes and the current archive.
   A quiet log, a stale lock file, or an observation timeout does not prove the
   job stopped. If the same flow is alive, resume monitoring it; do not relaunch.
   The user explicitly said not to blindly kill Quartus. Independent projects
   may run concurrently, but never two full flows in this checkout.
2. If the wrapper finished, read `build.exit`, `source_check_after.exit`,
   `cross.exit`, `cpu_timing.exit`, fresh fit/STA summaries and `rbf.sha256`.
   A missing terminal file is incomplete evidence. A routed design can still
   fail timing; a nonzero wrapper exit must be interpreted from its components.
3. If power loss interrupted it and no matching process remains, preserve the
   old archive as interrupted. Do not claim success from its partial reports or
   run STA against an unverified partial database. Confirm current source still
   matches the intended snapshot and inspect any unexpected local modifications.
4. Restart the **same configuration first**, using a new unique tag, for example:

   ```sh
   cd /home/alans/mister/MacQuadra800_MiSTer
   bash scripts/cpu/fit_dev.sh interim_mac_divsqrt_borrow_recovery1 --allow-other-projects
   ```

   The wrapper refuses an existing tag/date archive and guards this checkout
   with an OS `flock`. Do not manually bypass a live lock. Check other Quartus
   processes by command line/cwd. No git worktrees. Do not run `fit_dev.sh --help`:
   this script treats its first argument as a build tag.
5. After a real power loss, check MiSTer connectivity and guest state afresh.
   Slot 0 must still select the disposable disk. Recover that disposable guest
   as needed; never replace or overwrite the protected original disk image.

This Linux environment previously required `exec_command` escalation because
sandbox startup failed with `bwrap: loopback: Failed RTM_NEWADDR`. That is an
execution-environment issue, not evidence the build failed. `scripts/local.env`
contains local tool/SSH settings; do not print secrets. Expand a leading `~`
in the SSH key path rather than passing a quoted literal `~` to ssh.

## If this build fits and routes

1. Let the complete wrapper finish. Require source-after integrity and a fresh,
   archived RBF tied to the exact source/configuration. Record its SHA-256,
   fitted resources, setup/hold results, and both directions of clk_sys/clk_ram
   crossing analysis. Review all relevant clocks, not only the CPU clock.
2. If timing passes, proceed directly to hardware validation. If an RBF exists
   but timing fails, preserve it and identify exact failing paths and margins.
   Prior user instructions allow exploratory timing-marginal hardware tests;
   report that qualification explicitly and do not call the build timing-clean.
   CPU/SDRAM failures deserve particular scrutiny because memory correctness is
   affected. A hardware pass does not erase an STA failure or justify release.
   Do not invent false paths: the related 33/99 MHz SDRAM crossings must stay timed.
3. Deploy only the fresh candidate to verified `mister.local`, using the disposable
   HDA. Follow [the hardware checklist](docs/INTERIM_HARDWARE_VALIDATION.md), with
   the updated fixture paths below overriding its older missing-image examples.
4. Validate boot, responsive Finder/input/idle clock, normal shutdown, Ethernet,
   data CD reads and CD audio controls/output. Then collect **five valid
   Speedometer runs**, preserving all ten metrics and Mix per run and the median.
   Do not capture screenshots during timed runs. Invalid runs do not count.
5. Preserve and push source, exact artifact identity, results, limitations and
   handoff. Do not mark the goal complete on fitting alone. A/UX is explicitly
   deferred to Dani; its disk is unavailable. Audible CD output requires the
   user's ears at the display. No dedicated hardware disk-cache counter gate
   exists yet; describe boot/benchmark disk use as functional coverage.

The target is performance near 1.8 while delivering a validated full-feature
interim build; hitting 1.8 is not a prerequisite for that interim delivery.
Comparison caveats: P212 median 1.725 had caching but a development profile
without OSD/sound and CPU timing -1.446 ns. P232 scored 1.778 with
`SCSI_CACHE_OFF`, so it is not a full-feature/cache-on baseline. Real Quadra 800
reference is about 1.897. Report profile differences and individual metrics.

## If this build does not fit or cannot route

First archive the actual failure, resource accounting, routing demand, elapsed
time and integrity result. Distinguish capacity, congestion, timing, source
integrity and tool failure. Do not infer failure merely from its long runtime.

**My next controlled experiment is a physical-synthesis setting change, not
another blind seed walk:** on the same validated borrow RTL, set only
`PHYSICAL_SYNTHESIS_COMBO_LOGIC OFF`, leaving
`PHYSICAL_SYNTHESIS_COMBO_LOGIC_FOR_AREA ON`, retiming, seed, features and timing
constraints unchanged. Commit the exact setting and launch a new archived full
fit after the previous wrapper has finished. Suggested tag: `interim_mac_borrow_nospeedphys`.

Reason: the first setting is the performance-oriented physical logic pass;
Quartus's installed advisor notes it can increase logic use. The second is the
area/fitting pass. The prior report attributed an estimated 1.590 ns improvement
to the speed pass, so removing it can hurt timing. This is a measured tradeoff,
not a promised cure. Compare actual fitted resources/routing and all clock/hold
margins. Keep whichever configuration supports the validated full-feature result;
revert or retarget an unhelpful change instead of stacking unmeasured settings.

A small F_ADDX shared add/sub variant is already validated but **not integrated**:
`scratch/alu_fpu_addsub_shared_20260924/`, FPU SHA
`6fd0a29d37aae9a4878f68872a8623855ba392f447af0141178bc9e43e6063ab`.
It saves only 30 CPU-map ALMs (25,484 vs 25,514). Its miter and complete directed
suite pass. Keep it isolated during the setting experiment so causality is clear;
it does not by itself justify another full build.

If the setting experiment also fails, use its hierarchy/congestion/timing evidence
to choose a larger structural reduction. Avoid endless tiny savings and seed
changes. A lower-unroll FPU divider/square-root fallback was identified but has
not been implemented: it may reduce logic while roughly tripling iteration
latency. Quantify arithmetic/Speedometer impact before choosing that tradeoff.
Do not silently disable Ethernet, CD audio, disk caching or other requested
features. Keep global VRAM/ROM/cache relocation and disk redesign out of this
interim fitting effort unless a specific measured necessity changes the plan.

## Evidence already obtained; avoid rerunning it without a reason

Recent full-fit attempts (all no fresh RBF/STA):

| Trial | Map ALMs | Fitter ALMs needed | LABs | Result |
| --- | ---: | ---: | ---: | --- |
| `interim_mac_onealu` seed 28 | 39,354 | 41,002 | 4,155 | Placed, routing failed |
| `interim_mac_onealu_s21` | 39,354 | 40,997 | 4,156 | Placed, routing failed |
| `interim_mac_onealu_s21p3` effort 3 | 39,354 | 40,997 | 4,156 | Placed, routing failed |
| `interim_mac_divsqrt` source 3791bf6 | 39,313 | 41,077 | 4,165 | Placed, routing failed |
| Current `interim_mac_divsqrt_borrow` | 39,021 | Pending | Pending | Live at handoff |

“ALMs needed” includes a packing/unavailability estimate, not just implemented
logic. Example s21p3: 39,778 actually used minus 1 recoverable plus 1,220
unavailable = 40,997 needed. Most unavailable ALMs are due to LAB input limits.
Do not confuse CPU-only synthesis gains with full-device routing improvement.

Current FPU changes share DIV/SQRT's three arithmetic stages and derive unsigned
comparisons from a 70-bit difference's borrow bit. They preserve three bits per
iteration, terminal counters, rounding/GRS, and instruction cycle structure.
The borrow candidate passed 100,056 source-derived recurrence comparisons,
a deliberate truncation negative control, and the complete directed CPU suite
with LEA/XSTORE, including FPU exceptions, frames and BUSY resume. CPU map:
25,514 ALMs / 8,966 registers. Evidence:
`scratch/alu_divsqrt_shared_borrow_20260924/RESULTS.md` and `cpu_suite_evidence/`.

Earlier combined common-ALU/shift/queue/BRF reductions have six production
Speedometer kernel simulations, directed drain, fault and IRQ coverage preserved
in `scratch/alu_owner_combined_86d48df/` and the detailed chronological handoff.
The ordinary CPU suite does not enable the experimental pipeline; dedicated
pipeline evidence matters. Do not mislabel its legacy IRQ test as pipeline coverage.

Other rejected screens include integer ADD/SUB sharing (+25 ALMs), FPU frame
sharing, BRF barrel alternatives and sticky shifting. See
[fit experiments](docs/INTERIM_FIT_EXPERIMENTS_20260924.md) before repeating work.

## MiSTer readiness and authorization

The latest user instruction is: **“the fpga is ready when you are - replace
whatever is running.”** This supersedes earlier unavailable-hardware notes.
Do not ask again solely because an older document says it is occupied; obey any
newer user instruction. Reloads/resets with the disposable disk are authorized.
Only use `mister.local`, last verified `10.3.89.233`; never stale `.143` or `.92`.
Preflight observed FM-7; re-observe after reconnect. No new core has been deployed.

- Disposable: `/media/fat/games/MacQuadra800/QuadSquad8-pipeline-test-20260919.hda`.
- Protected original: `/media/fat/games/MacQuadra800/QuadSquad8.hda`.
- `config/MacQuadra800.s0` was verified to select the disposable disk.
- Do not hash/copy a mounted HDA. A shutdown screenshot does not prove Main
  released its file descriptor. Do not use default deployment disk-seeding options.
- Host Main SHA-256:
  `6db4851b939dbef32297c3fcce47d37531daddf5214e9a28a54412afd6586fd0`.
  Exact source version is unknown, but it embeds `macquadra800`, `Mac CD: cmd`
  and `Quadra 800 SONIC` markers. This supports capability, not functional proof.
- CD fixtures are already staged and SHA-verified under
  `/media/fat/games/MacQuadra800/interim-validation-20260924/`:
  `ToneTest.cue`, `ToneTest.bin`, `HFS-Data-Test.iso`.
  Slot 4 was empty before testing; fixtures are not mounted yet.
- Tone BIN SHA: `d7b79ff2ea7455c431bed459c50a6333ce1c8213c5244150ca511da57e95d06c`.
- HFS image SHA: `3aff251d770216fd5eabe1ae9ef4a2db7abe9d473f8aa688cba635bd9c3ab68b`.
  It contains `MacQuadra800-CD-README.txt`, with TEXT/ttxt Finder metadata;
  independent hfsutils extraction matched its known bytes.
- The old ToneTest and Open Transport image paths in older notes are missing.
  Use the staged replacements, not those stale examples.
- Preflight/fixture evidence: `scratch/interim_hardware_preflight_20260924/`.
  Tone generation is tracked in `scripts/make_tonedisc.py`; the HFS regeneration
  recipe is `fixtures/build_hfs_fixture.sh` inside that scratch evidence directory.

## Repository, people and follow-on scope

Commit and push meaningful progress explicitly to **`origin add-ethernet`**;
the configured upstream is misleading. Current source and summary documents
have been pushed. Most raw logs, fixtures and rejected prototypes are gitignored
under `scratch/`: they survive an ordinary reboot on intact storage but are
**not** backed up by a Git push. Tracked documents preserve source identities,
results and commands; losing the storage itself would require regenerating raw evidence.

Leave these unrelated untracked files alone:
`docs/disk-speed-vs-minimig-ao486.md`, `docs/scsi-ddr3-disk-plan.md`,
`worst_detail.txt`, `worst_paths.txt`.

Use Luna for routine builds, simulations and hardware operation. The monitor
currently owns the full-fit session; root handles architectural decisions and
review. Other Luna workers finished their screens and are idle. Agent/session
handles may not survive power loss; use filesystem/process evidence to resume.

After the full-feature interim build is validated: assess global memory placement
(BRAM vs SDRAM vs DDRAM for caches/VRAM/ROM/buffers), then profile disk bottlenecks,
then write a measured disk-improvement plan. A larger on-chip L1 with external
burst refill is a hypothesis to compare, not an agreed redesign. Decide CPU parity
(~1.89) versus disk improvement from the measured user benefit.

Further references:
[goal](docs/INTERIM_BUILD_GOAL.md),
[hardware validation](docs/INTERIM_HARDWARE_VALIDATION.md),
[chronological handoff](RESUME-interim-mac-20260924.md),
[fit experiments](docs/INTERIM_FIT_EXPERIMENTS_20260924.md).
