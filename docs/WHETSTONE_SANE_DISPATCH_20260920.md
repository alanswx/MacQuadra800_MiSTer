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
