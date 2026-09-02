# MacQuadra800_MiSTer — working notes for Claude

Macintosh Quadra 800 core for the MiSTer FPGA (DE10-Nano). Authentic 33 MHz
68040 bus clock, AP68040 CPU (git submodule), 128 MB SDRAM main memory, DAFB
video, NCR 53C96 SCSI, Z8530 SCC, ASC sound, ADB via VIA. Boots Mac OS 7.x/8.1
and A/UX 3.1. The core was called `wombat33` until 2026-09-02; the internal
`wombat_cpu` / `wombat_bus32` / `wombat_store_buffer` module names are a
separate codename and are deliberately unchanged.

## Layout

| path | what |
|---|---|
| `MacQuadra800.{qpf,qsf,sdc,sv,srf}` | Quartus project. `MacQuadra800.sv` is the MiSTer `emu` top (CONF_STR, SDRAM/DDR3 glue, video out). Fitter seed and its history live as comments in the `.qsf`. |
| `files.qip` | the RTL file list (mirrored in the `.qsf`); add new RTL to **both** |
| `rtl/quadra800.sv` | the machine: address decode, service FSM, ROM overlay, retained-line fast paths |
| `rtl/wombat_cpu.sv` | AP68040 core + MMU + cache + store buffer wrapper |
| `rtl/wombat_bus32.sv`, `rtl/wombat_store_buffer.sv` | transaction→beat adapter; two-entry ordered RAM write queue |
| `rtl/sdram.sv`, `rtl/sdram_beat32.sv` | open-page BL8 SDRAM controller (99 MHz) and the 33↔99 MHz beat bridge with the retained 16-byte line |
| `rtl/iosb.sv`, `rtl/ncr53c96.sv`, `rtl/scc.v`, `rtl/via6522.sv`, `rtl/asc*.sv` | I/O |
| `rtl/ap68040/` | **git submodule** — the CPU. Remote is `alanswx/AP68040`. Do not edit in place without committing there first. |
| `verilator/` | full-machine Verilator sim (`sim.v`, `sim_main.cpp`) plus directed testbenches (`tb_*.sv`, targets in `verilator/Makefile`) |
| `SingleStepTests/` | CPU corpus benches |
| `scripts/` | build / deploy / hardware test tooling (see below) |
| `tools/misterdeploy/` | the reusable rbf push + `load_core` launcher |
| `releases/` | shipped `.rbf`s + `README.md` (table + one section per release) + `quadra800.rom` |
| `docs/` | design notes (`sdram-fast-path.md`, `PERFORMANCE_MEASUREMENTS.md`, `scsi/`, …) |
| `RESUME-*.md` | session hand-off notes; the newest is the one to read first |
| `BUILD.md` | full build/deploy/disk documentation — read it before touching hardware |

## Build

```bash
bash scripts/build_only.sh            # full compile, ~40 min, -> output_files/MacQuadra800.rbf
bash scripts/build_only.sh --check    # Analysis & Synthesis only (~13 min), no rbf
```

- Needs `scripts/local.env` (gitignored; from `scripts/local.env.sample`). It
  holds `QUARTUS_BIN`, the MiSTer host/key, and the seed paths.
- **Run it from Git bash**, not WSL. On this box `bash.exe` on PATH resolves to
  WSL's `C:\Windows\System32\bash.exe`; the build needs
  `C:\Program Files\Git\bin\bash.exe`. From PowerShell, launch it detached with
  `Start-Process` so a tool timeout cannot kill Quartus mid-fit.
- **Never run two builds at once** — they share `db/` and corrupt each other.
  `build_only.sh` waits for any running `quartus_*`; only pass `--no-wait` when
  you have verified nothing is running.
- Timing must be **met** (positive worst slack in `output_files/*.sta.summary`).
  The design sits at ~85 % ALMs with well under a nanosecond of slack; a
  failing fit usually wants a different seed, not a source change. Walk seeds,
  record the result in the `.qsf` comment block.
- After any array change, check the RAM Summary in the `.map.rpt` (see BUILD.md):
  an array falling out to registers costs tens of thousands of ALMs.
- `SCSI_TRACE` in the `.qsf` makes a **debug** build that hijacks the serial
  port. It must stay commented out for anything released.

## Simulation (WSL)

Verilator 5 lives in WSL (`wsl.exe -e bash -lc '…'`; the `Failed to mount I:\`
line on stderr is harmless).

```bash
# directed testbenches, from verilator/ (run on /mnt/c or synced tree)
make tb_sdram tb_wombat_bus32 tb_store_buffer tb_memory_path tb_memory_path_registered_first_miss tb_ncr53c96 tb_easc
# full machine sim: sync sources to ~/MacQuadra800 (ext4), build Vemu + ROM hexes
bash scripts/sim_wsl.sh build
bash scripts/sim_wsl.sh disk <image.hda>      # writable copy
bash scripts/sim_wsl.sh run [args] ; bash scripts/sim_wsl.sh log [pattern]
# CPU self-tests (iverilog + vasm), inside the submodule
sh rtl/ap68040/tb/run_tests.sh
```

`tb_memory_path_registered_first_miss` is the variant that matches the shipped
quadra800 architecture. `tb_sdram` models both SDRAM ranks and reports chip
protocol errors; any change to `rtl/sdram*.sv` must keep it at zero.

QEMU (`qemu-system-m68k -M q800`, built from `../qemu` in WSL) boots the exact
ROM + A/UX disk and is the golden reference for SCSI/ESP behaviour.

## Hardware (the MiSTer)

Target is the DE10-Nano at the address in `scripts/local.env`
(`192.168.99.143`, ssh key `~/.ssh/mister_only`, mrext remote on `:8182`).

```bash
bash scripts/deploy_screenshot.sh       # md5-verified scp + load_core (refuses a timing-failed build)
bash scripts/grab.sh out.png            # screenshot (grab_fresh.sh fails loudly on a stale frame)
python scripts/mister_ws.py raw:<kc> …  # keyboard/mouse injection (see its docstring)
bash scripts/mac_shutdown.sh            # Mac OS: Special -> Shut Down from the host
bash scripts/guest/shutdown_finder.sh   # same, screenshot-verified menu walker
```

Disks live in `/media/fat/games/MacQuadra800/`: `QuadSquad8.hda` (Mac OS 8.1),
`HD60_512-AUX3.1-Installed.hda` (A/UX 3.1), `boot.rom`, and `backup/`.
Slot 0 is chosen by `/media/fat/config/MacQuadra800.s0` (rewrite it to switch
guests before a `load_core`).

### Binding rules — these have cost real data and whole sessions

1. **Never `load_core` / deploy / reset while a guest is booting or running.**
   It yanks a mounted, writable HFS volume. Only deploy when the screen shows
   "You may now switch off your Macintosh safely" or the MiSTer menu. If the
   state is unknown, look first (`grab.sh`) and ask.
2. **Judge guest liveness by `/proc/$(pidof MiSTer)/io` `write_bytes` deltas
   and the menu-bar clock, never by the `.hda` mtime** (main holds the image
   open; mtime is the last close).
3. **Never restart the mrext remote service under a running core** — main does
   not hot-plug input; remote keyboard/mouse goes dead until the next
   `load_core`. Silence then says nothing about the guest.
4. **Always send an explicit `mousebtn:left_up` after any guest-menu
   operation**, and never let `menu.sh` / `click.sh` be killed by a timeout
   with the button down — a held button wedges the Finder in a menu track and
   looks exactly like a hung CPU.
5. **Hash or back up a disk image only after a clean guest shutdown** and
   after the core has released the file. A mounted image's md5 means nothing.
6. Do not `push_disk.sh` from the NAS to "refresh" — the MiSTer's image is the
   authoritative base.

### Regression gate before any release

Both guests must boot to a responsive desktop and shut down cleanly on the
candidate bitstream:

- **Mac OS 8.1** (`QuadSquad8.hda`): Finder desktop, keyboard + mouse respond,
  menu-bar clock ticks at idle for several minutes, Special → Shut Down reaches
  the "safe to switch off" screen.
- **A/UX 3.1** (`HD60_512-AUX3.1-Installed.hda`): boots through to the
  multiuser Finder desktop (a long fsck after an unclean halt is normal),
  CommandShell responds, `shutdown -h now` reaches "You may now switch off".

Then: copy the rbf to `releases/MacQuadra800_YYYYMMDD.rbf`, add a table row and
a section to `releases/README.md` (md5, seed, slack, what changed, hardware
results), and commit.

## Conventions

- Commit messages: `area: what changed and why` in plain prose, like the
  existing history. Commit as work lands; don't batch a day into one commit.
- Documentation is part of the work: design notes go in `docs/`, hand-off
  state in a `RESUME-*.md`, measurements in `docs/PERFORMANCE_MEASUREMENTS.md`.
- `scratch/` is the gitignored working area for screenshots and logs.
- Git bash mangles absolute `/media/fat/...` arguments — export
  `MSYS_NO_PATHCONV=1` (the scripts already do). `ssh` without `-n` eats a
  piped script.
