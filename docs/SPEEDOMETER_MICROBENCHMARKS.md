# Original Speedometer loops on CPU and RAM

These tests execute extracted, unchanged Speedometer 4.02 machine code at
its original CODE-relative addresses. They instantiate `wombat_cpu`, including
its actual cache and store buffer, with a 64 KB byte-addressable RAM responder.
They do not boot Mac OS or implement the Toolbox. Interrupts are masked;
MMU translation is not enabled. RAM acknowledgment latency is controlled.
The platform SDRAM controller, device contention and real guest scheduling
are absent, so cycle counts compare CPU variants, not Speedometer scores.

Existing runners cover Permutations, Bubble Sort, Queens and Quick Sort;
Towers is also covered by the existing extracted-kernel fixtures. Sieve now
uses the same checked responder and profiling counters as Quick Sort.

## Sieve

```sh
python3 scripts/cpu/profile_sieve.py \
  '/home/alans/mister/MacQuadra800_fixtures/Speedometer 4.02.rsrc' \
  --out scratch/sieve-example --early-drain --compare --profile \
  --disassemble --latencies 0 3 8
```

The resource SHA256 must match the known fixture. `--core`, `--alu` and
`--muldiv` select isolated candidate sources without changing production RTL.
`--disassemble` requires Python Capstone and writes `kernel.dis`.
Generated `sieve.bin`, assembly, program image, oracle, source hashes and
per-latency logs remain in the output directory.

The original Sieve routine allocates RAM with a Mac trap, runs 100 passes,
and disposes it. The extracted range is CODE3 `0x0b6a..0x0bad`: one complete
pass, including initialization of all 8,191 flags and the prime-marking loops.
There are no external calls in this range. The harness supplies RAM at
`0x9000`, invokes the original bytes, and returns through an added RTS outside
the extracted range. Allocation, disposal, the outer repetition and UI/timers
are excluded. Kernel bytes and branch displacements are unchanged.

A Python trial-division reference independently computes primality for every
odd number from 3 through 16,383. The simulator checks all 8,191 flag bytes,
the guest's D7 count (1,899), and guards on both sides of the buffer. A negative
control replacing the guest's composite-clearing instruction with NOPs fails
with count8,191, demonstrating rejection of an incorrectly executed loop.

## First comparison, 2026-09-20

| CPU | RAM latency0 | latency3 | latency8 |
|---|---:|---:|---:|
| P64, 64-byte refill | 303,820 | 309,734 | 377,576 |
| P73, shared 128-byte refill | 303,820 | 309,734 | 377,576 |

All prime flags, counts and guards pass. Evidence: `scratch/sieve64_20260920`
and `scratch/sieve73_final_20260920`. P64 core hash starts609b1687;
P73 startsa4875880; full source identities are in each `current/identity.json`.
The larger refill does not improve this loop. At latency3, the profile records
106,055 queue-ready `S_PIPE_REGS` clocks and only144 empty-fetch clocks;
this points toward execution-path costs for this workload, not refill capacity.
Counters describe distinct conditions and must not simply be added together.

The original Quick Sort regression remains178,422cycles at latency3 with
sorted-permutation and guard checks passing. The Sieve build took about8s;
its simulation runs take under a second each on this host. Compile time varies.

Use these small tests to screen and diagnose changes, then run CPU correctness
and fault/interrupt regressions before fitting. Hardware still decides whether
a candidate improves the complete benchmark. Whetstone extraction must retain
its SANE/math dependencies; replacing those calls with stubs would invalidate
that workload.
