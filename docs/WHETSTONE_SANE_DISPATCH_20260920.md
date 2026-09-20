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

## Translation-fault qualification and broader gates

`fpu_read_faults.py --mmu 4k|8k` now makes page 2000 invalid in real page
tables and places an extended operand so each of its three longwords can
be the first failing read. All nine addressing/word-position combinations
pass on both baseline and P99, in all three bus phases, for both page sizes.
Handlers check that TC remains enabled, format-7 PC/fault address, unchanged
FP0 and A0, and absence of the following instruction's side effect.
Evidence: scratch/{base,p99}_fpu_mmu_faults{4k,8k}_20260920.
These tests validate exception entry and rollback, not RTE retry of those
specific FPU faults.

A frozen candidate tree and source manifest are under
scratch/p99_fpu_read_20260920/{tree,gate_source_identity.json}.
The established pipeline_handoff extended integration and immutable
first-100 corpus gates were launched as user units
q800-p99-integration-20260920 and q800-p99-corpus-20260920. Their results
are pending; no promotion or fit has occurred.

## Installed guest handler snapshot

The initial 8 MB capture was insufficient: logged SRP=01FF6C00 lies near
32 MB. A second, 32 MB capture from the same live guest succeeded at halfcycle
2419752961, PC4080B444, TC=C000, URP=0, SRP=01FF6C00. File:
scratch/whet_snapshot_host_20260920/tree/verilator/ram_snapshot_2419752961.bin.

`inspect_sane_snapshot.py` follows the captured supervisor page tables using
the same indexing as ap040_mmu.v and records every descriptor plus RAM hash
in scratch/whetstone_inventory_20260920/live_traps.json. Low-memory slots
and handle cells translate identically, consistent with transparent mappings
as well; this reader does not emulate ATC or transparent registers. The
physical snapshot still is not an architectural checkpoint.

| Item | Installed value |
|---|---|
| A-line vector 28 | 408099B0 |
| FP68K slot 15AC | 408E9A2C |
| FP68K hook 0AC8 | handle 244C, contents 408E9A20 |
| Elems68K slot 15B0 | 408EDCAC |
| Elems68K hook 0ACC | handle 2444, contents 408EDCA0 |

ROM 408E9A20 branches to 408E9A2C; the live FP68K table directly selects the
same dispatcher. Both installed implementations are in the ROM. This is the
booted inspection guest's state, not a capture at a Whetstone call boundary.
Next resolve selector dispatch and capture the original Whetstone inputs and
relocated state for a complete fixture; the current add test is only one
synthetic subroutine workload.

P99's broader integration unit subsequently completed with exit 0 and
`PASS real-core pipeline ownership integration`, including IRQ/replay cases.
The immutable first-100 corpus completed with 1900 field groups matching,
zero differences (/tmp/cpu-corpus100-gate.Uc2U3f). No fit/hardware claim.

## Selector targets and call-site rewriting

`resolve_sane_selectors.py` pins the ROM identity and the dispatcher instruction
bytes, then follows the actual rotate/shift/bitfield index calculation for
FP68K and masked index for Elems68K. Output:
scratch/whetstone_inventory_20260920/selector_targets.json.

| Dispatcher | Selector | ROM target |
|---|---|---|
| FP68K | 0000 | 408EAA4C |
| FP68K | 0002 | 408EABBE |
| FP68K | 0004 | 408EAD30 |
| FP68K | 0006 | 408EAEA2 |
| FP68K | 0008 | 408EB1FA |
| FP68K | 000D | 408EBCE6 |
| FP68K | 0012 | 408EB850 |
| FP68K | 200E | 408EB5BE |
| Elems68K | 0000 | 408EE83C |
| Elems68K | 0008 | 408EE042 |
| Elems68K | 0018 | 408EEBC2 |
| Elems68K | 001A | 408EEC52 |
| Elems68K | 001E | 408EEA54 |

FP68K at 408E9A80..408E9A9A recognizes a return address following
`MOVE.W #selector,-(SP); A9EB` and rewrites that six-byte sequence to
`JSR absolute` to the selected handler. 408E9AD2..408E9B3A handles cache
maintenance. Whetstone's inventoried sites use that immediate-selector form.
This is a conditional runtime rewrite, not evidence that every site has
already executed. A faithful fixture must retain writable code and coherent
instruction-cache behavior, or explicitly distinguish a captured patched
state from first-call execution. Forcing repeated A-line dispatch at every
original static trap site would misrepresent the repeated workload.

P99 was promoted as the exact qualified core SHA256
624964c31225722fd8b2b6d68901c1d0490c8152caec2072060ec771a6641757 in commit
4cd5824. Its development fit is running as q800-p99devfpuread-fit-20260920,
archive scratch/p99devfpuread_fit_20260920. All build inputs are frozen
through archive and detailed CPU/cross-domain timing. No fit result yet.
