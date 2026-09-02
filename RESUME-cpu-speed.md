# Resume prompt — CPU speed: related-clock handoff validated, page mode next

Paste this file as the opening message of a new session. Repo on `main`
through `4a29d6c`; the related-clock handoff is hardware-validated in the
current worktree but not committed.

This documents the landed fast path plus a related-clock follow-up that is
**finished and measured but not yet committed**. It is a starting point, not
a rescue. If you are here to make the machine faster, §5 is the queue.

**Binding rule:** never load a core while the guest is booting or running. It
hard-resets the FPGA and yanks a mounted, writable volume out from under the
OS. Shut the guest down first (`scripts/guest/shutdown.sh`) and flash only
when the screen says it is safe.

## 1. What was resolved

The machine ran the authentic 33 MHz bus clock but its memory delivered
16.5 MB/s where a real Quadra 800 does 50–65. Under a write-through cache with
no write buffer that was paid on every store and every miss. Two platform-side
changes, no CPU or submodule work:

- **Posted RAM writes.** The bridge captures a write, acks the beat, and
  drains behind the machine. Nothing downstream changed — the whole stall
  chain is ack-based, so releasing the ack releases all of it. Ordering is
  free because the next beat still waits on `busy`.
- **One row cycle per read.** `BURST_LENGTH=4` was already in the mode
  register, so every READ returned four words; the old bridge threw all four
  but the first away and then paid a *second* full ACT→RD→precharge for a word
  the chip had already handed it. A 32-bit beat's two halves are a 4-byte
  aligned pair, so they are always words 0 and 1 of one burst.

The bridge moved out of `wombat33.sv` into `rtl/sdram_beat32.sv` so it could
be tested.

**Results.** Memory path in isolation (`verilator/tb_sdram.sv`):

| | before | after |
|---|---|---|
| isolated read beat | 272 ns | **212 ns** |
| isolated write beat | 242 ns | **30 ns** |

End to end, Speedometer 4.02 on hardware
(`docs/PERFORMANCE_MEASUREMENTS.md`):

| | real Q800 | before | after |
|---|---|---|---|
| Benchmark Mix | 1.897 | 0.200 | **0.231** (+15.5 %) |
| Color QuickDraw | 1.283 | 0.198 | **0.219** (+10.6 %) |

The follow-up related-clock handoff removes both conservative 2FF crossings by
capturing on the falling edge of the phase-related 99 MHz clock. It measures
151 ns per read and 22.0 MB/s sequentially. On the same Speedometer 3.23 disk,
the PR CPU score rose 2.661 → **2.917** (+9.6%). Do not compare that PR score
directly with the 4.02 Benchmark Mix above.

## 2. Regression status — all green for the handoff candidate

| check | result |
|---|---|
| `cd verilator && make tb_sdram` | 33 checks, 0 failures, 0 chip protocol errors |
| `cd verilator && make tb_easc` | 18 checks, 0 failures (pre-existing suite) |
| GUI sim elaboration (`verilator --lint-only`, full `V_SRC`) | clean; only pre-existing `SIDEEFFECT` warnings in `ap040_fpu.v` and `sim.v` |
| Quartus, seed 15 | fits, **+0.270 ns setup, +0.241 ns hold** |
| Targeted handoff paths | ≥+1.353 ns setup, ≥+3.191 ns hold |
| Hardware | Mac OS boots; full Speedometer 3.23 PR suite passes; clean shutdown |
| `rtl/ap68040` submodule | untouched, `0e767614` |

Re-run the first two before trusting any change to `rtl/sdram*.sv` or the
memory path in `wombat33.sv`. `tb_sdram` is the one that matters: it drives
the beat port against a behavioural SDRAM chip model and checks halfword
order *in the chip's own array*, all sixteen byte-enable masks,
read-after-posted-write ordering, all four banks, survival across refresh, and
a 64-deep sequential stream — then prints the latency table above, which is
the regression test for a performance change.

## 3. The builds to use

`releases/wombat33_20260901.rbf`, md5 `abb5ede4f776d20ccd74367813aa1d28`.
Seed 13, timing met at +0.132 ns, so `scripts/deploy_screenshot.sh` accepts it
with **no** `ALLOW_TIMING_VIOLATION`. It is also the core the A/UX work
(`RESUME-aux-scsi.md`) is running on.

**Read `wombat33.qsf` around the SEED assignment before you panic about
timing.** The critical path is `ap040_core|ir → exc_fmt` *inside the CPU
core*, on `clk_sys`, with ~0 ns margin. Any netlist perturbation flips it —
this branch made the design 97 ALMs *smaller* and still sent seed 6 from
+0.062 to −0.952 ns. Walking the seed found +0.132 at seed 13. Eight seeds are
recorded there. **Walk seeds; do not go hunting in your own diff.** Candidate
bitstreams and their reports live in `scratch/seeds/` (gitignored);
`scratch/seeds/restore_seed.sh <n>` stages one for deploy.

The faster candidate is `releases/wombat33_20260901_2.rbf`, md5
`d1d785de28439d132333a1c9e3aab5c5`. It is preserved separately from the
seed-13 release so both measured configurations remain reproducible.

## 4. Gotchas that cost real time

- **Verilator's `BLKANDNBLK` on `sdram.sv` cannot be waived.** Block-local
  statics with initialisers are both blocking- and non-blocking-assigned;
  waiving it does not make it work — the whole always block silently stops
  executing the instant startup finishes, presenting as a permanently hung
  handshake with the state machine frozen in `STATE_IDLE`. They were hoisted
  to module scope, which is identical for synthesis.
- **A dialog screenshotted immediately after opening can be caught
  mid-redraw**, missing its title, static text and button labels. That is not
  a rendering fault. It briefly looked like a regression from this branch.
- **The 8-bit Color QuickDraw test does not reproduce** — 43.7, 32.4, 45.2,
  45.2 seconds across four runs. Three cluster; the 32.4 is a lone outlier
  that made an early sweep imply a 22 % colour gain. That number is wrong.
  **Why the one fast sample happened is still unexplained** and is the only
  loose thread in the measurements.
- **A screensaver is armed on the Quad Squad disk**, idle timeout between
  250 s and 400 s. Keep timing runs inside ~250 s of the last input.

## 5. The queue, in order

From the original plan, with what the measurements now say about it:

1. **Page-mode scheduler in `sdram.sv`** (plan §1d). The structural fix and
   the prerequisite for real-Quadra *bandwidth*: drop per-access
   auto-precharge, keep rows open per bank, track tRAS/tRC/tRP. Sequential
   beats — line fills and writeback streams — become page hits.
   `docs/sdram-vram-sharing.md` §6(a) has the design and cycle diagrams.
   `tb_sdram.sv`'s chip model already tracks bank/row state and reports the
   timing parameters such a scheduler must respect, which is most of what
   makes this tractable. An isolated prototype passed those checks and reached
   26.1 MB/s reads / 32.4 MB/s writes, but it is not ready to merge: cover the
   copy port and resolve the four-cycle ACT→PRE case against tRAS first.
2. **Full-line read path** (plan §1e). The prototype shows page mode alone is
   still limited by the serialized request/ack bridge. A one-beat cache using
   the unused half of BL=4 reached 37.5 MB/s. Getting to 50–65 MB/s needs the
   cache's `fill_active` plumbed out of `ap040_cache` plus a controller that
   pipelines all four beats, or an equivalently coherent 16-byte read-ahead
   buffer. Do not promise 50–65 MB/s from row-open scheduling alone.
3. **Inside the core** (`rtl/ap68040`, coordinate with whoever owns it): early
   ack on line fills, then a store buffer, then copyback. `docs/sdram-fast-path.md`
   §3 and the original plan's §2 have the analysis. Copyback needs a real
   snoop — an external write hitting a dirty line would destroy data on
   invalidate, and the MMU walker's U/M-bit updates use exactly that path.
4. **Perf counters** (plan §4 stage 0) — still not built, because there is no
   readout path: `debug_status` is the core's bus, `m_debug_status` in
   `wombat33.sv` goes nowhere, and the Verilator GUI sim builds `sim.v`, not
   `wombat33.sv`. Counters would be write-only. **Giving them a home is the
   prerequisite**, and they are what would turn "it feels faster" into "store
   stalls fell by N %" and say when the bottleneck has moved into the core.

## 6. Do not break

`rtl/ncr53c96.sv` is shaped tightly around the Mac ROM's SCSI access pattern
and the A/UX work is actively widening it (`RESUME-aux-scsi.md`). The memory
path and the SCSI path meet at the beat port in `wombat33.sv`, so changes
there want a Mac OS boot re-verified on hardware, not just green testbenches.

Keep `docs/sdram-fast-path.md` and `docs/PERFORMANCE_MEASUREMENTS.md` current
— the second is the before/after baseline any future speed claim is measured
against, and re-running that comparison after §5.1 and §5.2 land is the
obvious next measurement.
