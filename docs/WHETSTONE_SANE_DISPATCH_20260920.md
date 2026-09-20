# Whetstone SANE dispatch evidence

The original Speedometer CODE3 inventory and CODE6 wrappers identify A9EB
(FP68K) and A9EC (Elems68K) calls. Their live destinations must be resolved
before extracting a faithful standalone workload.

Run `python3 scripts/cpu/resolve_sane_rom.py releases/quadra800.rom --out scratch/whetstone_inventory_20260920/rom_traps.json`.
The resolver pins the ROM SHA256, decodes its 1024-entry compressed Toolbox
trap table, and verifies each SANE entry's actual hook-loading prologue.
The decoder follows ROM 40809A96..40809ADC; Toolbox dispatch at 408099B0
and the GetTrapAddress helper at 40809A3A establish the table indexing.

| Trap | Low-memory table slot | Initial ROM handler | RAM handle location |
|---|---|---|---|
| A9EB FP68K | 15AC | 40826206 | 0AC8 |
| A9EC Elems68K | 15B0 | 40826228 | 0ACC |

Each ROM handler reads its RAM handle, then dereferences it. If both are
nonzero, it dispatches to the handle contents. Otherwise it enters the
resource-loading fallback at 408262AE or 408262B0. Mac OS may also replace
the trap-table slot itself. Consequently neither a ROM disassembly nor the
trap-table slot alone proves which arithmetic implementation executes.

Validation: decoded addresses agree with the existing ROM disassembly;
both expected hook prologues match ROM bytes; a one-bit-corrupted ROM is
rejected. These are static structural checks, not dynamic performance data.

Next inspect the snapshot guest's low-memory slots and handles, respecting
its TC/URP/SRP translation state. Raw physical RAM is not automatically a
virtual address space or an architectural checkpoint. Follow the installed
handler before extracting code and runtime data; do not substitute host math.

## Executable ROM add fixture

Live P97 Whetstone heartbeat PCs included 408EAA74 and 408EAD3E, inside
ROM extended-add/multiply wrappers. The add wrapper contains FMOVEM,
FADD.X and FMOVE.X; hardware floating-point instructions are being reached.
Sparse heartbeat samples do not establish their frequency or cost.

`python3 scripts/cpu/profile_sane_add.py releases/quadra800.rom --out scratch/sane_add_baseline_20260920`
extracts the unchanged 70-byte add wrapper [408EAA4C,408EAA92), places it
at 1000 (no address-dependent code references), and performs 100 additions
of 1 to 2. The exact extended result must be 4005:CC000000:00000000 (102).
The source, adjacent memory guards, stack pointer, A0 and A6 are checked.
Changing the fixture's FADD.X to FSUB.X is a required failing control.
ROM/kernel/program/RTL identities are recorded with the output.

All three existing CPU-bench phases pass; subtraction is rejected. Tagged
loop spans are 38,548 / 53,498 / 53,498 clocks. They include calls, loop
control and the end marker, and are not pure arithmetic latencies. Phase 0
whole-program profile: 39,394 clocks, 24,147 in S_MRD/S_MWR (61.3%), of
which 904 wait for the fetch queue to release the shared port. The operand
values are synthetic exact integers, not Whetstone's full operand trace.

This first fixture uses ap040_tg68k_compat and its 16-bit adapter, caches
enabled, MMU and experimental integer pipeline disabled. It is useful for
correctness and CPU/FPU comparisons, but **not** representative of Quadra
SDRAM/store-queue timing. Next port these unchanged routine bytes and the
independent oracle to the existing 32-bit wombat_cpu memory harness before
using measurements to choose a production optimization.

## 32-bit fixture and isolated P99 screen

`profile_sane_add32.py` uses the same byte-exact program and independent
exact arithmetic oracle through wombat_cpu, the production cache and ordered
write queue. It enables the current integer-pipeline flags, checks bus request
stability until acknowledgement, checks output/source/guards independently in
the host, and requires the FSUB negative control to fail. Identity manifests
record all sources and flags. MMU remains disabled; controlled RAM replaces
the SDRAM controller and retained-line path.

| RAM latency | Baseline loop clocks | P99 loop clocks | Reduction |
|---|---:|---:|---:|
| 0 | 22519 | 21921 | 2.66% |
| 3 | 22693 | 22096 | 2.63% |
| 8 | 24256 | 23659 | 2.46% |

Evidence: scratch/sane_add32_baseline_20260920 and
scratch/sane_add32_p99_20260920. All exact-result cases pass and both variants
reject the subtraction control. Whole-fixture baseline latency-3 state
occupancy is 7788 read + 2677 write clocks out of 23503 (44.5%). This is
not the measured loop alone and is not a full Whetstone profile.

P99 (`scripts/cpu/fpu_read_early_issue.patch`, **unapplied**) adds address hints
for S_FPU_RD and loading S_FPU_MVM2, allowing their reads to use the existing
within-page low-RAM early-issue gate. It saves approximately one setup cycle
per operand longword in this fixture. No production RTL changed. It still
needs MMU, page-crossing and fault/restart qualification before promotion;
there is no Quartus or hardware result. A 2.6% add-wrapper improvement alone
cannot close the real-machine Whetstone deficit.

## P99 MMU screen

The 32-bit runner now accepts `--mmu 4k|8k --remap`. Both supervisor and
user roots point at real resident page tables. The operand virtual page at
2000 maps to physical 6000; the old physical page is poisoned with DEAD.
The independent host oracle reads the translated location and requires the
entire poisoned page to remain unchanged. Nonzero walker reads/writes,
TC enable and descriptor used bits are required, so a disabled/bypassed
MMU cannot silently pass this workload.

| Mapping | RAM latency | Baseline loop | P99 loop | Clocks saved |
|---|---:|---:|---:|---:|
| Remapped 4 KB | 3 | 22834 | 22237 | 597 |
| Remapped 4 KB | 8 | 24477 | 23880 | 597 |
| Remapped 8 KB | 3 | 22697 | 22100 | 597 |
| Remapped 8 KB | 8 | 24422 | 23825 | 597 |

All exact results, guards and subtraction controls pass. The 4 KB runs
perform 18 walker reads/8 writes; 8 KB performs 15/7. Evidence directories:
`scratch/sane_add32_{base,p99}_mmu{4k,8k}_20260920`.
The gain survives real translation (~2.4–2.6%). These are successful
within-page accesses, not fault injection or cross-page qualification;
P99 remains isolated and unapplied pending those checks.

## P99 fault and boundary checks

`fpu_read_faults.py` runs nine directed cases: bus fault at each of the three
longwords of an extended operand, for FMOVE postincrement, FMOVE predecrement
and FMOVEM postincrement. The handler checks format-7 frame, instruction PC,
fault address, unchanged A0 and FP0, and that the following instruction did
not execute. Baseline and P99 both pass all nine cases in all three existing
CPU-bench bus phases. These are bus-fault tests with caches/MMU disabled,
not translation-fault or cross-page-fault injection.

`profile_sane_add32.py --mmu 4k|8k --remap --stack 0xe088 --require-fpu-crossing`
places a SANE temporary FPU operand at DFFE. P99 passes exact results,
guards and the subtraction control at latencies 3/8 for both page sizes;
the monitor requires entry into S_MRD_B with an FPU return state and the
crossing condition. It records 100 split FPU reads in each run. An initial
monitor looking only at normal S_MRD acknowledgements incorrectly reported
zero; it was corrected to observe the actual byte-split path, not weakened.

Evidence: scratch/{base,p99}_fpu_faults_20260920 and
scratch/p99_sane_cross{4k,8k}_20260920. P99 remains unapplied. These gates do
not establish full CPU-corpus correctness, fit/timing, or hardware performance.

The existing `rtl/ap68040/tb/asm/t_fpu.s` battery was freshly assembled and
run on the same P99 bench: all three phases pass (107834/152622/152622 total
cycles). Logs and binary are in the P99 fault directory under `full_fpu.*`.
This supplements the new directed tests; it is not the complete CPU suite.
