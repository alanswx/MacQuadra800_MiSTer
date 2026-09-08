# Resume -- 2026-09-07: install #8 on the deadlock fix; block cache wired, built

Read `CLAUDE.md` first. **Everything is on `main` now** (user's
instruction, 17:25: no feature branches, linear commits). The whole
work/cd512 -> work/cache -> work/cpu chain was replayed onto main
(`fa4c08d` = AP68040 5aa596f on top of the block cache; `c805300` = the
tracer-off cache build's source). The branch names below are historical:
`../MacQuadra800_wt2` is now a detached checkout used as a build
directory, `../MacQuadra800_wt` still shows `work/cpu` only until its
Quartus run (the CPU build) finishes, then it gets detached at `fa4c08d`
and the work/* branches deleted. Hardware driving is delegated to an
Opus operator subagent (user's instruction); the brief is in this
session's transcript and summarised in memory `opus-operator-for-mister`.

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
  No `open_row` RAM in the map report. Deployed for install #9.
- **Release candidate (tracer OFF)**: work/cache 021de90,
  `scratch/MacQuadra800_cacherc_03f83c62.rbf`, md5 `03f83c62d92d997e…`,
  built 17:10: 37,939 ALMs (91 %), RAM 502/553, timing met, worst
  +0.250 ns (HDMI PLL), clk_ram +0.721, clk_sys +0.850, open_row
  uninferred. **Two-OS gate PASSED 18:42-19:23** (`scratch/gate_03f83c62/`):
  Mac OS 8.1 desktop at 150 s (not visibly faster to boot), clock 5:47 ->
  5:52 over the idle watch, mouse + keyboard OK, Shut Down in 25 s; A/UX
  3.1 multiuser desktop at ~4.5 min (no fsck, clean previous halt),
  `uname -a` = A/UX localhos 3.1 SUR2 mc68040, `shutdown -h now` to "You
  may now switch off" in 2 min 10 s. **Released as
  `releases/MacQuadra800_20260907.rbf`** (README row + section). Operator
  notes: menu driving under A/UX needs a black-inversion row probe and
  `--delay 0.05` (System 7 acceleration at 0.02);
  `scratch/gate_03f83c62/inv_probe.py` + `walk7.sh` work. **Folded in**
  (menu.sh centre + measured scale + MENU_DELAY, menuitem_probe inversion
  fallback, mac_shutdown measured scale); probe verified on captured
  frames of both guests, the drivers still owe a live run.
- **CPU bump queued**: branch `work/cpu` (worktree ../MacQuadra800_wt,
  67627ec) = work/cache + AP68040 5aa596f (Alan's Sep 3 dispatch/decode
  work; the user reports ~2x CPU, "close to a Quadra 605"). The user says
  Alan runs the CPU self-tests himself -- no self-tests, no gate sim:
  build and put it on the hardware. **First build (17:10-17:29) did NOT
  fit**: 42,251 ALMs needed / 41,910 (4264 LABs vs 4191). Map-report
  logic cells: `wombat_cpu` 31,667 -> **38,138 LC (+6,471, +20 %)** for
  Alan's 5aa596f; `scsi_cache` is 1,774 LC. Second attempt queued 17:33
  with area-directed packing in the qsf (QII_AUTO_PACKED_REGISTERS
  "MINIMIZE AREA", ALM_REGISTER_PACKING_EFFORT HIGH,
  PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION OFF; uncommitted, in
  `../MacQuadra800_wt`, log `scratch/build_cpu_area.log`). Packing changed
  NOTHING (4265 LABs needed, 17:47-17:58 build): the overrun is LUT logic.
  Third attempt 17:59: OPTIMIZATION_MODE "AGGRESSIVE AREA" +
  OPTIMIZATION_TECHNIQUE AREA (`scratch/build_cpu_area2.log`; timing is
  the risk, seed walk if it fits but fails). AGGRESSIVE AREA got to
  41,777 ALMs (100 %), 4221 LABs vs 4191 -- still no fit, and 100 % would
  have no routing margin. Cache tags trimmed on main anyway (17767e8,
  size_r 64->32 bits). **Decision 18:20: CDROM_OFF=1 measurement build**
  of main HEAD (Alan's CPU + cache, no CD path, tracer off, proven speed
  settings) in `../MacQuadra800_wt` (now a detached checkout of main;
  the CDROM_OFF flip is an uncommitted build-dir edit), log
  `scratch/build_cpu_nocd.log`. Purpose: Speedometer/Queens numbers for
  Alan's 2x today. **Built 18:39: `scratch/MacQuadra800_cpu_nocd_ecd5705e.rbf`**
  (md5 `ecd5705e67aa9fa6…`): 38,962 ALMs (93 %), RAM 487/553, timing
  met, worst +0.494 ns. **Measured 19:26-20:06** (operator; the user then
  took the controls and ran Speedometer too): Benchmark Mix average
  **0.361** (runs 2/3 identical; 09-01 baseline 0.231 = +56 %), CQD 0.317,
  FPU 0.250; boot to desktop 136 s. BUT vs the 09-02 release's only two
  recorded numbers it is ~3 % faster (Queens 1.534 vs 1.574, Bubble 2.648
  vs 2.754) -- the full table on `MacQuadra800_20260907` (same be0a662
  core + cache) is OWED to say what 5aa596f itself buys. First-run
  anomaly again: Sieve 0.494 s on run 1 only (like the −17,482 s Queens
  before) -- a first-pass timing bug to chase. Full write-up:
  docs/PERFORMANCE_MEASUREMENTS.md §9. The MiSTer was left LIVE at the
  Finder on ecd5705e with the user driving; shut it down before any deploy. Shipping Alan's core WITH the CD needs ~600 more ALMs
  freed somewhere (wombat_cpu is 38,138 of ~50,700 logic cells; the
  machine side is 25 %), or a smaller CPU option from Alan.

**SCSI throughput (user's analysis, 21:15; work landed 21:40, f878a6e):**
every hps_io transaction costs a Main_MiSTer main-loop pass and the core
paid it per 512-byte sector (`sd_blk_cnt` hard-wired 0). The cache's
platform side now works in aligned 8-sector groups: group fetch on a
miss into an absent group, two groups of read-ahead as 8-block reads,
fully dirty groups flushed as one 8-block write, per-sector valid as the
words land, quiet-gated single flushes for partial groups, and a miss into
a group in flight waits instead of refetching. CD slot single-sector
until the fork's CD path is confirmed (MB_CD). `io_blk_cnt` ->
`sd_blk_cnt` for slots 0/1/4 in MacQuadra800.sv (not sim-covered:
verify in the next build). Bench T9: 64 writes -> 8 transactions,
32 reads -> 7. NOT yet built or on hardware; the next cache build should
show a large install-throughput gain (the 9-12 MB/min bursts were
round-trip bound).

**Getting Alan's CPU to fit WITH the CD (user, 20:15: "WE NEED CD ON so
users can install").** Logic cells per block in the CD-on cache build
(c805300 map report): ap040_core 29,772 (old core; +6.5k with 5aa596f),
ap040_fpu 8,559, ncr53c96 6,086 of which cd_audio 2,936, scsi_cache
1,774, ap040_mmu 1,206, scc 1,112, ap040_muldiv 732, **pll_cfg (the
512x384 monitor option's PLL reconfig) 715**, sdram_beat32 613, dafb
561, easc 481, ap040_cache 588. Gap: ~30 LABs (~300 ALMs) with
aggressive-area synthesis, plus margin. Levers, cheapest first:
(1) all-area qsf settings incl. physical synthesis OFF -- build launched
20:18 in ../MacQuadra800_wt (`scratch/build_cpu_cd_area3.log`);
(2) `CACHE_CD=0` parameter on scsi_cache (the CD slot passes through,
its tags and mux leg vanish, ~250 ALMs; bench in flight);
(3) drop the 512x384 PLL reconfig (~360 ALMs) -- user decision;
(4) cd_audio ~1,500 ALMs -- the user wants CD audio, last resort. The
cache's disk write-behind is what made the install fast; keep it.
**(0) Framework switches, no core feature lost** (found 20:30, all
commented in the qsf): MISTER_DISABLE_YC (yc_out 458 LC, composite/
S-Video encoder) and MISTER_DISABLE_ALSA (alsa 400 LC, audio-over-HPS
for USB/Bluetooth) -- together ~450 ALMs, i.e. the whole gap; also
MISTER_DOWNSCALE_NN / MISTER_DISABLE_ADAPTIVE trim the scaler (ascal
2,873 LC + 4,369 regs) at cosmetic cost. Full per-entity table in the
transcript (c805300 map): ap040_core 17,608 own + FPU 8,559 + ALU 2,461
+ MMU 1,206 + muldiv 732 + cache 588 + regfile 412; iosb own 1,172;
ncr53c96 own 2,472; cd_audio 2,526; scsi_cache 1,755; ascal 2,861;
audio_out 1,629 (IIR 798, alsa 400); hdmi_osd 916; vga_osd 884;
pll_hdmi_adj 779; pll_cfg 715; sdram_beat32 613; dafb 561; easc 481;
yc_out 458; video_calc 416; scc 1,112 (4 UARTs ~780). The queued wt2
build (all-area + CACHE_CD_OFF) had YC + ALSA off added before it
started (20:33), and was moved to ff7f4b0 (20:52): **the 512x384 PLL
retarget now uses the framework's trimmed reconfig core
`sys/pll_cfg/pll_cfg_hdmi.v`** (Altera's core with unused features cut
out, same MODE/C-counter/START registers) instead of the generic
`pll_cfg` IP -- 715 -> ~300 logic cells for the same function (the HDMI
instance of the same module is 296). VIDEO_512_OFF stays available but
should no longer be needed.
**Build A result (20:18-20:45, all-area + physical synthesis off, CD on,
no trims): FITS at 41,430 ALMs (99 %), 500 RAM blocks, but timing FAILS
-0.348 ns (HDMI PLL domain).** So area synthesis alone gets there but
too dense for timing. Build B (wt2, trims + all-area) running from
20:46; build C (wt, same trims, OPTIMIZATION_MODE BALANCED / technique
BALANCED, duplication off) queued behind it -- pick whichever fits AND
meets timing with the most slack.
**Build B (20:46-21:11): FITS at 40,457 ALMs (97 %), 499 RAM, but HDMI
PLL domain -0.720 ns** (clk_sys +0.774, clk_ram +0.605, holds fine) --
worse than A despite 2 % less logic, so the all-area synthesis itself
hurts the framework's HDMI paths. Kept as
`scratch/MacQuadra800_cpu_cd_B_798ea37d_TIMINGFAIL.rbf` (never deploy).
**BUILD C (21:05-21:27) FITS AND MEETS TIMING: Alan's CPU + CD on.**
`scratch/MacQuadra800_cpu_cd_C_b882d3fc.rbf` (md5 `b882d3fce60b63fa…`,
source ff7f4b0 = main before the multi-block cache; qsf: OPTIMIZATION_MODE
BALANCED, technique BALANCED, register duplication off, CACHE_CD_OFF=1,
MISTER_DISABLE_YC=1, MISTER_DISABLE_ALSA=1; the trimmed PLL reconfig core
is in the source). 41,108 ALMs (98 %), 499 RAM, worst +0.343 ns (HDMI),
clk_sys +0.415, clk_ram +0.609, hold +0.158, open_row uninferred. NOT yet
on hardware: needs the two-OS gate + a CD boot/install check. **Build D (21:29-22:01, speed settings globally + OPTIMIZATION_TECHNIQUE
AREA on `emu:emu|quadra800:machine` only, same trims): also fits and
meets timing** -- 41,164 ALMs (98 %), 499 RAM, HDMI +0.214, clk_sys
+0.252, clk_ram +0.843; md5 `2d083f18…` (wt2 output_files). C has the
better worst-case slack, so C is the candidate. **Build E (22:01-22:21,
D's recipe on the multi-block cache f878a6e): does NOT fit** -- 41,481
ALMs (99 %), Fitter Error 170012. The multi-block groups cost ~320 ALMs;
to ride with Alan's CPU + CD they need a trim (the size-clamp compares,
the pf_first encoder, `idle_ctr`) or VIDEO_512_OFF for that build. The
session's Claude process died ~22:30 while the gate operator for C was
still shutting the old guest down (it never deployed C; the MiSTer stayed
on ecd5705e with the Special menu open and the button held). Resumed
2026-09-08 05:00; the operator was resumed with a button release.
**Gate on build C, partial (05:03-05:15, operator resumed then stopped
for the user's power-down):** old guest shut down cleanly (it had run
7.5 h unattended on ecd5705e, clock ticking); b882d3fc deployed and
md5-verified; Mac OS 8.1 from Quad Squad booted (menu bar ~135 s, full
desktop ~180 s with the CD auto-mounting); **the retail CD mounted and
its window opened with the correct 17 items -- the CD target reads
through the new CPU**; no bombs, no garbling. NOT done: the 5-minute
clock watch, Speedometer, A/UX, the CD boot. Slots left as found (.s0
QuadSquad8, .s1 FreshTest, .s4 retail ISO), one load_core used. The
user then took the guest (Apple System Profiler open at 05:16) and is
about to power the MiSTer down; a clean Shut Down first was requested.
Operator notes: the live shutdown pattern that works first time is
`click.sh 181 8 move` (Special's title centre), `mousebtn:left_down`,
`menu.sh item 172 104`, verify, `release`; mac_shutdown.sh's 0.008 s
event spacing dropped moves (fixed to 0.02, 0e6e135); mopen.sh's
give-up path leaves the button down (scratch script, avoid).
**Two CD icons on build C (user, 05:20):** the same disc mounted twice --
the Main fork's 60 s boot repulse re-inserts the CD when the guest has
read <= 8 data blocks (true with CACHE_CD_OFF: no read-ahead during the
ROM scan); the driver then mounts it again. Core-side fix: a mount pulse
for a same-size disc that is present and not ejected is ignored
(`cd_same_disc`, ncr53c96.sv). Not in build C/F; goes into the next
build. The fork's heuristic could also be retired now that the eject-
until-bus-reset fix makes the ROM CD boot work.
**Build F (05:05, wt2)**: main 9f6e528 (multi-block cache with the
group-limit trim) on C's recipe (BALANCED/BALANCED, duplication off,
CACHE_CD_OFF, YC + ALSA off) -- CD target ON. **Result (05:28): fits at 41,447 ALMs
(99 %), 499 RAM, but HDMI PLL domain -0.105 ns** (clk_sys +0.219, clk_ram
+0.756); the trimmed multi-block cache is +339 ALMs over C. Kept as
`scratch/MacQuadra800_cpu_cd_F_a8046eee_TIMINGFAIL.rbf` (never deploy).
**Seed walk launched 05:35**: builds G (seed 20, wt2) and H (seed 21,
wt) in parallel, both = main 344a7cf (multi-block cache + trim + the
same-disc CD guard) on C's recipe (`scratchpad/recipe_c.py`). Whichever
meets timing is the gate candidate; if neither, VIDEO_512_OFF (-360 ALMs)
is the next lever, or gate C (b882d3fc, no multi-block) as the CPU+CD
release and land multi-block later. **H (seed 21) did not fit at all**
(41,556 ALMs, "requires 4191 LABs"): the multi-block source is at the
device edge; seed variance is +-100 ALMs. **G (seed 20) did not fit
either** (41,627 ALMs, 4200 LABs). Decision 06:08: **gate C (b882d3fc)
now** as the CPU+CD candidate (operator launched, scratch/gate2_b882d3fc/).
**GATE PASSED 06:09-07:02 on all three checks** -- Mac OS 8.1 from disk
(desktop 151 s, CD mounted + readable, clock 5:25 -> 5:30, Speedometer
Benchmark Mix 0.360, clean Shut Down; TWO CD icons as predicted), A/UX
3.1 (desktop <= 263 s, uname = A/UX localhos 3.1 SUR2 mc68040, clean
halt), ROM CD boot (desktop <= 146 s, ONE CD icon, clean halt).
**Released as `releases/MacQuadra800_20260908.rbf`** (README row +
section, 1682d56). The MiSTer had been in the DiskIOTest core (the
user's benchmark) when the operator arrived; it sits at the CD halt
screen now with .s0 restored to QuadSquad8 (07:05). Operator notes:
menuitem_probe's inversion fallback read the teal desktop strip under
the Special panel as a highlight (threshold tightened to < 40, verified
on the frames); modifier keys need `down:56 sleep:0.3 raw:NN sleep:0.3
up:56`; `n` does not press "No" in Speedometer's save alert.
the multi-block cache is the next increment once ~400 ALMs are found.
Data-point build J launched 06:08 (wt2): multi-block source + C's recipe
+ VIDEO_512_OFF=1, seed 19 -- tells whether "multi-block instead of the
12-inch monitor mode" fits with timing. **06:50: the cache's tag bitmaps
are now sized to the largest slot and `CACHE_SMALL=1` gives 32/32/16
sectors** (halves the tag logic; found and fixed a flush-scan index
aliasing bug on the way, see the commit). Build K launched 06:50 (wt):
multi-block + CACHE_SMALL + C's recipe, 512x384 kept, seed 19 -- the
"everything" candidate. **K (07:07) FITS AND MEETS TIMING**: 41,124 ALMs
(98 %), HDMI +0.009 ns (met, razor-thin), clk_ram +0.697, clk_sys +0.824;
`scratch/MacQuadra800_cpu_cd_K_f8fc0806.rbf` (main 90cfa95 = multi-block
+ trim + CACHE_SMALL + the same-disc CD guard; Y/C + ALSA off,
CACHE_CD_OFF). Not gated. **User (07:10): keep Y/C, ALSA off is fine
(MT32-pi is unaffected: it is the user-port I2S `mt32pi` module; ALSA is
the Linux-side audio mix), and look for more savings.** Build L launched
07:17 (wt): K + Y/C ON + MISTER_DOWNSCALE_NN + MISTER_DISABLE_ADAPTIVE
(`scratchpad/recipe_target.py`) -- the user's target configuration.
**L (07:38) FITS AND MEETS TIMING: 41,181 ALMs (98 %), HDMI +0.171,
clk_sys +0.358, clk_ram +1.008** -- `scratch/MacQuadra800_target_L.rbf`
(main 43e5d09: Alan's CPU + CD + multi-block cache CACHE_SMALL + the
same-disc CD guard + 512x384; Y/C ON, ALSA off, scaler NN + no
adaptive, CACHE_CD_OFF, BALANCED, seed 19). **GATE PASSED 07:43-08:34** (`scratch/gate_L/`): Mac OS 8.1 desktop
<= 136 s, CD readable, clock 6:55 -> 7:00, 5.5 MB Finder Duplicate in
~29 s (~195 KB/s guest write; block-layer writes 4.5x the guest's), clean
Shut Down; A/UX desktop <= 282 s, uname OK, halt 188 s; ROM CD boot
<= 107 s, one CD icon, clean halt. **Released as
`releases/MacQuadra800_20260908_2.rbf`** (29b26aa) and **the recipe is
now the qsf default on main** (966d0cd) -- a plain `build_only.sh` from
main reproduces it. **The double CD icon is NOT the re-insert**: it
persists on the Quad Squad boot with the guard in (2 icons, Get Info
identical, SCSI ID 3), and is absent on the CD boot and under A/UX -- the
Quad Squad disk's extension set (a second CD driver?) is the variable.
Operator notes: modifier chords work at the DEFAULT 0.35 s pacing, not
at --delay 0.05; menu.sh item landed first time on Mac OS 8; A/UX's
Apple menu still needs hand-walking (click.sh lands on the separator).
Build M launched 08:45 (wt): main HEAD (engine diet + everything) with
the default qsf -- the reproducibility check and the next candidate. **M (08:58): fits at 41,085 ALMs (-96 vs L) but
HDMI -0.117 ns** (clk_ram +0.655, clk_sys +0.748) -- the HDMI-domain
slack swings +-0.15 ns with any netlist change at this density (L +0.171,
K +0.009, F -0.105, M -0.117). L stays the release. Seed walk of main
HEAD (dc9eebb: L's source + the engine diet + the group-flush fix)
launched 09:00: seed 20 in wt, seed 21 in wt2, default qsf otherwise.
**CD audio diet, final (07:50): 2,936 -> 2,566 LC (-12.6 %), regs 938
-> 852** -- divider share -34 (79d3e9b), 20-bit LBAs -297 (5f52240),
shared volume LUT -38 (3098ee3); all on main, engine suite 475,299
checks each time. Not worth doing: registering the BCD conversions
(CSE already shares them); nothing in the debug probes (unconnected).
The next real step down would be architectural: pre-build the AppleCD
TOC/subcode responses in the Main fork and drop the t2/t43/resp plane
builders (~800 LC) -- the user's call. These three commits are NOT in
build L (43e5d09); they ride in the next build.
**CD multi-block (user asked why not, 08:50):** the core is ready
(`MB_CD` parameter; bench passes with it on) but the Main fork's
`mac_cdrom_fill` zero-fills any request that is not exactly 512 or 2352
bytes, so CUE/CHD discs would read zeros in 4 KB groups (flat ISOs use
the generic path and are fine). Fork change written up in
`scratch/main_fork_cd_multiblock.patch.md` (loop the data-window fill
over the request's blocks); `MB_CD` stays 0 until it lands (847421e). The cache side is benched with MB_CD on in all
geometries. Found on the way (dc9eebb): a wholly dirty group whose scan
pointer sat mid-group was flushed as eight singles; it now flushes from
its base -- 64 sequential writes = 8 transactions in every geometry.
The ARM-side AppleCD response building the user conditioned on
precedent: the Main's `ide_cdrom.cpp` (read_toc, read_subchannel...)
serves ao486/Archie/CD32/CDTV, and the fork's Toolbox round-trip
(`mac_sd_service` op 2 = CDB in, op 1 = DataIn) is the transport to
reuse -- a legitimate ~800-1,200 LC move, awaiting the user's go.
**Double CD icon, corrected theory (08:45):** two DRIVER instances on
one target: since the ROM CD-boot fix (4e9bc9e, Sep 3) the ROM loads
the disc's own driver partition on a hard-disk boot and mounts the CD;
the System's Apple CD-ROM extension then mounts it again. Experiment
running (`scratch/cdicon/`): Quad Squad + Open Transport ISO (no driver
partition) on build L, and the retail ISO on the 20260902 release. **Test A result (08:55): ONE icon** with the Open
Transport disc on build L (`scratch/cdicon/05b_otdisc.png`) -- the
doubling needs the retail disc's own driver partition. Test B pending.
If B shows one icon on 20260902, the trigger is the eject-until-bus-reset
change: the ROM's scan now keeps the disc, reads its driver map and
installs the disc's driver on a hard-disk boot, and the Apple CD-ROM
extension mounts it again. Fix direction then: make the ROM-installed
driver and the extension see one drive (what a real Quadra does), or
keep the scan-time eject for non-boot passes. **Test B (09:05): the 20260902 bitstream shows ZERO CD
icons -- it predates the CD-slot strobe fix, the CD never mounted on it,
so it cannot date the doubling.** The operator's own finding is the
lead: `MAC_OS_8-1_RETAIL.ISO` is an Apple hybrid with TWO complete,
overlapping partition maps (512-byte and 2048-byte granularity) naming
the same HFS volume, plus Apple_Driver43, Apple_Driver43_CD,
Apple_Driver_ATAPI and Apple_Patches; the OT disc has one map and no
drivers. Our target serves the disc in both block sizes (the ROM scan
switches it to 512, the extension uses 2048), so two enumerations can
each discover that volume. QEMU golden run launched 09:12
(`scratch/qemu_hdboot/`, WSL `~/qemu-work/vm3`, log `~/qemu-work/qemu3.log`):
Mac OS 8.1 hard disk (hd2 copy, id 6) + the retail ISO (id 3): icon
count + the ROM/extension command sequence to id 3. The MiSTer was left
with the 0902 core loaded (halt screen); reload from the halt screen
before any hardware work. **RTL fact (09:15):** `cd_blk512` (the CD's 512-byte
block mode set by MODE SELECT) is cleared only by machine reset, not by
a SCSI bus reset (ncr53c96.sv ~1158 clears cd_ejected only). A real
drive reverts mode parameters on a hard reset. The ROM's scan sets 512,
resets the bus, scans again; on ours the disc stays at 512 for the
extension too. Whether that is the doubling depends on the ROM/extension
sequence -- see the QEMU trace. If reverting is right, the ROM must
re-send MODE SELECT after the reset (QEMU refuses 512 mode entirely and
still boots the CD, so the ROM copes with 2048). **QEMU VERDICT (09:25, `scratch/qemu_hdboot/`, WSL
`~/qemu-work/qemu3.log`/`qemu4.log`): ONE icon.** Same HD image (8.1
installed) at id 6 + the retail ISO at id 3: the ROM runs its full
driver-load twice (two 1..8 map walks) and the OS driver once more, ALL
reads are 2048-byte multiples, and QEMU REJECTS every MODE SELECT to
the CD (two 8-byte, one 28-byte: CHECK CONDITION 05/26/00) -- the block
size never leaves 2048, the HFS partition is found at one block number,
one drive registered. Ours honours the MODE SELECT as the 512-byte
switch (9ff8a77); the ROM's post-MODE-SELECT reads then re-parse the
disc's second (512-granularity) map, find "Macintosh HD" at a different
block number, and register a second drive = two icons. The OT disc has
one map -> one icon. **Fix: refuse a block-length change (05/26/00)
like QEMU, keep 2048 always, still apply page 0x0E (audio control).**
T16h/T16j (512-mode tests) invert. The ROM CD boot never needed 512
(QEMU boots the CD at 2048); the eject fix was the real one.
Other savings still on the table: the printer port's UART pair (~390 LC,
if unused), the framework's IIR audio filter (798 LC, no switch -- a
framework edit, which the user is wary of), and a leaner core option from
Alan. **CD audio diet (user, 07:25: "shrink the CD Audio engine a
bunch")**: the fitter says cd_audio = 1,679 ALMs, 2,983 ALUTs, 938 regs,
8 DSP blocks -- the MSF->LBA multiplies and the audio multiplies are
already in DSPs (55 spare), so the LUT fat is (a) the LBA->M/S/F divider
STEP written out in six states (~600 ALUTs) -> one shared step
(79d3e9b; measured 07:30: only 2,936 -> 2,901 LC -- Quartus had already
merged the six copies, so the divider was NOT the fat); (b) thirteen
32-bit LBA registers
and their input muxes where a CD needs 20 bits (~450 ALUTs + 156 regs)
-> done (5f52240, 20 bits, measuring 07:39); (c) the three TOC/response
planes are MLABs (RAM made of logic cells, ~410 LC of the module's
children) -> M10K candidates. Build J (512x384-off data point) was killed at 07:23 after 67
min stuck in placement; wt2 is free for `--check` measurements. Build D queued (wt2): the qsf's
proven speed settings globally + `set_instance_assignment -name
OPTIMIZATION_TECHNIQUE AREA -to "emu:emu|quadra800:machine"` (area
synthesis only for our machine, the framework untouched) + the trims. Install #9 meanwhile
  passed the base Mac OS 8.1 package (where #8 died) and was installing
  the optional packages at 18:00.
- User's next topic after this: SCSI throughput ("our disks are REALLY
  slow") -- measure with and without the cache once it lands.
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

**QEMU verdict (16:45): the image is at fault, the RTL and ISO are clean.**
Same QEMU q800 + our ROM + the same ISO (id 3): a copy of `fresh_now.hda`
(id 1) fails with the character-for-character identical dialog after
50.76 MB of writes, 69 s after Start, with NO REQUEST SENSE ever sent
(so "no CHECK CONDITION" was never evidence against the RTL); the same
image with the volume erased first (Erase Disk, Mac OS Standard) installs
to "The installation process has finished" -- 169.65 MB written, LBAs up
to 1,024,094. `fresh_now.hda` carries a *blessed* partial System Folder
(drFndrInfo[0] = 18), so the installer takes its merge-into-existing
path and dies on the leftovers; clicking OK on the FPGA would have shown
a second dialog naming the item (Try Again / Skip / Stop). Logs:
`scratch/qemu_install/qemu_at_error.log` (failed, 21,952 lines) and
`qemu2_success.log` (79,728 lines) -- the byte-for-byte reference for
any future divergence. NB the QEMU trace prints the opcode in DECIMAL
(42 = WRITE(10)). The MDB "unmounted cleanly" bit is 0 on every image
captured while mounted, so it is not a corruption signal (correcting the
paragraph above). Both VMs are still up in WSL (`~/qemu-work`, monitor
sockets `/tmp/qmon` and `/tmp/qmon2`; helpers there) -- see memory
`qemu-golden-reference` for how to drive them.

**Install #9 (18:33): SUCCESS.** Pristine volume + block-cache build
61c31c4f: the base Mac OS 8.1 package completed (where #8 died), then
every optional package (Internet Access with its ten disk images, MRJ,
the four-disk archive set...) to "The installation process has
finished." -- `scratch/install9/43_flat.png`. 177 MB written, peak
11.7 MB/min (vs ~9 on the no-cache build; long read-only stretches
dominate the average). The operator quit the installer and shut the
guest down cleanly (`47_shutdown.png`). Two notes: (1) before the driver
warning the installer said "Problems were found with MacOS8-MiSTer that
cannot be fixed by this program" -- Disk First Aid does not verify the
machfs-formatted volume (something in `make_pristine_hda.py`'s output is
non-canonical; harmless here, but a guest-side Erase Disk is the
canonical fresh volume). MDB diff vs the Mac-formatted volume: machfs
writes drCrDate/drLsMod = 0, 8 KB extents/catalog B-trees with 8 KB
clumps (Mac: 1 MB / 1 MB), and drNmFls = 0 while drFilCnt = 3 (its
invisible Desktop DB/DF at root are not counted) -- that last one is
the kind of inconsistency Disk First Aid reports. Fix in
`make_pristine_hda.py` when the image is next needed: set the dates,
count the root files, or format in the guest instead. (2) `scripts/guest/menu.sh open` and
`scripts/mac_shutdown.sh` could not land on Special: `menubar_probe.py`
prints `OPEN <left> <right>` while its docstring promises a center, so
`menu.sh` aims at the RIGHT EDGE, and the fixed step never adapts. The
operator's adaptive opener `scratch/install9/mopen.sh` (right edge 212 =
Special) + `menu.sh item 172 104` + `release` works; fix menu.sh later.
Command-Q is ignored by the 8.1 Installer (use the close box). So: the deadlock fix + the block
cache install Mac OS 8.1 from the retail CD end to end on hardware; the
earlier "error occurred" failures were the poisoned target image.

Two experiments launched to split image-vs-RTL (both have answered):
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
