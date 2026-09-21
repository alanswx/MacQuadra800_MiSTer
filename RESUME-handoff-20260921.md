# HAND-OFF, refreshed — Quadra 800 state on 2026-09-21 evening

**Read this first.** It supersedes `RESUME-handoff-20260919.md` as the index
and reconciles three things that no single earlier note had in view: the
Ethernet work (done and released), two and a half days of CPU performance work
by another assistant (425 commits, 2026-09-19 to 09-21), and what is actually
live on this machine now, checked on 2026-09-21 at 18:19 EDT.

Everything below marked *verified* was looked at directly for this note, not
copied from a previous hand-off.

## 0. In one paragraph

Ethernet is finished and **shipped**: Dani merged both pull requests on
2026-09-19 and cut release `MacQuadra800_20260919` (build 11) with its Main.
Since then this checkout has been a CPU speed project: hardware Speedometer
Mix went from **0.925 to 1.313** (build "P120", five valid runs, *verified*
from `scratch/hardware_p120_20260921/run3_complete.png`: KWhetstones 1060,
Dhrystones 15,710), against a goal of 1.8 and a real Quadra 800 at 1.897. The
last Quartus flow, **P150, finished after the previous hand-off was written and
failed** (CPU clock -19.3 ns). Nothing is running. The uncomfortable fact nobody
has written down yet: **the fast CPU only fits with the CD-ROM and Ethernet
compiled out** (P120 is 39,814 ALMs = 95 % *without* them), so the speed work
and the shipped feature set are currently two different bitstreams.

## 1. What is live right now (*verified*)

| thing | state |
|---|---|
| Quartus | **nothing running.** Dozens of `q800-p*-fit-*` systemd user units are listed as `failed`: that is how the timing gate reports (`build.exit=1` "solely timing gate"), not crashes. `systemctl --user reset-failed` clears the list |
| P150 (`scratch/p150_routing_seed25_fit_20260921/`) | terminal 16:57. `build.exit=1`, source-after check clean, rbf produced (`edd7fa4a...` sha256) but **unusable**: setup **-19.298 ns on the 33 MHz CPU clock**, **-5.557 ns on the clk_sys->clk_ram crossing** (`sdram_beat32 r_addr -> a_ram`), 40,551 ALMs (97 %), 502/553 RAM blocks, with `CDROM_OFF` and `ETHERNET_OFF`. Worst paths are all `ap040_core mem_addr_q[7] -> epf_data[*]`: the P147 "cache response data" change put a cache response into the fetch queue in one clock. That is structural, not a seed problem. Do not deploy it |
| tracked RTL at HEAD (`693bd94`) | P109 core / P120 pipeline / **P147 cache**. P147 has now failed two fits (routing congestion, then P150). The last tree proven on hardware is commit **`a102f76`** (P120); HEAD differs from it only in `rtl/ap68040/rtl/ap040_cache.v` (+119 lines) and the `.qsf` |
| `.qsf` defaults at HEAD | **a development recipe, not the release recipe**: `SEED 25`, `CDROM_OFF=1`, `ETHERNET_OFF=1`, eleven `AP040_EXPERIMENTAL_*` / `AP040_PIPELINE_*` macros. `CLAUDE.md` still says "the qsf's default settings ARE the release recipe"; on this branch that is no longer true |
| git | branch `add-ethernet`, everything pushed to `alanswx/MacQuadra800_MiSTer`; untracked `worst_detail.txt`, `worst_paths.txt` at the root are P150 timing dumps (copies are in the P150 archive; they can go) |
| Dani's `upstream/add-ethernet` | **rebased**: our Ethernet commits are there under new hashes, plus four of his own on top (`483c94d` Main release, `7760352` gate docs, `5b9ad4d` `releases: MacQuadra800_20260919`, `6009aa7`). `git rev-list --left-right --count upstream/add-ethernet...HEAD` = 31 / 452. Do **not** merge or rebase blindly: see section 3 |
| MiSTer `10.3.89.233` | running **FM-7** (`_Computer/FM-7_new.rbf`) — someone else's session, leave it alone until it is free. Main is still `1d512b7a` (the DMA-guard build; Dani's release Main is newer, `fbb540c8`/`6919c21`). `config/MacQuadra800.CFG` = `40 00`, slot 0 = `QuadSquad8-pipeline-test-20260919.hda` (the disposable benchmark disk, last written 20:17 UTC); the networking disk `QuadSquad8.hda` is untouched since 09-19. `_Unstable/` holds 28 experiment rbfs (123 MB); `_Unstable/MacQuadra800.rbf` is Dani's build 11 (09-19 12:33). **SD card: 3.5 GB free, 99 % full** |
| FTP server on this box | still up as user unit `ftp-pub` (port 2121), unchanged |

## 2. The CPU work: where it stands

The other assistant's own notes are good and current up to P164; read, in this
order, `HANDOFF-20260921.md`, `HANDOFF-20260921-P162-AUDIT.md`,
`HANDOFF-20260921-P164-SCREEN.md`, `RESUME-performance-20260921.md`, then
`docs/PERFORMANCE_MEASUREMENTS.md` from line ~1380 on (the hardware ladder) and
`docs/P96_REAL_QUADRA_COMPARISON_20260920.md` (where the 1.897 comes from).
`RESUME-pipeline-goal-20260920.md` is a 2,092-line running log: search it, do
not read it.

Hardware ladder (Speedometer 4.02 Mix, five runs each, this box, 32 MB):

| build | median | note |
|---|---|---|
| Ethernet build 10 (09-19) | 0.925 | the CPU the Ethernet shipped with |
| P5 ... P39 | 1.006 ... 1.105 | pipeline increments |
| **P63, full feature** (CD + Ethernet in) | **1.129** | the last build with everything in; it missed timing |
| P64 dev and the next | 1.131, 1.133 | CD and Ethernet out from here on (the same CPU as P63 measured 1.122 without them, so removing them is not itself a speed-up) |
| **P120** dev (`a102f76`, seed 25) | **1.313** | 39,814 ALMs, CPU clock +0.273 ns, clk_ram +0.643, **HDMI -0.335** (video only). Not yet written into `PERFORMANCE_MEASUREMENTS.md`: the evidence is only in `scratch/hardware_p120_20260921/` |

Simulation-qualified and waiting for a fit: **P161 core + P151 shared-port
cache + P120 pipeline** (wrapper `scripts/cpu/fit_combined_forward_shared_port.sh`,
note `docs/P163_...md`); **P162** (FPU multiword read continuation, -0.39 % of
Whetstone cycles, root-audited in simulation); P164 screened, no gain, dropped.
Simulation cycle counts are not Speedometer predictions — the notes say so and
are right.

An invalid Speedometer timer still turns up now and then (one run in the
ladder: Towers 0.140 s, aggregate 1.410, correctly excluded). Item 2a of the
09-19 hand-off — a bad `Microseconds` reading rather than a skipped loop — is
still open and still the best explanation; nothing in the CPU work has
addressed it, it has only been filtered out of the averages.

## 3. The decisions that need a human

1. **Area.** P120 needs 95 % of the chip with CD-ROM (~3,000 ALMs) and
   Ethernet (~500-600: `sonic_mbx` was 402 plus the DMA arm and instruments)
   removed. A release cannot drop the CD (users install from
   it) and Ethernet has just shipped. Either the speed work now turns to area
   (the P151 shared cache port was aimed at RAM blocks, not ALMs), or there are
   two products (a "fast" build without CD/network), or the 1.8 goal is pursued
   knowing the result will not ship as it stands. Every further increment that
   adds logic makes this worse; P150 at 97 % is what the wall looks like.
2. **Which tree is the branch?** `add-ethernet` now means "CPU experiments with
   Ethernet compiled out". Suggested: leave Dani's `upstream/add-ethernet` as
   the Ethernet/release line, and move this work to a branch named for what it
   is (e.g. `cpu-speed`), rebased onto Dani's rebased history so the four
   release commits come along and the two lines can be compared. That rebase
   touches `MacQuadra800.qsf`, `files.qip`, `quadra800.sv` and the docs on both
   sides, so it wants doing deliberately, with a build check after, not as a
   side effect of a pull.
3. **P147 in the tracked tree.** Two failed fits. Revert
   `rtl/ap68040/rtl/ap040_cache.v` to its `a102f76` state (or promote P151
   in its place, per the P163 plan) before anything else is built, so HEAD is
   again something that has run on hardware.

## 4. Next actions, in order

1. Decide 3.3, then make HEAD buildable: either `a102f76`'s cache or the
   P161/P151 promotion, committed and pushed, **before** launching Quartus.
2. One fit at a time: P163 (`fit_combined_forward_shared_port.sh`). Check the
   RAM summary (the P151 port is meant to save ~20 M10K), CPU-clock slack and
   both crossings; the P150 numbers above are the ones to beat. If the
   `r_addr -> a_ram` crossing fails again, that is placement pressure on
   `sdram_beat32`, and it is the same handoff that item 2a suspects — record
   the margin every time.
3. Hardware only when the MiSTer is free (it is running FM-7 now) and from a
   fresh look at the screen. Five Mix runs, invalid ones reported and replaced.
   Then write P120 and the new result into `docs/PERFORMANCE_MEASUREMENTS.md`
   — P120's 1.313 is still only in scratch.
4. Before any of this ships: a full-feature fit (CD + Ethernet in), and the
   second-bus-master checks the Ethernet work added — `make tb_line_dma`, then
   on hardware at CFG `40 00` a ping soak and an FTP transfer with an md5
   (`RESUME-ethernet-20260919.md`). **None of the CPU builds since P63 has been
   run with Ethernet in**, and the memory path (cache, store buffer, line
   shortcuts) is exactly what both Ethernet bugs lived in.
5. Housekeeping: the SD card is at 99 % — 28 experiment rbfs in `_Unstable/`
   (archive the ones worth keeping to
   `~/mister/MacQuadra800_fixtures/mister_archive_*` as on 09-19, delete the
   rest); `systemctl --user reset-failed`; update the stale lines of
   `CLAUDE.md` ("the qsf defaults ARE the release recipe", the `.143` box, the
   Windows paths) or fence them as Dani's-machine-only.

## 5. Still open from 2026-09-19 (unchanged; details in `RESUME-handoff-20260919.md`)

- **Ethernet download speed**: 62.6 KB/s down against 227 KB/s up; the DMA
  engine is under 2 % of it; the leading hypothesis is Main's single thread
  blocking in the SD write. First experiment needs no build (download to a RAM
  disk). Dani's release may already carry changes here — read his `7760352`.
- **Invalid Speedometer timing** (2a), see section 2.
- The one Finder hang inside Shut Down at CFG `40 04`; CAS/TAS not bus-locked
  with a second master; the `Dbg` OSD switches still in the tree.
- This box's mrext has no mouse; `scripts/guest/vmouse.py`
  (`/media/fat/Scripts/q800tools/` on the MiSTer) plus `mister_ws.py` keys
  drive the guest. The other assistant's operator runs used the same route
  (`scratch/hardware_p120_20260921/` shows it).

## 6. Rules that still bind

- One Quartus flow on this machine at a time; tracked HDL/QSF/QIP/SDC frozen
  for the whole flow (the wrappers hash them before and after).
- Never load a core over a running guest; look at a fresh screenshot first;
  the MiSTer is shared (FM-7, ColecoAdam and other sessions use it).
- Simulation counts are differential evidence, not scores; hardware decides,
  five runs, invalid timers excluded and reported.
- Commit as work lands and push to `origin` (`alanswx/...`); nothing goes to
  Dani's repositories without the user saying so.
