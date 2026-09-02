# Resume prompt — Alan's CPU/SDRAM speed-ups merged and released (2026-09-02)

Paste this as the opening message of a new session. Repo on `main`; the
release is `releases/MacQuadra800_20260902.rbf` (commit after `e8eebe9`).
`CLAUDE.md` now holds the standing rules and commands; read it first.

## What happened this session

1. **Merged Alan Steremberg's fork** (`alanswx/wombat33_MiSTer`, branch
   `cpu-sdram-handoff-seed15`; remote `alan` is configured, fetch over HTTPS —
   his SSH remote is not readable from this machine). Two merge commits:
   `e744dde` (the eight-commit branch: related-clock handoff, BL8 open-page
   SDRAM, retained line served through registered paths, AP040 line-assist
   fill, two-entry store buffer) and `e8eebe9` (his follow-up: store-hit
   data-cache update + exception-format decode refactor, seed 19). The
   `rtl/ap68040` submodule now points at `alanswx/AP68040` `be0a662`.
   Conflicts were cosmetic only (release table, qsf file list, one header
   comment, Makefile tail). Code review notes are in the merge messages; the
   SDC uses `derive_pll_clocks` and `sys_top.sdc` groups every `*|pll|*`
   output together, so the negedge-`clk_ram` handoff really is timed.
2. **Built** at seed 19: +0.420 ns setup / +0.195 ns hold (worst = HDMI PLL
   domain; `clk_sys` +1.138, `clk_ram` +0.916), 85 % ALMs, 19.5 min flow.
3. **Verified** — Verilator: `tb_sdram` 45/45 (0 chip protocol errors),
   `tb_wombat_bus32` 6/6, `tb_store_buffer`, `tb_memory_path*` (52 MB/s),
   `tb_ncr53c96` 6556/6556, `tb_easc` 18/18, AP68040 `tb_ap040_cache_snoop`
   (T10 + T11). Full-machine gate sim on `gate-emu.hda` scored against the
   silicon oracles (recipe below). Hardware: A/UX 3.1 and Mac OS 8.1 both boot,
   take input and shut down cleanly on the release bitstream.
4. **Released** as `MacQuadra800_20260902.rbf` (md5 `91cf5d72…`), README
   row + section written. **Not pushed** — `main` is ahead of `origin/main`.

## The one finding worth remembering — mmu_full sim diffs are pre-existing

The gate run's `mmu_full` suite reports **13 REAL diffs** (stores to a
write-protected / invalid page complete with vec 0 instead of faulting with
vec 2; the root descriptor's Used bit is never set; two data windows differ).
`RESUME-disk-gate.md` records that suite as clean. It is **not** a regression
from the merge: I rebuilt the sim at the pre-merge base `f9767d8` and at the
first merge `e744dde` and both reproduce the identical 13 diffs. Something in
the harness or an earlier core change (SCC/SCSI work? fastboot ROM? the
`gate-emu.hda` re-blessing?) is behind it. Worth a bisect on its own some day;
it does not affect the two OSes on hardware.

## Gate-sim scoring recipe (works, ~45 min per run in WSL)

```
bash scripts/sim_wsl.sh build                       # ~/MacQuadra800, builds Vemu + ROM hexes
bash scripts/sim_wsl.sh disk ../wombat33_MiSTer.ORIG/scratch/gate/gate-emu.hda
wsl -e bash -lc 'cd ~/MacQuadra800/verilator && (setsid nohup ./obj_dir/Vemu --headless --no-cpu-trace +rom=quadra800-fastboot.rom.hex --disk run.hda > sim_run.log 2>&1 &)'
# done when the [HB] pc parks at 000400FA and io_wr lba has passed ~2837
wsl -e bash -lc 'dd if=$HOME/MacQuadra800/verilator/run.hda of=/mnt/c/.../scratch/gate_sim/results.bin bs=512 skip=1398 count=2048'
cd SingleStepTests
python gen/split_allinone_results.py ../../wombat33_MiSTer.ORIG/scratch/gate/quadra800-allinone.hda.manifest.json ../scratch/gate_sim/results.bin ../scratch/gate_sim
python gen/score_vs_oracle.py cpu results/allinone/cpu_hardware_quadra800_2026-08-28.jsonl ../scratch/gate_sim/cpu.jsonl   # etc; mmu_full scores as `mmu`
```

Expected: cpu 717 rows / 13,585 groups with the 2 known memory-indirect
diffs; fpu 270, saverestore 8, integration 1328 clean; mmu_full 13 (see above).

## Hardware driving notes that worked today

- Deploy = `bash scripts/deploy_screenshot.sh` (pushes to `_Unstable`,
  `load_core` via `/dev/MiSTer_cmd`). Switch guests by rewriting
  `/media/fat/config/MacQuadra800.s0` (1024-byte NUL-padded relative path)
  and sending `load_core` again — only when the screen shows the halt dialog.
- A/UX: `scripts/guest/menu.sh open 20` opens the Apple menu; the `item` verb
  mis-probes A/UX's panel, so step by hand (`mouse:0,4` × 30 at 0.05 s reached
  CommandShell from the title), screenshot, then `mousebtn:left_up`.
  `scripts/guest/type.sh -r 'shutdown -h now'` halts it. Type one command per
  call and let output finish — typing over a running command interleaves.
- Mac OS 8.1: `click.sh 181 10 move`, `left_down`, then `mouse:0,1` × ~60 at
  0.05 s lands on Shut Down (~1.5 px/event today); verify, then `left_up`.
  `shutdown_finder.sh`/`menu.sh open 181` open the menu but cancel on a
  geometry check — harmless, it releases on nothing.
- Windows: `bash.exe` on PATH is WSL's; run Quartus from
  `C:\Program Files\Git\bin\bash.exe` (PowerShell `Start-Process`, detached).
  A stray `quartus_fit.exe` can outlive the flow and block the next build's
  wait-gate — kill it.

## Next

- Push `main` when the user says so.
- Optional: bisect the pre-existing `mmu_full` sim diffs.
- Optional: run Speedometer on `QuadSquad8.hda` here to get our own numbers
  for `docs/PERFORMANCE_MEASUREMENTS.md` (Alan's are on his 7.5.5 disk).
