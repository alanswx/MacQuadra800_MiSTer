# Area budget, 2026-09-24: what the full Mac needs and where the CPU's area is

The question: can the release recipe (OSDs, audio, Y/C, CD-ROM, Ethernet, SCSI
block cache) fit again with the fast CPU, by cutting what does not slow it
down first and a few percent of Mix if needed?

All ALM figures are Quartus's synthesis estimate ("Estimate of Logic
utilization (ALMs needed)" in the `.map.rpt`) unless marked *fit*.  The
synthesis estimate runs about 1,000 ALMs under the fitter on this design
(P232 dev profile: 37,980 synthesis, 38,967 fit at seed 28).

## The release recipe at HEAD (83177c7, P233)

`configs/cpu_release_lite.tcl` (OSDs, audio and Y/C in; shadowmask, the
audio IIR, video measurement and the 512x384 retarget out), CD-ROM and
Ethernet in, the SCSI block cache in:

| variant | ALMs | registers | note |
|---|---|---|---|
| CACHE_SMALL, CPU cache 16+16 KB | 93,187 | 116,700 | **block RAM over budget**: one data-cache way (`cdata0_*`, `cdata1_b3`) and `mt32pi` fall out to 90,000 registers |
| CACHE_TINY, CPU cache 16+16 KB | 93,003 | 116,608 | still spills |
| CACHE_TINY, CPU cache **8+8 KB** (`SETW = 7`) | **41,817** | 26,452 | no spill; device 41,910 |

Warning 276002 ("Cannot convert all sets of registers into RAM
megafunctions") is the only sign of the spill; the `ap040_cache.v` comment
at the mirrors records the same failure mode at P175b.  The CPU cache is
74 M10K at `SETW = 8` (16 KB instruction + 16 KB data, 4x a real 68040):
16 byte-lane data arrays of 2,048 x 8 (2 M10K each), 16 pair-mirror and 16
instruction-mirror arrays (1 each), two tag RAMs.  `SETW = 7` halves the
data arrays to 1 M10K each and saves 16 M10K; below 7 nothing more is saved
because every array is already one block.

What each Mac feature costs in the release recipe (one off at a time,
CACHE_TINY, SETW 7):

| off | ALMs | saves |
|---|---|---|
| (none) | 41,817 | |
| CD-ROM (`CDROM_OFF`) | 41,342 | 475 |
| Ethernet (`ETHERNET_OFF`) | 41,264 | 553 |
| SCSI block cache (`SCSI_CACHE_OFF`) | 41,380 | 437 |

The three Mac features together are about 1,500 ALMs.  The framework parts
a user sees (OSDs ~1,080, audio ~850, Y/C ~240, from the 2026-09-15
measurement in `cpu_release_lite.tcl`) are about 2,200.  The P232
development build (all of those out) was 37,980 and routed on one seed in
six, missing the CPU clock by 2.2 ns.

## The CPU over time (CPU-only synthesis)

`scratch/cpu_area/run.sh <tree> <tag>` synthesizes `wombat_cpu` alone with
the production AP040 macros (about 5 minutes; CPU outputs are ports, so a
little debug logic survives that the full design strips):

| CPU | ALMs | registers | Mix on hardware |
|---|---|---|---|
| 20260919 release (`5b9ad4d`, before the pipeline and fast paths) | 22,323 | 7,390 | ~0.93 |
| + the integer pipeline (`90b37e4`, 09-19 evening) | 25,291 | 7,903 | (P39 1.105) |
| `c8c58bf` (09-19) | 25,340 | 7,905 | |
| `d90c597` (09-20, the P63 era) | 26,167 | 8,176 | P63 1.129 |
| `53fb722` (09-20) | 26,812 | 8,435 | |
| P165 (`e655742`) | 27,361 | 8,485 | (P174 1.460) |
| P193 (`970b98c`) | 28,269 | 8,934 | 1.646 |
| P212 (`c214e74`) | 28,936 | 8,977 | 1.725 |
| HEAD (P233) | 29,366 | 8,977 | (P232 1.778) |

The 20260919 release fitted the full recipe at 36,914 ALMs (*fit*) with the
22.3k CPU.  The 7,000 ALMs the CPU gained since (Mix 0.93 -> 1.78) are the
gap; the P165 -> HEAD speed work is only 2,000 of them, and it bought
Mix 1.46 -> 1.78.  The integer pipeline, landed the same evening as the
Ethernet release, is 3,000 of them.  The last full-feature build was P63
(2026-09-20): 41,174 fitted ALMs, CPU clock -1.709 ns, never released; every
build since has been a development profile.  The non-CPU side has not grown
(about 14.6k at the Ethernet release, about 13.5k now).

## Feature ablations: speed cost and area

Fixtures: the latency-model kernel suite (Towers, Puzzle, Quick, Matrix,
Sieve, Bubble), Dhrystone, Permutations (lat 0), Queens (`--compare
--early-drain`), Whetstone (tb_w2, MEMSUM) and the platform Whetstone, all
oracle-checked; runner `scratch/abl_fixtures.sh <name>` on
`scratch/abl_<name>/rtl`.  Cycles relative to HEAD (+ is slower):

| off | Towers | Puzzle | Quick | Matrix | Sieve | Bubble | Dhry | Perm | Queens | Whet | plat. Whet | CPU ALMs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| whole pipeline | +8.9 | | +3.0 | +23.3 | +20.0 | +12.6 | +4.5 | | +28.1 | 0 | 0 | |
| XSTORE | +36.4 | +4.4 | +16.4 | 0 | 0 | 0 | +51.4 | +40.9 | +18.6 | +57.0 | +38.0 | |
| LEA | +11.6 | +0.4 | 0 | +0.1 | 0 | 0 | +2.2 | +1.1 | +0.5 | +4.2 | +4.2 | |
| PIPELINE_LOADS | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 29,456 |
| PIPELINE_STORES | 0 | 0 | 0 | **-2.9** | 0 | 0 | 0 | **-1.8** | 0 | 0 | 0 | 29,307 |
| LOADS + STORES | 0 | 0 | 0 | -2.9 | 0 | 0 | 0 | -1.8 | 0 | 0 | 0 | 29,150 |
| PIPELINE_PEA | 0 | 0 | 0 | 0 | 0 | 0 | 0 | +14.6 | 0 | 0 | 0 | 29,134 |
| PIPELINE_P6 | +6.7 | +6.8 | -0.9 | +23.3 | 0 | +8.4 | +0.3 | 0 | +0.7 | 0 | 0 | |
| MEMORY_ENTRY | +0.9 | +36.1 | +1.8 | +23.5 | +6.1 | +19.0 | +2.9 | 0 | +24.5 | +1.4 | +1.4 | |
| PIPELINE_COMPARE | +3.1 | +29.5 | +3.9 | +17.5 | +20.0 | +8.4 | +4.3 | 0 | +27.4 | 0 | 0 | |
| EARLY_DRAIN | +1.5 | +7.2 | +8.1 | +5.8 | +2.8 | +4.2 | +1.2 | 0 | +8.9 | 0 | 0 | |
| every address hint and handoff | +20.2 | +32.9 | +12.8 | +23.9 | +8.6 | +10.7 | +22.1 | +26.8 | +12.6 | +34.4 | +34.4 | 28,753 |
| CPU cache 8+8 KB (`SETW 7`) | 0 | +0.1 | -0.1 | +0.2 | 0 | 0 | 0 | 0 | -0.3 | +1.9 | +3.2 | 29,337 |

(The whole-pipeline run predates the Permutations fix in the runner; its
blank cells were not measured.)  Base: HEAD 29,366 ALMs; synthesis noise is
about +-100.

Readings:

- PIPELINE_LOADS and PIPELINE_STORES are free to drop (STORES is slightly
  harmful) but are worth only ~200 ALMs.
- Every address hint and handoff together is 613 ALMs and 9-34 % on every
  kernel: the fast paths are the best area in the chip.
- The 8+8 KB CPU cache costs Whetstone 2-3 % in the fixtures and is what
  lets the release recipe keep its block RAM.

So the free cuts do not close a 4-5k ALM gap, and the speed work since P165
is not where the area is.  The next step measures the base core by
instruction family (below).

## The base core by instruction family

`ap040_core` is one flat module (24k ALUTs of its own) and Quartus does not
extract its 202-state `state` register as a state machine, so it cannot
prune unreachable states.  `scratch/ablate_family.py` makes a family's case
items dead (`S_X: if (1'b0) ...`) and its `state == S_X` tests false; the
entries into the family stay.  CPU-only synthesis, HEAD 29,366 ALMs / 8,977
registers:

| family made dead | ALMs | saved | registers saved |
|---|---|---|---|
| all rare families below except exceptions, RTE, FPU | 25,533 | **3,833** | 2,026 |
| FSAVE / FRESTORE (`S_FSAVE*`, `S_FREST*`) | 27,950 | 1,416 | 994 |
| exception entry (`S_EXC*`, `S_AERR*`) | 28,146 | 1,220 | 374 |
| bitfields (`S_BF*`) | 28,230 | 1,136 | 188 |
| 64-bit MUL/DIV long (`S_MDL*`, `S_MD*`) | 28,838 | 528 | 399 |
| RTE (`S_RTE*`) | 28,859 | 507 | 44 |
| CHK2 / CMP2 | 29,058 | 308 | 0 |
| MOVE16 | 29,078 | 288 | 138 |
| MOVES / MOVEP | 29,115 | 251 | 73 |
| CAS / CAS2 | 29,311 | 55 | 30 |
| PTEST / PFLUSH / CINV | 29,382 | 0 | 74 |
| the core's FPU sequencing (`S_FPU*`, FScc, FDBcc, FBcc) | 26,954 | 2,412 | 401 |

None of the rare families runs in the Speedometer kernels, so making them
smaller costs no speed.  The plan: re-implement FSAVE/FRESTORE's state frame
(1,000 registers) compactly, merge the bitfield register and memory paths
onto one set of shifters, build exception frames with shared temporaries,
and share the per-family scratch registers; each change is gated by a
differential random-operand test against the current core as well as the
CPU self-tests.

## First structural cut: the bitfield register form on the memory stages

The register form of BFxxx had its own extract, mask and insert stages
(S_BF_X2/S_BF_X3) duplicating the memory form's (S_BF_M2/S_BF_M3), and two
rotators.  It now rotates into the 40-bit work window and runs the memory
form's stages, and one rotator serves both directions (right by n is left by
-n).  Checked by a differential random test
(`scripts/cpu/bitfield_diff_gen.py`: 32 seeds x 85 cases, register and
memory forms, immediate and Dn offsets and widths, every result, CCR and
memory window compared against the old core over the three
tb_ap040_program phases; a planted rotate-direction bug is caught) and the
CPU self-tests (all pass).  **29,366 -> 29,105 ALMs (-261)**, a quarter of
the family's 1,136: the rest is the field logic itself.  At that yield the
structural route is worth roughly 1,000-1,500 ALMs over all the rare
families, not the 4-5k the release recipe needs.
