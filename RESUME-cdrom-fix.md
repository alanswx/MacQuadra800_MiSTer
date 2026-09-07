# Resume -- 2026-09-07: install #8 on the deadlock fix; block cache wired, built

Read `CLAUDE.md` first. Worktrees: `../MacQuadra800_wt` = `work/cd512`
(f349e9e, the deadlock fix, tracer build 05ca079a deployed);
`../MacQuadra800_wt2` = `work/cache` = work/cd512 + the block cache.
Alan's CPU work stays PAUSED. Hardware driving is delegated to an Opus
operator subagent (user's instruction); the brief is in this session's
transcript and summarised in memory `opus-operator-for-mister`.

## Install #7 / #8 (the deadlock fix on hardware)

- #7 (previous session, build 05ca079a) was cut off by a MiSTer reboot;
  the target image held **64 MB** of "System Folder" / "Installer Temp"
  data -- far past the 6-7 MB where #5/#6 stalled, but not a completion.
- #8: same build, target `MacQuadra800FreshTest.hda` refreshed from
  `scratch/fresh_now.hda` (md5 8890a228…, 27 MB of earlier partial
  installs; there is NO pristine blank image anywhere -- creating one needs
  Drive Setup from the CD). Tracer capture started before the load_core.
  Result: see the "Outcome" line below (filled in when the operator
  reported).

## Block cache (`work/cache`, `docs/scsi-block-cache.md`)

- Rebased onto f349e9e. The T7 random-mix failure was a real race: a
  prefetch issued in the same cycle the engine decided to re-base completed
  after the window moved and marked its sector valid in the new window
  (slot 2 returned LBA 8's data for LBA 25). Fixed 9754dac together with
  the engine-write vs same-sector flush/prefetch same-cycle start.
- Quartus caught `mounted[2]` on a 2-bit vector (Verilator read it as 0
  silently); fixing it exposed the prefetcher collapsing to 1-2 sectors
  ahead (a hit re-armed it onto an already-valid sector, which stopped
  it) -- now it skips forward (65c75eb). tb_scsi_cache T1-T8: 237,584
  checks, 0 failures (T8 = the installer's write burst then CD reads).
- The "1-byte-short residual" on T16p was the bench: its read loop waited
  for DRQ before every single byte, and data-in DRQ needs two bytes in
  the FIFO (the last odd byte is left for the processor -- the ROM's
  16-bit PDMA pacing). Reading pairs per DRQ like T9 gives 2048/2048
  (work/cache 1d8821d, tb_ncr53c96 475,299 checks, 0 failures). The
  engine has no cross-target byte bug; the cache was never needed to
  hide one.
- Wired in `rtl/quadra800.sv` between iosb and the module ports
  (8db486c): 64/48/16 sectors = 64 M10Ks (fit before the cache: 430/553
  RAM blocks). `hps_busy` covers both sides.
- Full-machine Verilator boot was started twice and abandoned: the user
  asked to skip the slow sim and go to hardware. The Vemu build with the
  cache does compile (Verilator lint clean).
- **Built:** work/cache 65c75eb (+ bench-only 1d8821d), tracer ON, seed 19:
  `scratch/MacQuadra800_cache_61c31c4f.rbf`, md5 `61c31c4f0bdf96a1…`,
  22-minute compile. Timing MET, worst +0.277 ns (HDMI PLL), clk_ram
  +0.745, clk_sys +0.917, hold all positive. 39,803 ALMs (95 %; the cache
  is 1,108 of them, +1,093 vs the 05ca079a tracer build at 92 %), RAM
  503/553 (+64 = the store, inferred as one altsyncram of 524,288 bits).
  No `open_row` RAM in the map report. NOT yet deployed.
- Next: deploy it (after a clean guest shutdown) and run install #9 with
  the tracer, same procedure; then both-OS regression on a tracer-OFF
  build before any release. `work/cd512`'s qsf has `SCSI_TRACE=1`
  committed ON; comment it out for release builds.

## Outcome of install #8 (build 05ca079a, old image): ERROR, not a hang

Operator report (`scratch/install8/`, trace `scratch/install8_trace.txt`):
the install ran 15:24-15:57, cleared "Preparing to install", copied at up
to ~9 MB/min, and at ~83 % of the item bar ("Reading font: Helvetica" was
the last status) showed **"An error occurred while trying to complete the
installation. The installation has been stopped."** with a single OK.
wchar 56.0 MB. The trace has **no CHECK CONDITION at all** (118 disk + 159
CD statuses, all GOOD), no watchdog, no bus faults beyond the boot-time
slot probes; the last bus activity is CD READ, disk READ, disk WRITE(10),
then silence. After the dialog the disk still took ~48 KB of writes, so
the SCSI path was not wedged: the installer failed at the software level.

Post-mortem of the target (`scratch/install8_result.hda`, pulled while the
guest sat idle at the dialog; `scratch/hfs_installer_log.py` parses the
Apple partition map + HFS with machfs): no "Installer Log File"; the
Installer cleaned up -- `System Folder/ Installer Temp` is empty, free
space is back to 465 MB, catalog IDs advanced 322 -> 542 (about 220
files created and deleted). The volume is the same dubious lineage every
"error occurred" run (#3, #4, #8) used: its MDB "unmounted cleanly" bit
is CLEAR and the alternate MDB is stale (free 63742 vs 59637), i.e. it
never had a clean unmount since the yanked installs. NB: machfs reports
the volume name as "Untitled"; the MDB says "MacOS8-MiSTer".

Two experiments launched to split image-vs-RTL:
- **QEMU golden install** (Opus subagent, WSL): q800 + our ROM + the same
  ISO (id 3) + a copy of `fresh_now.hda` as scsi-hd id 1,
  `--trace scsi_req_parsed`. If QEMU installs, the RTL corrupts or
  mishandles something silently; if it fails the same way, the image/ISO.
- **Install #9 on hardware**: a genuinely pristine target
  (`scratch/pristine_500.hda`, md5 149fb642…, made by
  `scratch/make_pristine_hda.py`: the old image's driver descriptor,
  partition map and Apple_Driver43 partition + an empty machfs-formatted
  500 MB HFS volume named MacOS8-MiSTer) on the **cache build 61c31c4f**.
  If it succeeds both the lineage theory and the cache are confirmed in
  one run; if it fails, run #10 = pristine image on 05ca079a to separate.

---

# Resume — installer deadlock fixed; block cache in progress

**2026-09-03 afternoon.** The Mac OS 8.1 CD installer hang is root-caused and
fixed on branch `work/cd512` (worktree `C:/Temp/mistercore/MacQuadra800_wt`),
commit `f349e9e`:

- Symptom: installs stalled at "Preparing to install". The opcode/status SCSI
  tracer (build c18f0c8f) showed the CPU stall watchdog never fired and the
  LAST bus event was a disk WRITE(10) to ID 1 then a CD READ(10) select to
  ID 3 that hung in DATA IN (456 s of silence).
- Cause: the engine reports a write's GOOD status when its last block STARTS
  flushing; the ROM's SCSI Manager then selects the CD, cur_tgt switches to 2,
  and `io_ack_i = io_ack[cur_tgt]` stops watching slot 1, so the write flush's
  ack is lost, `flush_pending` wedges `io_busy`, and the next command
  deadlocks.
- Fix: `io_ack_i` follows `flush_tgt` (latched when io_wr rises) while a flush
  is pending. tb_ncr53c96 T16p reproduces the sequence; the CD read went from
  0 bytes/hang to completing. A 1-byte-short residual on that exact sequence
  is a WARN, subsumed by the block cache.
- Next: build `work/cd512` (queued behind another session's MacIIvi fit) and
  run install #7 on it. If it completes, cut a release-candidate (tracer off).

Block cache (the user's steer): `work/cache` branch, `ebe1c42`. A per-target
read-ahead + write-behind cache (`rtl/scsi_cache.sv`) so writes ack from RAM
and no flush is ever pending across a target switch. Directed tests pass
(tb_scsi_cache T1-T6b); the random multi-slot interleave (T7) has a coherency
race to finish; not yet wired into `quadra800.sv`.

---

# Resume — CD-ROM works on hardware; 512-byte block mode, 512x384, Alan's CPU in flight

Session of 2026-09-03 (morning). Read `CLAUDE.md` first. Repo `main` is at
the CD wiring fix; the rest of the day's work is on branches in a worktree.

## 1. The CD-ROM hang — root cause and fix (DONE, on main)

Both symptoms in `RESUME-cdrom-and-video.md` (grey boot hang with a disc in
slot 4, wedged Finder after an in-OS mount) had one cause, found by watching
the Main's file positions during a boot (`/proc/$(pidof MiSTer)/fdinfo/<fd>`
for the `.iso` and `.hda`): it never read a byte of either image.
`MacQuadra800.sv` built `sd_rd` as a packed literal that put the CD's strobe
at **bit 5** (the BlueSCSI CD-changer control slot) while the image, lba,
data and ack are on **slot 4**. Every CD read — the `cd_audio` TOC fetch that
fires on mount before the ROM sends anything — was answered on slot 5, the
core waited for `sd_ack[4]` forever, `io_busy` never dropped, and the next
SCSI transfer to any target hung. The sim never saw it because
`verilator/sim.v` instantiates `quadra800`, not `emu`: **nothing in
`MacQuadra800.sv` is covered by the full-machine sim** (now in CLAUDE.md).

- Fix: `a1680e8` — the strobes are assigned per slot by name.
- Build: `output_files/MacQuadra800.rbf` md5 `e34c700424e3e04e93c748f6294eb600`,
  seed 19, 86 % ALMs, timing met +0.184 ns (clk_sys +1.2, clk_ram +0.79);
  `open_row` confirmed uninferred (logic) in the map report. Deployed to
  `/media/fat/_Unstable/MacQuadra800.rbf`.
- Hardware: Mac OS 8.1 boots with the Open Transport disc armed in `.s4`
  and shows the CD icon on the desktop; the user rebooted and used it.
  The pristine-ROM sim with `--cd` also boots through the CD scan (the ROM
  reads block 0 of ID 3 as 4 HPS blocks, then boots ID 0).
- Watch item: after the first boot the hard-disk icon was garbled (stable
  garbage across redraws, everything else clean); it healed when an app
  launched and stayed clean after a reboot. Most likely a leftover from the
  morning's dirty resets. Not reproduced since.
- **Release gate still open for e34c7004:** A/UX 3.1 has not been booted on
  it yet (the user was using Mac OS on the box). Do the A/UX boot + clean
  shutdown, then the `releases/` row + section.

- **CD audio output (`92633ed` on main):** `cd_snd_l/r` were implicit 1-bit
  nets at the top level (Quartus warning 10236) so the engine's PCM never
  reached AUDIO_L/R; now declared and summed 1:1 with the ASC like MacLC.
  Not in any built bitstream yet — cherry-pick onto `work/cd512` after its
  running build ends, then rebuild. Audio needs a CUE/CHD disc (the Main
  fork serves the CD-DA frames) and the AppleCD Audio Player in the guest.

Permission note: the project allow-list matches exact command prefixes;
run `bash scripts/deploy_screenshot.sh` / `bash scripts/grab.sh <file>` bare
(no `export …;` prefix, no trailing pipe) or the auto-mode classifier gets
asked and may refuse. The classifier also refuses to let Claude edit the
permission settings; the user adds rules.

## 2. Worktree `C:/Temp/mistercore/MacQuadra800_wt` — two branches

- **`work/cd512`** (main + video + docs + block mode, CPU unchanged) —
  **built 06:34: md5 `2c275a61b3ca95384fb97f56b3f9d08a`, +0.244 ns, 87 %,
  open_row uninferred; copy at `scratch/MacQuadra800_cd512_2c275a61.rbf`.
  Not yet deployed (the user was in the guest).**
  - `bf371f4` video: "Monitor (on reset)" OSD option, 13" 640x480 or 12"
    512x384. Sense code 2, 640x407 frame at 15.664 MHz via MacLC's
    runtime-reconfigurable `pll_video` + `sys/pll_cfg` (static config stays
    the 13" divider; `pix_quiet` blanks ~84 ms on a retarget). Latched
    under reset like the RAM size; the user applies it with the OSD's
    "Reset and close OSD". `docs/video-modes.md`. **Untested on hardware.**
  - `9ff8a77` scsi: MODE SELECT block descriptor of 512 puts the CD in
    512-byte blocks (`cd_blk512`): READ unscaled, READ CAPACITY / MODE SENSE
    follow; survives a bus reset (MAME `nscsi_cdrom_device`). Needed because
    the Mac ROM and the Apple CD-ROM driver switch an AppleCD to 512-byte
    blocks to read the driver descriptor map. `tb_ncr53c96` T16h,
    9207/9207.
  - A full build of this branch was launched at ~06:17 in the worktree
    (`scratch/build_cd512.log` there). If it closes timing: deploy, regress
    Mac OS 8.1 at 640x480 with the CD, then try the **retail disc**
    (`games/MacQuadra800/MAC_OS_8-1_RETAIL.ISO`, Apple partition map, 420 MB):
    (a) in-OS mount from the HD; (b) ROM boot from it — unmount `.s0` (rename
    it away), `.s4` = the ISO, reload. Then switch the OSD monitor to 12",
    reset, check the Main's log for `Video resolution: 512 x 384`.
- **`work/side`** = the same three commits + `4f5e2f7` AP68040 submodule bump
  to Alan's `687a8da` (branch refill, operand retirement, DBcc). A gate sim
  on `gate-emu.hda` with that CPU is running in WSL (`sim_side.log`); when
  the `[HB]` pc parks at `000400FA`, score it per the recipe in
  `RESUME-cpu-merge.md` (`split_allinone_results.py` + `score_vs_oracle.py`;
  expected: cpu 2 known memory-indirect diffs, mmu_full 13 pre-existing).
  **Scored 06:40: exactly baseline** (cpu 2 known memind diffs, fpu 0,
  saverestore 0, integration 1328/1328, mmu_full 13 pre-existing); the
  on-screen `trap=3` is normal. Alan's seed note: 25.
- **Hardware on `2c275a61` (07:00-07:30):** Mac OS 8.1 boots from the HD
  with the Open Transport disc; the retail 8.1 disc mounts in-OS (its
  window opened); the user booted the ROM from the retail disc, 512x384
  works, and the installer ran — its "driver cannot be updated, not an
  Apple hard disk" dialog is the MODE SENSE page $30 check ("Ignore
  Warning" proceeds). `f0be8d7` on `work/cd512` adds the page to the disk
  targets (MAME hd.cpp layout; Drive Setup needs it too). Build launched
  07:32 (`scratch/build_cd512b.log`).
- **Installer stall (07:42):** on `2c275a61` the retail install froze at
  "Writing Text Encodings: Chinese Encodings Supplement" — screen static,
  no cursor on mouse moves, no HPS I/O. Not reproduced by the bench
  (T16j: 512-mode CD reads interleaved with disk writes, clean) and the
  ISO is complete. A `SCSI_TRACE` build of `work/cd512` was launched 08:10
  (`scratch/build_trace.log`; the qsf edit is local, do not commit it) —
  deploy it, re-run the install with `bash scripts/scsi_trace.sh
  --capture-only 600` running, decode.
- More on `work/cd512`: `bcd755e` CD audio mixed into AUDIO_L/R (build
  `1dd496a8`, +0.249 ns, 88 %, copy in `scratch/`); `9631e0f` T16j;
  `0158f55` the `CDROM` parameter / `CDROM_OFF=1` qsf macro that drops the
  CD target + audio engine (~2,800 ALMs) for Alan's CPU builds.
- **ROM CD boot found and fixed (`4e9bc9e` on `work/cd512`):** with no HD
  the tracer build and the pristine-ROM sim both ended at the flashing "?"
  after ~10 MB of the disc. QEMU booting the same ISO
  (`~/qemu-src/build/qemu-system-m68k -M q800 -bios quadra800.rom -drive
  file=cd_retail.iso,format=raw,if=none,id=cd,media=cdrom,snapshot=on
  -device scsi-cd,drive=cd,scsi-id=3 --trace scsi_req_parsed -D log`)
  issues the SAME sequence: the ROM's first pass ends with PREVENT/ALLOW
  (allow) + START/STOP LoEj (eject), a bus reset, then a second pass that
  reads the disc again and boots. QEMU/MAME keep the medium readable after
  that eject; we removed it. Now an eject lasts until the next bus reset /
  mount pulse / machine reset (T16k). The user's earlier "CD boot works"
  was presumably a HD boot; a real ROM CD boot had never passed.
  QEMU also rejects the driver's 8-byte MODE SELECT (ILLEGAL REQUEST) and
  the driver copes; we answer GOOD and ignore it, which is fine.
- **Hardware 09:07, tracer build `fffa1536` (= `1dd496a8` + CDROM gate +
  eject fix + SCSI_TRACE; timing met +0.245 ns this time):** with no hard
  disk mounted the ROM boots the retail 8.1 disc to the CD's Finder.
  First ROM CD boot ever on this core. The fixed pristine-ROM sim
  (`sim_cdboot3.log`) also gets the happy Mac at frame 4000 instead of "?".
  09:10-09:50: the retail installer, run from the CD-booted system onto the
  fresh disk at ID 1, ran past the earlier stall point (33 MB written and
  climbing) with the tracer capturing (`scratch/scsi_trace*.txt`).
- **Second install stall (09:48, tracer build fffa1536, CD-booted system,
  "Writing AppleScript", 35 MB written):** same class as the first; the
  tracer had gone silent at ~09:39 because DBG_BUDGET (4000 records) is a
  one-shot -- `66be88a` makes it refill every epoch; a rolling-tracer build
  was launched 10:07 (`scratch/build_trace3.log`). Bench cases that do NOT
  reproduce the stall: T16j (512-mode CD reads interleaved with disk
  writes), T16l (CD READ issued back to back after a disk WRITE with a
  3000-cycle device latency; `38ce5d5`) -- 27704 checks clean. Tracer
  refill is `8eee63a`; the first attempt double-drove dbg_left (Quartus
  10028) -- the refill must live in the block that owns the register.
- **Release candidate `85ba3d50`** (`work/cd512` @ `4e9bc9e` + tracer-off):
  timing met +0.183 ns, 88 % ALMs, copy in `scratch/`. Not deployed; needs
  both-OS regression and the install question answered first.
- **10:30 — rolling-tracer build `f55b6ee0` (+0.241 ns) deployed;** CD-booted
  with the fresh disk on ID 1; capture running (3000 s); an Opus subagent
  drives the installer via `scripts/guest/click.sh` + `grab.sh`, monitoring
  screen + `/proc/<pid>/io`, and reports COMPLETED / STALLED. Decode the
  capture with `scratch/scsi_decode.py`, then `scratch/epoch_summary.py
  decoded.txt 3` to see the last busy epochs before the silence.
- **`CDROM_OFF=1` measured (10:49):** 33,794 ALMs (81 %) vs 36,830 (88 %)
  with the CD path -- 3,036 ALMs, +0.250 ns. Alan's CPU (+3,900 on this
  base) fits at ~90 % with the gate on; with the CD in it is 96 %.
- **Traced install #3 (10:39-11:12, tracer `f55b6ee0`, CD-booted, target
  ID 1):** no stall this time; the installer FAILED twice with the generic
  "An error occurred while trying to complete the installation" right at
  "Finishing installation" (11:02:24 and 11:10:19 after Try Again), ~9 MB
  written per pass. Trace: no bus faults, no selection timeouts; the only
  distinctive record at both failure moments is a read of IOSB register
  block $50F183xx ("u F1 / n 83"), also seen at the "Updating Apple hard
  disk drivers" step -- i.e. Apple's disk-driver code runs right there.
  The tracer cannot show opcodes (CDBs go through PDMA). Hypothesis: the
  driver code issues hard-disk commands we rejected with ILLEGAL REQUEST
  (MODE SELECT on a disk, VERIFY, SYNCHRONIZE CACHE, FORMAT UNIT...), which
  MAME/QEMU disks accept. Added (`work/cd512` top commit, T16m). Tracer
  build with it launched 11:25 (`scratch/build_trace4.log`); next: deploy,
  CD-boot, run the installer again (Opus was 529-overloaded twice; the
  Sonnet operator brief in this session worked well). The install target's
  volume looked sane (HFS 500 MB, driver partition, System Folder from the
  partial installs).
- **Install #4 (11:43-12:11, tracer `40a09f76` with the disk command set):**
  FAILED again with the same generic dialog, now mid-copy at "Reading
  ColorSync Profile" (12:02:01) and, after Try Again, at "Reading Control
  Panel: Desktop Pictures" (12:09:19); counters moving until each error;
  the "not an Apple hard disk" warning still appeared. So neither the
  command set nor a fixed step explains it; it looks like an I/O error on
  a CD (or disk) transfer. The tracer could not show opcodes/status, so
  ncr53c96 now has taps and the tracer records D/d (opcode, disk/CD) and
  Y/y (status byte) per epoch; decoder updated (`scripts/scsi_trace.sh`,
  local copy `scratch/scsi_decode.py`). Tracer build with the taps
  launched 12:20 (`scratch/build_trace5.log`). Next: deploy, CD-boot,
  operator runs install #5 with capture; look for "Y 02"/"y 02" in the
  failure epoch and which opcode preceded it.
- **Install #5 (12:39-13:01, tracer `9d641bc0` with opcode/status records):
  STALLED at "Preparing to install" right after Ignore Warning. THE TRACE
  NAMES IT: the last busy epoch (144, ~12:55:29) ends with `D 2A` = a
  WRITE(10) executed by the DISK target with no status byte ever returned;
  the CD READ(10) and disk READ(10) just before it completed GOOD; 45
  silent epochs follow; the Main's counters are flat (no HPS request
  pending), so the hang is inside the target's DATA OUT handshake, not in
  the HPS path. Fits stalls #1/#2 (both during "Writing" steps). Working
  hypothesis: a multi-block WRITE(10) driven as ONE long DMA TI (the Mac
  OS SCSI Manager style) starves DREQ after the first block's flush --
  the bench only ever wrote in the ROM's 256-byte TI chunks (T14/T15/
  T16j/T16l). Files: `scratch/scsi_trace_stall5.decoded.txt`,
  `scratch/find_check.py`, `scratch/epoch_summary.py`.
- **ROOT-CAUSE CANDIDATE for the installer stalls/errors (13:2x):** the
  SCSI engine is clean under stress (T16n single-TI 4-block write on a
  3000-cycle device; T16o 80 random rounds of CD READ / disk READ / disk
  WRITE with random latencies and pacing -- 475k checks). What no bench
  models: the CPU's pseudo-DMA beat waits for DREQ while the target waits
  for the Main, whose O_SYNC 512-byte writes hit SD-card housekeeping
  stalls of 100s of ms; the IOSB escape (2^18, 7.9 ms) is frozen while a
  strobe is up but the core-side `ap040_bus_timeout` (2^21 = 63 ms) in
  `wombat_cpu.sv` is not -> bus error inside the SCSI Manager's DMA loop
  -> hang or "An error occurred", writes only. Its fault never reached the
  tracer (B records come from quadra800's S_BERR only). Fix on
  `work/cd512`: `.req(mem_req && !stall_hold)` with `hps_busy = |io_rd |
  |io_wr | |io_ack` from quadra800, COUNTER_BITS 24, and a tracer "W"
  record when it fires. Tracer build launched 13:2x
  (`scratch/build_trace6.log`); next: deploy, CD-boot, install #6.
- **Release candidate #2 `52ca7ee4`** = `work/cd512` @ `bc1769b` (disk
  command set) with the tracer off: 88 % ALMs, hold +0.234 ns worst, open_row
  uninferred; copy `scratch/MacQuadra800_cd512e_52ca7ee4.rbf`. Supersedes
  `85ba3d50`. Deploy this one for the regression gate once install #4 (on
  the tracer twin `40a09f76`) has answered the installer question.
- **Alan's CPU work PAUSED by the user (10:55):** the `work/all2`
  (= `work/cd512` + bump) CDROM_OFF build was killed mid-fit and nothing
  more is to be done on it until asked. Branches `work/all` / `work/all2`
  stay for later.
- **`work/all`** = `work/cd512` + the CPU bump (`fbf2706`), i.e. everything.
  Full build launched 06:42 in the worktree (`scratch/build_all.log`).
  Candidate for main once both OSes pass on it.

Merging: `main` ← fast-forward to `work/cd512` once its build passes on
hardware, then `work/side` on top once the CPU scores clean and builds.

## 3. What the ROM sends a bootable CD (sim in flight)

`~/MacQuadra800/verilator/sim_cdboot2.log` in WSL: pristine ROM,
`--disk blank.hda` (a file that does not exist, so ID 0 stays unmounted —
a bare `--cd` run never mounted the disc at all, `sim_cdboot.log`) and
`--cd cd_retail.iso`. The real ROM spends ~20 min of sim in its memory test
before the SCSI scan. Grep `[NCR` lines (drop `io_ack`/`INT+`) for the CDB
sequence at ID 3: look for a `15` (MODE SELECT) before the `08` reads — that
is the 512-byte switch the block mode exists for. QEMU's q800 note: its
`scsi-cd` refuses the block-size change yet boots Mac OS from CD, so the ROM
may have a 2048-byte path too; the sim will show which it uses here.

## Hardware state at hand-off

MiSTer runs build `e34c7004` with `QuadSquad8.hda` on slot 0 and the Open
Transport ISO on slot 4 (`config/MacQuadra800.s4`; the old `.s4.off` copy
is still there). Mac OS 8.1 was at the Finder with the user driving it.
Main fork is installed (md5 `0783ef1a…`), started with nohup, log at
`/media/fat/nohup.out`.
