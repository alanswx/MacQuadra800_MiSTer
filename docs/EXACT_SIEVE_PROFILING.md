# Exact Speedometer Sieve: relative kernel profiling

This fixture measures unchanged Speedometer 4.02 integer-loop bytes without
Mac OS startup or its suspect stopwatch. Results are **relative kernel CPU
cycles**, not absolute Speedometer scores, application latency, or hardware
cache measurements. It does not change RTL or run hardware.

## Provenance and correctness

Source: `/tmp/speedo402-unar/Speedometer 4.02.rsrc` (AppleDouble), SHA-256
`af67113bceb4eb906e973a9b747a0b1925b9d64c62f0f9a84bc6f0578839ca80`.
The actual CODE 3 Benchmark Mix selector 12 calls Sieve at resource offset
`0xB54`. Its 80-byte computational loop is file `[0x630C7,0x63117)`, resource
offset `0xB66`, SHA-256
`345defabade69898e7c3300557944301ea7a1dc5cd2b6472326c524e5bf8882a`.
This is not the similar copy in the tEsT resource. Extraction rejects an
unrecognized resource; no binary redisassembly/reassembly changes the loop.

The loop at $2000 runs its original 100 passes with A2=$4000. It needs no
relocations, A5 globals, OS calls, or libraries. The excluded function wrapper
calls NewPtrClear/DisposePtr; the application stopwatch is also excluded.
The complete fixture image SHA-256 is
`1276106eea0281f1d9180027ff7be73f1fdfb4059b01101b604b3ca56f21d80f`.

The host-side SV oracle independently trial-divides every odd number 2*i+3
for i=0..8190. It checks D6=100, derived D7=1899, all 8191 final array bytes,
and surrounding guards after both calls. Final-array SHA-256 independently
computed in Python:
`6cae993f4352ec01660344e72914964c9f8557c9138c8f2892f4019b658a4218`.
The original inclusive bound accesses 8191 bytes despite requesting 8190
from the allocator; the fixture preserves that bound, reserving 8 KiB plus
32-byte exterior guards. The unused 8192nd byte remains a sentinel.

## Timing boundaries and conditions

Setup initializes data/guards with caches disabled, enables IC/DC, and
invalidates both. Each latency phase invokes the exact loop twice: first
`cold_at_call`, then `repeat_no_flush`. The array exceeds one 4 KiB cache
side; the repeat is not described as entirely cache-resident.

The monitor samples one time unit after each positive edge, after NBA
updates. Entry is S_DECODE at PC_i=$2000/IR=$7C00; exit is S_DECODE at
PC_i=$2050/IR=$4E71. These MOVEQ/NOP boundaries cannot take the candidate's
shared register-decode bypass. Reported cycles are exit_edge-entry_edge:
initial entry fetch/setup are excluded; kernel execution and final fallthrough
dispatch are included; exit NOP execution, RTS, checks, and stopwatch are
excluded. This is not an instruction-retirement counter.

The state histogram samples pre-edge state on (entry_edge, exit_edge] and
must sum to the bracket; its stall subset has core CE low. `+sieveprof` is
kernel-only, while the inherited `+prof` includes setup. Backing-memory checks
are valid for this write-through AP cache after the kernel's stores complete.

The reused `tb_ap040_program` instantiates `ap040_tg68k_compat`, not the actual
`wombat_cpu`/djMEMC path. Cache config, placement, latency phase, and call
condition must match between variants. Phase 0 uses immediate ready, phase 1
varied waits, phase 2 varied waits and held-level acknowledgement.

## Commands

Run **serially per tb source tree**: the runner shares `tb/build` for image
generation. Different output directories alone do not make parallel invocation
safe. Use separate source copies if parallel tests are necessary. Requires
VASM and Verilator 5 with timing support; no general regression is launched.

```sh
cd /home/alans/mister/MacQuadra800_MiSTer/rtl/ap68040/tb
VASM=/tmp/wombat-vasm/vasmm68k_mot \
VERILATOR=/home/alans/verilator5/bin/verilator JOBS=4 \
sh run_exact_sieve.sh '/tmp/speedo402-unar/Speedometer 4.02.rsrc' \
  /tmp/MacQuadra800_regdispatch_20260912.ptmO3k/rtl/ap68040/rtl \
  /tmp/ap040-exact-sieve.tbhvUa/ab-regdispatch +phase=0
```

The RTL_DIR must be a complete source tree, including `ap040_defs.svh` and
the wrapper/cache/bus modules. The similarly named
`/tmp/ap040-regdispatch-verify.PQvPVk/rtl` contains only the core and is unsuitable.

Reference core SHA-256:
`a433214d9b776f8d4da9c824a39b638226e067c158de81b202ca1c3514a206f2`.
For compact, use RTL_DIR `/tmp/ap040-shared-compact.9MZsa0/ap68040/rtl` and a
distinct output directory; core SHA-256:
`5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
Omit `+phase=0` for all three phases. The runner records hashes, compile/run
logs, asserts image placement, and requires two checked kernels per passed
phase. Its 400-million-cycle timeout does not change the kernel's loop count.

## Measured compact result, 2026-09-12

Phase 0 passed: cold call **96,114,461** cycles; repeat **96,114,314** cycles.
Both had D6=100, D7=1899, complete array and guards PASS. Whole phase including
setup/caller: 192,283,290 cycles. Verilator 5.050 build: about 13 s; execution:
182.648 s. Evidence `/tmp/ap040-exact-sieve.tbhvUa/debug-compact/run.log`, SHA-256
`549fe71700ea1f0de4b6f406ed43b50a6c0ff2c5754e525d1ecd6d8cb4a5d43a`.
Reference phase 0 subsequently passed with the same image and complete fitted
regdispatch RTL: 96,618,059 cold / 96,617,914 repeat cycles; both array/guards
and D6/D7 checks PASS, exit 0. Compact reduces cycles by 503,598 / 503,600,
or **0.52123%** versus reference. This is not the hardware CPU Mix gain.
Reference log: `/tmp/ap040-exact-sieve.tbhvUa/ab-regdispatch/run.log`, SHA-256
`bf86f78c29dfe289c63c7ee28d79bd6784d9997171b820eeed45b42a4a38c1cb`.
On the repeat, compact eliminates 2,357,400 DECODE and 1,381,800 IMMF clocks
but adds 3,235,600 FETCH clocks; all other state occupancies are unchanged.
This makes fetch/extension attribution more useful than treating removed
decode states as a direct throughput prediction. Only phase 0 was compared;
varied-latency and held-ack phases remain future profiling work.

Repeat-call occupancy:

| State/group | Cycles | Share |
|---|---:|---:|
| S_FETCH | 20,172,306 | 20.99% |
| S_DECODE | 15,724,204 | 16.36% |
| S_MWR | 11,595,000 | 12.06% |
| S_PIPE_REGS | 10,605,701 | 11.03% |
| EA_DISP + EA_EXTW + EA_EXTW2 | 9,414,300 | 9.79% |
| S_IMMF | 5,641,902 | 5.87% |

Next diagnostic priority: separate S_FETCH/extension-consumption costs by
kernel PC and branch outcome. FETCH+IMMF occupy 26.86%, with zero CE stalls
in these states on the repeat: this is not evidence of external-memory wait
or cache-miss latency, and not all occupancy is removable. Decode remains
substantial, but its measured reduction is mostly offset by FETCH occupancy.
After that, brief indexed-EA setup is a bounded candidate to investigate:
each of its three states costs 3,138,100 cycles. Any attempt to remove a stage
must preserve index-register read/forwarding timing and the full-format
fallback. No such optimization is implemented or claimed here.

The fixture adds four tb files and optional monitor/phase/timeout hooks to
`tb_ap040_program.v`; default regression behavior remains unchanged.
