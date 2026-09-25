# Timing closure on the full-feature build, 2026-09-25 (afternoon session)

Goal: the full-feature recipe (OSDs, audio, Y/C, CD-ROM, Ethernet, SCSI
block cache) with timing met on every clock.  Starting point: the interim
`15a1449` build, 40,651 ALMs (97 %, 4,182/4,191 LABs), CPU −2.406 ns,
SDRAM −0.697, HDMI −0.426, Mix 1.828 on hardware.  Its worst path was 71 %
interconnect: the chip was too full to route short wires.

The user allowed cutting the CPU further.  All fits below are seed 21
unless noted, in independent scratch project copies (`scratch/fit*/`),
reported by `scratch/fit_report.sh <dir>`.

## Area first

| change | full map (ALMs) | note |
|---|---|---|
| HEAD `8bdade9` (X-default BRF + SDRAM ready bits) | 38,824 | |
| + the three invisible framework trims back on (`MISTER_DOWNSCALE_NN`, `MISTER_DISABLE_ADAPTIVE`, `MISTER_DISABLE_ALSA`; part of the shipped 09-19 recipe, commented out on 09-24) | 38,362 | −462, commit `22b5667` |
| + IOSB/djMEMC scratch registers in MLABs with valid bits (`rtl/iosb.sv`) | 38,093 | −269 ALMs, −976 registers, commit `9c2cfa4`; boot sim reaches the Finder |
| CPU-only: second integer pipeline off | 25,410 → 23,730 | −1,680; fixtures say about −10 % Mix |
| CPU-only: PIPELINE_LOADS+STORES off | +80 | no longer helps (the 09-24 "seqmem" result) |

## Full fits

| fit | recipe | ALMs (fit) | CPU | SDRAM | HDMI | worst CPU family |
|---|---|---|---|---|---|---|
| A `tc_a_trims_iosb` | pipeline kept | 39,626 (95 %) | **−2.761** | −0.119 | −1.112 | 2 h in the router; congestion |
| B `fitB_nopipe` | pipeline off | 37,866 (90 %) | **−0.350** | +0.478 | −0.209 | `epf_head → … → epf_ftail` (queue-head branch decode → target → refill seed → tail), 43/200 endpoints |
| B seed 22 | | | −0.755 | −1.891 | −0.203 | |
| B seed 23 | | | −1.412 | −0.227 | −0.596 | |
| B seed 24 | | | stopped after 2 h in the router | | | |
| C `fitC_bdr` | B + P240 | 37,975 | −0.548 | −0.103 | −0.630 (shadowmask) | tag RAM → hit → c_rdata → ALU → flags → taken → refill seed → `epf_data`, 191/200 |
| D `fitD_bdr2` | C + P241, shadowmask off | 37,727 | −1.665 | +0.107 | −0.846 | same family, entering the ALU on the quick-RMW operand |
| E `fitE_bdr3` | C + P242, shadowmask off | 37,712 | −1.548 | +0.734 | −0.319 | c_rdata → ALU result → register bypass → DBcc count test → refill seed |
| **F1** `fitF1_speed` | B + `PHYSICAL_SYNTHESIS_COMBO_LOGIC ON`, `OPTIMIZATION_TECHNIQUE BALANCED`, shadowmask off | 38,329 (91 %) | **+0.007** | **+0.082** | **+0.044** | **timing met**: every setup, hold (min +0.219), recovery, removal positive; crossings +0.469 / +0.519 |
| F2 `fitF2_speed` | C (P240) + the same | 38,632 | −0.569 | +0.005 | −0.124 | |
| G `tc_g_fullfeature_clean` | F1's recipe refitted in the checkout at `a0b3072` | 38,329 | +0.007 | +0.082 | +0.044 | **bit-identical RBF** (sha256 ce26df46…, md5 46b85dcc) |
| H1 | F1 with the original IOSB registers | | −0.235 | | | hardware bisect only |
| H2 | F1 with the pipeline back on | | −1.561 | | | hardware bisect only |
| H3 | F1 without the three trims | | −0.435 | | | hardware bisect only |

The speed synthesis settings were worth about 0.4 ns on the same RTL
(B −0.35 → F1 +0.007); with them the P240 core (F2) was worse than without,
so the recipe carries no CPU RTL change beyond the IOSB move.

## Hardware, 2026-09-25 afternoon

Every build deployed after 14:30 came up black with no disk reads at all --
F1, fit B, H1, H3 and the known-good 1.828 build alike.  Cause: the MiSTer's
Main binary had been replaced at 12:58 by a FujiNet build without the Quadra
800 support (no `macquadra800` / SONIC / `Mac CD` code), so no Mac core got
its ROM.  With `/media/fat/MiSTer.bak_pre_fujinet` (md5 d5b50fc4, Quadra +
printer) reinstalled, F1 boots to the Finder desktop.  Lesson: check Main's
identity (`grep -a -c macquadra800 /media/fat/MiSTer`) before blaming a build
for a black screen, and keep the known-good RBF as the first control.

The RBF is `test-builds/MacQuadra800_fullfeature_timingclean_20260925_a0b3072.rbf`.
On hardware: **Mix 1.661 / 1.670 / 1.674 / 1.666 / 1.676, median 1.670**; Ethernet
pings, CD data, CD audio transport and normal shutdown pass.  Full table and
evidence: `docs/perf/fullfeature_clean_20260925/README.md`.

SDRAM crossings (sys↔ram) pass on every routed fit (+0.6 / +1.8 ns on B).

## The CPU changes tried (scratch/abl_bdr*, all self-tests pass)

- **P240** registered lookahead branch decode: the three queue-head words
  are captured at the end of each cycle from where the head will be after
  the pop; the lookahead fires only while the copies match the live head
  (`bd_fresh`).  Removes the `epf_ftail` family.  Fixtures: Queens +5.7 %,
  Puzzle +2.4 %, Whetstone +1.2 %, rest ≈ 0 (about −1 % Mix).
- **P241** no lookahead Bcc on flags from an S_MRD one-clock-hit operand:
  adds Bubble +4.2 %, Dhrystone +2 %.  Does not cut the path structurally
  (the ALU still has `mem_rdata` as an input and the flag mux still has
  `alu_fast_fl`), so STA still sees it.
- **P242** lookahead Bcc on registered flags only: **Matrix +28 %, Sieve
  +13 %** — rejected.  And the family survives through another route
  (ALU result → register-file bypass → S_DBCC1).

Reading: every violating path is a 26-29 level one-cycle handoff whose
interconnect share is 60-70 %; the seed spread (−0.35 … −1.4 on the same
RTL) is larger than any single cut, and each cut moves the miss to the
next family of the same depth.  The remaining levers are placement/synthesis
effort (F1/F2) and more area.
