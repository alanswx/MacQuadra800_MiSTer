# Speedometer 4.02 invalid-timing diagnostic

2026-09-12: invalid negative/near-zero times recur beyond the first run.
Earlier releases also exhibited them. Neither a VIA bug nor a new CPU regression
has been established. Do not average invalid scores into performance results.

Read-only Astra inspection of `/tmp/speedo402-unar/Speedometer 4.02.rsrc`:
the ten-test suite is CODE 3 `RunBMTests`; `TimedCPUTest` is the separate PR test.
The offsets below are physical AppleDouble-file offsets, NOT runtime PCs.

## Timing path selection

File offsets 0x55f29–0x55f33 initialize `[A5-0x36f2]` using TrapAvailable(A193).
Each benchmark selects:

- Nonzero: A193 Microseconds, returning high32 in A0 and low32 in D0.
- Zero: A058 InsTime, A05A PrimeTime, A059 RmvTime countdown helpers.

Trap names are corroborated by local MAME source
`/home/alans/mame/src/mame/apple/mactoolbox.cpp` lines 99 and 174.
Named Start/StopMicroSeconds routines alone do not identify the live path.
The fallback primes -1,800,000,000, removes the task, then adds 1,800,000,000
to its remaining count at task+10. Task pointer `[A5-0x205c]` addresses
`[A5-0x6e04]`; the count is `[A5-0x6dfa]`.

## Bounded observation points

CODE 3 payload begins at file offset 0x62561. Subtract this from the following
to obtain resource-relative offsets; obtain its actual loaded address before
using runtime PC triggers.

| Event | Queens file offset | Sieve file offset |
|---|---:|---:|
| Start Microseconds | 0x65751 | 0x65be5 |
| First instruction after start | 0x65753 | 0x65be7 |
| Benchmark call | 0x6576b (selector 6) | 0x65bff (selector 12) |
| Stop Microseconds | 0x6577d | 0x65c11 |
| First instruction after stop | 0x6577f | 0x65c13 |
| Return from wide subtraction | 0x65793 | 0x65c27 |
| Add elapsed low32 into D4 | 0x657a1 | 0x65c35 |

CODE 4 SubtractWide at 0x741b3 (symbol 0x741e2) implements unsigned low-word
comparison/borrow and 64-bit subtraction. The callers use elapsed low32 at
`[A6-4]`, accumulate into D4, and increment D5. They repeat kernels until
TickCount reaches an initial deadline plus 0x78 ticks. Outer averaging and
SANE conversion happen afterward and remain possible failure locations.

For a single Queens/Sieve invocation, cap observation to a few hundred records:

1. Timer-selector byte and runtime code identity.
2. Start/stop A0:D0 after each clock trap, with simulator cycle stamps.
3. Host-computed unsigned 64-bit delta versus guest elapsed `[A6-4]`.
4. D4/D5 around accumulation and returned TickCount/deadline.

Respect guest MMU translation for memory reads, or observe writes; do not read
virtual addresses directly from physical RAM and treat them as evidence.

| Observation | Next investigation |
|---|---|
| Raw clock delta wrong; actual kernel cycles normal | Clock-trap execution, OS timer implementation, VIA reads |
| Raw clocks correct; guest subtraction wrong | CPU arithmetic/addressing or memory corruption |
| Subtraction correct; aggregate/result wrong | Accumulation, division or conversion |
| Actual kernel cycles collapse | Benchmark execution/control flow, not just displayed time |

For the fallback, capture task+10 after RmvTime and check the fixed addition
against actual elapsed cycles. Local iosb.sv supplies a constant divider-driven
timer tick independent of CPU CE; that observation does not prove correctness
or explain the failure. No timing-path fixes have been made on this evidence.
