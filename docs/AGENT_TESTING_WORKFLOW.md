# Model routing and testing handoff

## Reusable local CPU corpus gate

`bash scripts/cpu_corpus100_gate.sh RTL_DIR PAYLOAD_HEX BASELINE_RESULTS`
uses the preserved first-100 testbench and immutable payload hash, builds only
the simulator, checks actual completion, and compares exactly 100 records.
Never rebuild the payload to work around a missing assembler: that changes
the comparison fixture. End-to-end validation passed in
`/tmp/cpu-corpus100-gate.7wYqvc`: 34,829,460 cycles, 1,900 matches, zero REAL diffs.

User preference, 2026-09-12: spend Astra reasoning on architecture and code;
delegate routine testing to Luna. This is an explicit delegation authorization.

## Responsibilities

- `gpt-6-astra`: architecture, profiling interpretation, RTL and test-code
  implementation, correctness review, failure diagnosis, and acceptance decisions.
- `gpt-5.6-luna`: run established regression and build commands, inspect summaries,
  deploy approved candidates, navigate Mac OS, run Speedometer, transcribe
  results, preserve evidence, restore the disposable disk, and update test records.
- Luna must not edit RTL, change timing constraints, alter benchmark settings,
  substitute disks, dismiss a failure, or decide that an optimization is accepted.
  Report an unexpected state with its screenshot/log and return control to Astra.
- If a model is unavailable, report it; do not silently use a more expensive
  model for the whole test. A parent already running another model cannot switch
  itself through these rules; use a named agent when useful independent work exists.

## Delegation and resource ownership

Spawn bounded test tasks with `model="gpt-5.6-luna"`, `reasoning_effort="low"`,
and `fork_turns="none"`. Provide the exact task context below. Use medium effort
only if interpreting the established procedure requires it. Use Astra for code
tasks. Keep the parent working on independent local analysis/documentation while
the test agent operates; avoid supervising every click with expensive model turns.

There is exactly one owner of FPGA loading, guest input, screenshots, and disk
restoration. Assign that owner explicitly. Other agents must not issue remote
commands during its test. Transfer an already-running benchmark with its start
time and earliest allowed screenshot time; never restart or capture it blindly.
Use one build owner per build tree as well. Do not commit or push unless asked.

## Required test handoff

Supply the test agent with:

- Repository and working directory; exact source revision/hash and dirty diff identity.
- Local RBF and fit/STA report paths; unique remote RBF name and expected hash.
- MiSTer host and current user authorization/reservations.
- Current core/guest state and whether a timed run is already active.
- Golden source, disposable destination, expected disk hash, and mount path.
- Application/version, test selection, iteration count, baseline results.
- Known navigation commands, screenshot directory, quiet interval, repeat count.
- Allowed actions, explicit stopping conditions, and cleanup requirements.

The FPGA was released from Apple-II by the user on 2026-09-12. A subsequent
user reservation overrides this record. Do not ask again for already-granted
routine testing permission; obey sandbox approval requirements when tools need it.

## Speedometer 4.02 procedure

1. Verify successful fit, zero negative timing slack/TNS, and source/RBF hashes.
   Verify the current machine state before loading the uniquely named candidate.
   Preserve accepted RBFs and Main. Verify the golden disk and slot-0 mount.
2. Boot Mac OS and inspect an idle screenshot. Use established keyboard
   navigation. MacAtrium: Escape opens the menu; two Tabs then Return select
   Exit to Finder. Finder type-select plus Command-O opens Mac7-5-5,
   Applications, Speedometer 4.02 Folder, then Speedometer 4.02.
3. Guest Command is Linux keycode 56 (Left Alt). With `scripts/mister_ws.py`,
   Command-O is `down:56 raw:24 up:56`; Command-B is
   `down:56 raw:48 up:56`. Return is `raw:28`; Escape is `raw:1`.
   Allow each window to settle. Return dismisses the splash; Escape dismisses
   registration. Inspect before assuming the main window is ready.
4. Command-B opens setup; it does not start timing. Confirm all ten CPU Mix
   tests selected, one iteration each, then Return activates Run Set.
5. Wait at least 135 seconds from Run Set with no remote input or screenshots.
   Use bounded waits and concise updates, not repeated expensive inspection.
   Capture after that quiet interval. If still running, mark the run perturbed
   and repeat; do not count a partially captured run as valid evidence.
6. Record all ten absolute results, average, and screenshot hash. Dismiss the
   completion alert, reopen the same setup, and run an immediate repeat with
   the same quiet interval. Negative/impossible times are invalid, not speedups.
7. Return to Menu and restore the disposable disk from the verified golden
   copy. The user authorized discarding this working disk without guest shutdown.
   Confirm Menu before overwriting it; verify the restored hash afterwards.

Current fixture:

- Host: `192.168.1.75`, SSH user `root` using established authentication.
- Golden: `/tmp/MacQuadra800-Speedometer402-profile.hda`.
- Disposable: `/media/fat/games/MacQuadra800/Speedometer402-upstream-test.hda`.
- Golden/disposable MD5: `16790b0577e13b45782214433d34954b`.
- Mount: `/media/fat/config/MacQuadra800.s0` must reference that disposable image.
- Main MD5 last verified: `dfb5937ba47720c3ae20abc8f381c462`; do not replace Main.
- Full-feature CPU reference: 0.405. Previous CD-off retirement checkpoint:
  0.423 and 0.424 (average 0.4235). Compare like application/settings.

## Report back once evidence is collected

Return PASS/FAIL/BLOCKED, exact artifact and hashes, both result tables and
averages, change versus the supplied baseline, screenshot/log paths, any
anomaly, and final machine/disk state. Distinguish measured hardware gains
from simulation estimates. Astra reviews acceptance and chooses the next change.

## Navigation and reporting corrections (2026-09-12)

After visually confirming fresh MacAtrium, the verified route is scripted:
`bash scripts/guest/speedometer402_setup.sh --macatrium-ready scratch/perf_NAME`.
It uses slower typing and saves stage screenshots, leaving Run Set unstarted.
Exit zero confirms delivery only: visually verify `setup_ready.png` has all
ten tests selected at one iteration before starting timing. Never run this
script from an arbitrary application state or during a benchmark.

Clean-disk sequence verified visually: allow boot to reach MacAtrium (30 seconds
was too short). After exiting to Finder, Mac7-5-5 is selected: Command-O, with
no extra Return. Type `appli` (not `app`, which selects Apple Extras), Command-O;
confirm Applications. Type `Speedometer 4`, Command-O; confirm Speedometer 4.02
Folder containing Machine Records, Speedometer 4.02, and SS_Athlon5000. Type
`spe`, Command-O, then wait for the splash before Return/Escape.

Return in Finder edits a filename; it does not open it. A root folder called
Speedometer containing Apps/images/metadata is accidentally renamed MacAtrium,
not the benchmark. Restore the disposable to recover. Ordinary selection/window
mismatches are navigation work, not proof of a crash: inspect and recover instead
of blindly typing more paths. Escalate persistent anomalies with a screenshot.

A hash verified before boot does not prove the disk remains clean after boot.
Cleanup is incomplete until MENU and a post-restoration matching hash are verified.
Explicitly transfer FPGA ownership when unable to finish the task.

Use a calculator/script for cycle deltas and percentages. Check OCR against the
image, especially 2 versus 5. Speedometer average is higher-is-faster. Follow the
assigned acceptance gate: an unchanged register loop does not veto a memory gain.

Actually view each completed screenshot before reporting a table; OCR alone has
repeatedly transcribed 2.397 as 2.597 and 3.315 as 3.515. If view_image fails
because of the filesystem sandbox helper, read the local PNG through an approved
`base64 -w0 <exact-path>` shell call with adequate output budget and pass the
returned string to the image helper as `data:image/png;base64,...`. Do not print
the base64 as text. If visual review is still unavailable, report the table as
unverified rather than silently accepting OCR digits.

## Mandatory hardware lifecycle guard

Use `bash scripts/cpu_benchmark_core.sh deploy LOCAL.rbf REMOTE.rbf SHA256`
and `bash scripts/cpu_benchmark_core.sh restore`, never ad-hoc core-load or disk
overwrite commands in test agents. Start with `--dry-run` before the mode to
validate local inputs. The guard fixes the host/fixture/Main hashes, rejects
ELF/non-RBF targets, preserves differing existing RBFs, requires Main restart
and the expected core marker, and verifies MENU before and after disk restore.
No invocation is allowed during a timed benchmark interval.

This is mandatory because a tester accidentally issued `load_core` against
`/media/fat/MiSTer` (an ELF executable), leaving the FPGA uninitialized and Main
exited. It also overwrote the disposable without verified MENU. Parent recovered
by loading the real menu.rbf through the platform loader and restarting unchanged
Main. That incident is an automation failure, not a CPU benchmark failure.
If the guard fails, return the actual error to Astra; do not invent recovery
commands, disable checks, rewrite Main, or try other files as bitstreams.

## Mandatory checkout identity gate

The environment may still default to the old `wombat33_MiSTer` checkout after
work has moved to `MacQuadra800_MiSTer`. Never infer the test directory from the
agent's cwd or from the word "active". Every delegated command must set an
explicit absolute working directory. Before each test/build group, print its
resolved directory and assert the supplied CPU source SHA256; stop immediately
if either differs from the handoff. Use absolute RTL/payload/baseline arguments.
Report those identities with the actual exit status and result.

This caught a final-validation run against old CPU `7f688eff...` / AP `299cb36`
instead of the intended `16fc1cc1...` / AP `9ecf647`. Its passing tests and
36,762,676 corpus cycles were discarded, not treated as a candidate regression
or an acceptance result. Correct-checkout validation must be rerun.
