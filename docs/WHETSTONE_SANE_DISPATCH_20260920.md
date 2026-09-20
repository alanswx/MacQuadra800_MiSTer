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
