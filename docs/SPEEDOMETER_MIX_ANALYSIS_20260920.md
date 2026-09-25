# Speedometer 4.02 Mix calculation and profiling priorities

## Evidence and scope

Read-only analysis of the original CODE 3 resource, SHA256
`02123c6cb020961c79cbb66cbadef9247a1add4c480b421645d2a4a4c3fefc31`.
The enclosing fixture is documented in the kernel profiling notes. No benchmark
bytes, reference values, machine settings, or scoring rules were changed.
Disassembly is saved locally as
`scratch/speedo_kernel_profile_20260919/DoBMAve.dis`.

The routine starts at CODE-relative `0x4718` (LINK A6), ends at `0x4d2a`
(RTS), and is followed by the Pascal debug name `DoBMAve`. Starting two bytes
earlier produces a misleading disassembly; use the actual instruction boundary.

Static interpretation: the routine accumulates ten normalized ratings and divides
by the number of included values. Each included component increments D3 once.
The first two use a stored floating result divided by a reference value; the
remaining eight use reference times multiplied by iteration counts, divided by
measured elapsed times. This is an arithmetic mean, not a geometric mean or an
average of raw elapsed seconds. This interpretation has not yet been checked
with a standalone execution of this routine against a complete guest record.

The record offsets are:

| Component positions | Measured values | References |
|---|---|---|
| First two | `0x4ba`, `0x4c2` | `0x572`, `0x57a` |
| Remaining eight | `0x4ca` through `0x4e6`, step 4 | `0x582` through `0x5ba`, step 8 |

There are ten ADDQ.W #1,D3 sites. The final division by D3 is at `0x4cca`
through `0x4cd6`, and the resulting double is stored at record `0x4ea`.
The first two inclusion checks use SANE classification; the eight elapsed-time
checks exclude zero values. This is not sufficient validation of timer results:
impossible nonzero values still require exclusion under our hardware protocol.

SANE operation interpretation was cross-checked against the implementation of
[FP68K in systemless](https://docs.rs/systemless/latest/src/systemless/trap/sane.rs.html):
operation 0 adds, 4 multiplies, 6 divides destination by source; 0x0e and 0x10
convert to and from extended precision. This source is corroboration of opcode
semantics, not evidence that the guest uses that emulator or of its performance.

## Consequences for the next experiments

Root re-inspected `scratch/hardware_p39refill64_20260919/run5_complete.png`.
Its columns are **Abs.**, **Rat.**, and **Itr.**. The hardware report's Towers,
Quick, Bubble, Queens, Puzzle, Permutations, Int. Matrix, and Sieve numbers are
elapsed seconds, not normalized ratings. Do not add those numbers to estimate
Mix contributions. The completion dialog hides some of the rating column.

Visible run-5 ratings are Whetstone 2.947, Dhrystone 0.723, Permutations 0.674,
Int. Matrix 1.014, and Sieve 1.226; Mix is 1.105 with all ten tests selected.
Under the arithmetic-mean interpretation, Whetstone contributes about 26.7%
of the current sum (2.947 / 11.05). Whetstone plus Dhrystone contribute about
33.2%. Display rounding limits this precision.

This makes profiling the original Whetstone workload a worthwhile next step.
Its SANE and external math calls must be retained; stubbing them would remove
the work being measured. The calls alone do not establish whether software
arithmetic, the FPU, traps, instruction dispatch, or memory traffic dominates.
Measure that before choosing an optimization.

P57's approximately 0.7% Permute and 1.0% Towers simulation-cycle improvements
remain useful candidates, but do not establish a hardware Mix improvement.
For scale only: if the *complete hardware* Permutations test became 1% faster
and all other tests were unchanged, its current 0.674 rating would add only
about 0.0007 to Mix. This conditional estimate is not a P57 prediction.
The gap from 1.105 to 1.8 still requires about 63% aggregate improvement.
