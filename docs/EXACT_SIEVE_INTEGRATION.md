# Exact Sieve: alignment and RAM-path profiling

This measures relative execution costs of the unchanged Speedometer 4.02
integer kernel, not an absolute Speedometer score or MacOS workload latency.
The new fixture stops after the **first original outer pass**; it does not
replace the original full-100 correctness fixture described in
[EXACT_SIEVE_PROFILING.md](EXACT_SIEVE_PROFILING.md).

## Provenance and measurement

The 80 bytes at resource file offsets `[0x630c7,0x63117)` (CODE 3 offset
`0xb66`) have SHA256
`345defabade69898e7c3300557944301ea7a1dc5cd2b6472326c524e5bf8882a`.
The existing preparation script verifies the original resource identity.
Only the wrapper's absolute call and placement change across alignments; the
runner asserts the extracted bytes are identical in every assembled image.

Entry is post-NBA S_DECODE at kernel base. Exit is post-NBA S_DECODE at
base+0x4a (CMP #100,D6) when effective D6=1, forwarding a matching pending
register write. Cycle/state sampling covers `(entry,exit]`. Dispatch counts
use the real dispatch toggle, exclude the entry dispatch and include the exit
dispatch; these are consumed opcodes, not retired-instruction counts.

The independently trial-divided odd-number oracle checks D7=1899, A2, every
one of the 8191 array bytes and both sentinel guards. Backing RAM is read only
after asserting no buffered/draining store remains. SDRAM model protocol
errors are fatal. This first-pass check is deliberately bounded.

## Integration fixture

[`scripts/fixtures/wombat_sieve`](../scripts/fixtures/wombat_sieve) instantiates
the actual wombat_cpu (core/MMU/cache/two-entry store buffer), wombat_bus32,
sdram_beat32 and SDRAM controller/model at the existing 33/99MHz test cadence.
Its RAM-only service duplicates the current quadra800 direct-miss eligibility
and registered completion/retained-line data behavior. It is not a full
quadra800: no overlay, devices, DMA, interrupts, MacROM or MacOS are emulated.
Vectors and the standalone RAM payload are preloaded into the SDRAM model.
Unexpected addresses or MMU walker requests fail rather than returning fake
data. Chosen CACR=0x80008000, TC=0 and constant CE=1 are printed explicitly.

This differs from the AP fixture's artificial 16-bit memory response, stalled
core/MMU/cache clock enable and absent store buffer/retained-line sideband.
Those differences alone must not be blamed for hardware benchmark results.
Actual MacOS CACR/TC, runtime placement and IRQ activity remain to be measured.

Run serially per source tree (the assembler uses a shared build/incbin file):

```sh
VASM=/tmp/wombat-vasm/vasmm68k_mot \
VERILATOR=/home/alans/verilator5/bin/verilator JOBS=4 \
sh scripts/fixtures/wombat_sieve/run.sh \
  '/tmp/speedo402-unar/Speedometer 4.02.rsrc' \
  /absolute/path/to/complete/ap68040/rtl /tmp/unique-output 0 6
```

Use an isolated source checkout to keep generated fixture files out of an
active tree. Pass all even offsets 0 through30 for an integration sweep.
The AP RTL argument must contain all supporting modules, not only core.v.

## Measured alignment effect (2026-09-12)

Accepted compact core SHA256 starts `5ab7603019ab`; experimental refill core
starts `2bbc1f3d6abb`. All 32 AP runs pass the first-pass oracle; each has five
I-cache misses, with identical A/B request/cache counts at a given placement.

| Base mod32 | AP compact cycles | AP refill cycles |
| ---: | ---: | ---: |
| 0 | 961299 | 932741 |
| 2 | 920158 | 920158 |
| 4 | 913734 | 913734 |
| 6 | 916352 | 916352 |
| 8 | 918137 | 918137 |
| 10 | 895668 | 895668 |
| 12 | 907655 | 907655 |
| 14 | 915639 | 915639 |
| 16 | 909350 | 909350 |
| 18 | 949639 | 921081 |
| 20 | 979967 | 951409 |
| 22 | 945832 | 917274 |
| 24 | 984367 | 955809 |
| 26 | 963997 | 935439 |
| 28 | 982073 | 953515 |
| 30 | 961498 | 932940 |

The 32-byte BRF sector, four-word seed, and subsequent tag replacement make
the refill opportunity alignment-dependent. The hot marking-loop target is
kernel+0x2e and its backedge kernel+0x3c. Half the tested placements lose the
entire refill benefit. CODE-relative 0xb66 has offset6, but the runtime CODE
allocation base is unknown; do not assume the guest kernel also has offset6.

| Base mod32 | Real RAM-path compact | Real RAM-path refill |
| ---: | ---: | ---: |
| 0 | 906241 | 877679 |
| 6 | 861298 | 861298 |

All four integration runs pass array/guard/drain/protocol checks. Each has five
I-cache misses, 512 D-cache misses, 517 external reads and 23190 writes.
The real RAM-path fixture retains the same alignment-dependent opportunity.
This supports alignment as a sufficient explanation for loss of synthetic
gain; it does not establish the actual cause of any specific hardware run.

Every integration placement spends 31381 cycles each in S_EA_DISP,
S_EA_EXTW and S_EA_EXTW2. The next experiment therefore targets common indexed
EA setup rather than another alignment-dependent BRF special case.

Evidence: `/tmp/ap040-sieve-alignment.qbjC08/{compact,refill}/offset-N.log`,
with full reproduction notes in that tree's HANDOFF.md; integration evidence
in `/tmp/wombat-sieve-integration.Tumycd/{compact,refill}/offset-{0,6}.log`.
The production-source files used by the integration runner are hashed in its
output. No production RTL was changed to obtain these measurements.
