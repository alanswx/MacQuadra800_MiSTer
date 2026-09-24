# RESUME — CPU speed, 2026-09-23 (supersedes RESUME-cpu-speed-20260922b.md)

Goal unchanged: Speedometer 4.02 Benchmark Mix ~1.9 on the MiSTer (real Quadra 800: 1.897,
`docs/perf/real_quadra800.jpg`). User's ruling: 1.9 first, then area (CD-ROM + Ethernet back).
User on 2026-09-23: "keep going until we hit 1.9".

## Hardware ladder

| build | Mix | note |
|---|---:|---|
| P174 (`c152ac4`) | 1.460 | one-clock instruction hit |
| P182 (`122dab4`, seed 24, lite) | 1.467 | Whetstone flat: store-drain bound |
| P188 (`f64a2d1`, seed 24, dev) | **1.631** | posted-write path + P184 (P175-P178 back, the P178 hang fixed); 8.1 boots on silicon |
| P193 (`970b98c`, seed 25, dev) | **1.646** | LEA/LINK/UNLK/JSR dispatch, MOVEM hint, one-clock FPU shift |
| P197 (`c4a3522`) | fitting | byte-lane cache arrays (P195b), read-after-store handoff (P196), FPU/PEA dispatch |

Gap at P193: 0.251, Whetstone 0.20 of it (69 % of real).  Int. Matrix/Sieve lost ~1 % on hardware at
P193 while the fixtures show them unchanged -- a hardware-only effect, not chased.

## The finding that reorders everything: Whetstone is store-drain bound on hardware

- The kernel fixtures' RAM model is fixed-latency and optimistic.  Whetstone with separate read/write
  latency (`scratch/p184_merge/tb_cpu_whetstone_wl.sv`, `+wlatency=`): read latency 3->8 is +0.4 %,
  **write latency 3->8 is +39 %**.  The data cache is write-through (a real Quadra runs copyback), so
  every one of ~2.4M stores per loop drains to SDRAM.  P174->P182 on hardware matched the fixture only
  at the high write latency.
- A store cost ~6 clk_sys on the platform path (store buffer -> wombat_bus32 -> service FSM S_MEM ->
  bridge -> registered acks back), whatever the SDRAM did.
- **P185/P186/P188** (`docs/P185_POSTED_WRITE_PATH_20260923.md`): an eight-entry write FIFO in
  `sdram_beat32` drained back to back on clk_ram; quadra800 pushes store-buffer RAM writes straight
  into it (`DIRECT_WRITES`, `bus_wr_direct`, acknowledged through `bus_miss_ack`); the store buffer
  drains back to back.  tb_line_dma: 4,096 stores 24,576 -> 9,712 clocks, 0 errors (with SONIC DMA,
  sized stores, a negative control).  **Projected Whetstone -17 % on hardware.**
- The full-machine sim (`verilator/sim.v`) acknowledges RAM in one clock: it cannot show memory-path
  effects at all.  The bridge benches (`tb_sdram`, `tb_memory_path*`, `tb_line_dma`) are the ground
  truth for the platform side.

## CPU work landed today (sim, all oracles pass)

- P179-P182 (above).  P184 (`docs/P184_P175_P178_ON_P182_20260923.md`): P175b/P177/P175c/P178 back on
  top, with **the P178 hang fixed** (the cross-line hit's next-row pair read had no same-clock write
  check: `idle_next_valid`) and P175b's Int. Matrix/Sieve regression fixed (hinted fetches leave the
  data banks on the data hint in their first clock).  Both P178 boot configurations that crashed now
  boot to the Finder in the full-machine sim (`scratch/sim_p184/run81{b,d}`).
- P187: a spanning store (2-mod-4 stack longword) captures its merge words so the next read keeps its
  idle read (Whetstone -1.6 % with fast stores).
- P184 vs P182 fixtures (lat 3): Permutations -9 %, Puzzle -8 %, Dhrystone -6 %, Towers -4 %.

## Fits

| fit | ALMs | CPU clock | note |
|---|---:|---:|---|
| P179 seed 24 lite | 39,113 | -3.153 | not run |
| P182 seed 24 lite | 39,229 | -0.718 | measured 1.467 |
| P184 seed 24 lite | 39,567 | — | routing FAILED |
| P186 seed 24 **development** profile | 38,505 | -1.722 | clk_ram->clk_sys crossing -1.369: not run; fixed in P188 |
| P188 seed 24 development profile | | | fitting at hand-off (`q800-p188-fit-20260923`) |

Dev fits now source `configs/cpu_development.tcl` (OSDs, audio out, Y/C off too).  After every fit
check `scratch/<tag>_fit_*/cross.log` (the bridge crossings), not only the .sta summary.

## Fixtures and tools

- `scripts/cpu/speedometer_suite.sh <tree>`: Towers, Puzzle, Quick, Int. Matrix, Sieve, Bubble with
  oracles and negative controls (about a minute).  Whetstone/Dhrystone/Permutations/Queens runners:
  copies in `scratch/p187_span/` (`run_whetstone_wl.py` takes `EXTRA_PLUSARGS=+wlatency=N`).
- Probes worth reusing (`scratch/p186_sb/tb_wf.sv`, `tb_w.sv`): memory-visit histograms (MHIST),
  slow reads by issuing state/opcode (MSLOW), why a hinted read missed the one-clock hit (WHY), the
  cache state while a read waits (WST/WIDLE), per-PC clocks in the SANE add wrapper (PCX).
- Hardware runs: an Opus agent with the P182 prompt (this session) works; `mister_ws.py` mouse
  commands are refused by this box's mrext, so shut down with `/media/fat/Scripts/q800tools/vmouse.py`
  and screenshots.  Speedometer Command-B = keycodes 56 + 48.

## Later on 09-23 (after this file was first written)

- P189-P193: MOVEM predec store hint, LEA d16/LINK/UNLK retire dispatch, JSR target fetch from S_JSR1,
  P182's fetch guard restored, one-clock FPU alignment shift (`docs/P190_...md`).
- P195: byte-enable store writes (no old-word merge, no spanning-store line read); **its first fit put the
  arrays in 514,863 registers** -- the slice-write form does not infer byte-enabled M10K in Quartus 17
  here; P195b splits each array into four byte-lane arrays (22,998 registers).  Always run
  `build_only.sh --check` and read `Total registers` after touching cache arrays.
- P196: the read-after-store handoff (regfile port F, `hint_rsr`, `fast_accept_pp` with the word
  overlap rule); P197: FPU cpGEN and PEA d16 dispatch (`docs/P196_READ_AFTER_STORE_20260923.md`).
- In scratch `p198_ret` (not landed): P198 UNLK->RTS handoff (RTS only: RTD in it costs Whetstone),
  P199 RTD redirected in its pop's acknowledge like RTS (+ RAS for RTD).  Whetstone 20,607,769.
- Fixture ladder (Whetstone at writes latency 1): P193 21.66M -> P197 20.73M -> P199 20.61M.
  Hardware needs ~15.25M for parity (1978 KWhet/s).

## Afternoon of 09-23: P198-P212, P205 on hardware 1.703

- Hardware ladder continued: **P205 (`887945b`, seed 25, dev) Mix 1.703** (Whetstone 1495, Dhrystone 20,185,
  Towers 0.507, Quick 0.506, Permutations 0.757; Bubble/Queens/Puzzle/Matrix/Sieve flat).  Per-test ratios
  against the real machine sum to 17.03; 1.9 needs +1.94 (Whetstone at parity alone is +1.64).
- P197's fit stalled in the fitter for 1 h 45 min (stopped); P205's routed in 12 min.  P209's fit: -2.220 ns
  (congestion at 94 % ALMs) and it carries a P207 bug -- never run.  P212 (`c214e74`) fitting at hand-off.
- The glue calls: Whetstone spends 6.3M of its clocks in the ROM's SANE-to-FPU glue (FADD/FMUL wrappers at
  $408EAA4C/$408EAD30).  `docs/P198_P205_CALL_RETURN_FPU_20260923.md` has the per-clock trace and changes.
- P206-P212 (commit messages have the detail): FPU EXEC/SHR skips, read-after-store for (An)+/-(An) (P207,
  fixed in c214e74: the source mode must come from the decode record, not ir[5:3]), FPU dispatch on done,
  forwarded pipe source hint (P209: costs the hint path), fast-ready in a posted store's C_PASS, fetch floor 4,
  conditional Bcc.W dispatched from retire (Queens -5.7 %).
- Fixture ladder (Whetstone, writes latency 1): P199 20.61M -> P205 19.17M -> P209 18.35M -> P212 18.05M.
- **The fixture over-predicts hardware.**  P193 -> P205 is 1.130x in the fixture at `+wlatency=1`, 1.061x at 3,
  1.040x at 5; hardware gave 1.078x.  An 8-deep store buffer is worth -3.4 % at wlatency 3 and nothing at 1.
  An Opus agent is building a platform-accurate Whetstone fixture (`scratch/platform_fixture/`: wombat_cpu
  against quadra800's real memory path, sdram_beat32, sdram.sv and the SDRAM chip model at 33/99 MHz) to find
  what the real store path costs.
- Checks for every CPU change (all in `scratch/p198_ret`, which tracks HEAD's RTL):
  `scripts/cpu/speedometer_suite.sh`, `rtl/ap68040/tb/run_tests.sh` (VASM=...wombat-vasm/vasmm68k_mot; it
  caught the P207 bug the fixtures missed), `run_dhrystone.py`, `profile_permute.py --pipeline --loads --stores
  --pea --xstore --lea --latencies 0`, `profile_queens.py --compare --early-drain` (without those two flags the
  numbers are 17 % off), Whetstone `run_whetstone_wl.py ... --bench tb_w2.sv` with `EXTRA_PLUSARGS=+wlatency=1`:
  tb_w2 prints `MEMSUM`, a hash of the whole RAM at the end -- it must stay `5892d5df133547e0` (Whetstone has no
  numerical oracle; FPU changes are checked by it).  `run_whet_tree.py` takes `TREE=` for other trees.
- Full-machine boot sims (Finder by frame 5400, 0 exceptions): P197, P205.  P212's running
  (`scratch/sim_p212`).

## Evening of 09-23: P212 on hardware 1.725; P214 platform fix; P220 failed on hardware

- **P212 (`c214e74`) Mix 1.725** (Queens +6.3 %, Whetstone +2.7 %).
- **Platform fixture** (`scripts/cpu/platform_fixture/`, TREE=<dir with rtl/>): Whetstone on quadra800 +
  sdram_beat32 + sdram.sv + SDRAM model; tracks hardware (P193->P205 1.093x vs 1.078x on hardware; P212 predicted
  +3.2 %, measured +2.7 %).  It found **P214**: 2-mod-4 longword stores took the adapter at 10 clk_sys; now two FIFO
  pushes (platform Whetstone -12.8 %).
- P215 (associative MMU data copies, Dhrystone -4 %), P216-P220 (MOVEM load chains, pair-hit idle reads,
  read-after-read handoff, **P220 idle-read validity fix -- a latent bug since P198/P205**), P221-P227 (FPU:
  F_IDLE fast paths, S_FPU_AN inlined, FMOVEM/FMOVE-out handoffs).  Fixture Whetstone 17.08M (P229), platform
  17.10M (~1860 KWhet/s projected).
- **P220 (`1a38ef8`, -2.596 ns, CACHE_TINY) failed on hardware**: Finder type-41 bomb twice, corrupted glyph,
  progress bar drawn past its box.  Suspects: the timing miss (worst path mem_addr_q -> MMU request translation ->
  epf_data, which P215's request-side compare lengthened), P215-P220 logic, CACHE_TINY (never on hardware before;
  passes tb_scsi_cache at 16/16/16).  Running: P229 fit (no P215, no CACHE_TINY), boot sims `sim_p220` (P220 RTL)
  and `sim_tiny212` (P212 RTL + CACHE_TINY).  The MiSTer was left with the P220 guest at the bomb dialog.
- A P228 variant (request path indexed, hint path associative) FAILED the MMU self-tests: the two sides must
  agree.  The SCSI-cache bypass (`SCSI_CACHE_OFF`, scratch only) does not find the disk -- not landed.
- Disk: scratch/ filled the disk (see memory `scratch-disk-hygiene`); delete obj dirs and run.hda after runs.

## Night of 09-23/24: the P219 fault, P232 on hardware 1.778

- P220 and P229 failed on hardware (Finder type-41 bomb, corrupted glyph).  Full-machine boot sims bisected it: P216
  and P216+P217 boot; P216+P217+P219+P220 ends in a Sad Mac 0000000F/00000002 -> **P219 (read-after-read handoff) is
  the fault**; it is gated off (`hint_rrr = 1'b0 && ...`).  P215 (associative MMU copies) is out for timing;
  P230's hashed slot index replaces it.  CACHE_TINY was cleared by a P212+CACHE_TINY boot sim.
- Routing is now the binding constraint: P232 (P214, P216, P217, P220, P221-P227, P230) failed or routed at
  -9.8..-17.8 ns at 94-95 %.  `SCSI_CACHE_OFF` (development builds only: the SCSI block cache bypassed; boot-simulated
  to the Finder) plus a seed sweep (`scratch/seed_sweep.sh`): of seeds 23-29 only 28 routes (-2.165 ns).
- **P232 seed 28 on hardware: Mix 1.778** (P212 1.725): Whetstones 1760 (+14.6 %, the platform fixture predicted
  ~1850), Queens +8 %, Towers +6.1 %, Quick/Permutations +3 %; **Puzzle 0.878 (-25.8 %) and Int. Matrix 0.511
  (-11.1 %) regress** on hardware only (fixtures, MMU on or off, show none).  Suspect: SCSI_CACHE_OFF -- a segment
  load inside the timed test.  A disk-I/O diagnostic run is under way.  With those two at P212's speed the Mix is ~1.83.

## Next

1. P212 fit -> hardware (Opus agent, P205's prompt with P212's identity); if the CPU clock is much past -1.7 ns
   try seeds (record each in the .qsf).
2. The platform fixture's verdict on the store path (store buffer depth, bridge FIFO, SDRAM row behaviour).
3. Remaining CPU items: LINK at a JSR target decodes after the push acknowledge (go_pc's resident dispatch
   bypasses the record dispatch; ~2 % of Permutations); RTD after UNLK (82k Whetstone decodes); `move.l
   #imm,d16(An)` right after a redirect (queue starvation); the FPU's NORM2/ROUND/WB latency before a dependent
   FMOVE; a Harvard split of the instruction port (fetches still share the one request port).
4. Area, after 1.9.
