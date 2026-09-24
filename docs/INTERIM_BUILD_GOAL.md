# Interim full-feature build goal

Updated September 24, 2026 at the user's request. This document refines the active fitting goal and defines the order of subsequent work.

## Immediate deliverable

Produce a reproducible MacQuadra800 FPGA build that fits the target MiSTer FPGA with normal Mac and MiSTer functionality enabled, including Ethernet, CD-ROM, CD audio, and hard-disk caching. Preserve CPU correctness and retain the demonstrated CPU performance improvements wherever practical. Prefer measured structural area reductions before disabling features or sacrificing performance.

Completion requires:

- A successful full Quartus build with a fresh RBF tied to its exact source commit and configuration.
- Recorded fitted resource usage, timing results, and clock-crossing checks. Report every unresolved timing failure or exception explicitly; fitting alone is not validation.
- Passing relevant simulation regressions, with experimental pipeline coverage distinguished from legacy CPU coverage.
- Hardware boot, shutdown, and relevant peripheral checks, followed by five valid Speedometer runs using the disposable test disk. Record individual metrics and compare with the prior working build and real Quadra 800 reference.
- Committed and pushed source changes, validation evidence, and an updated handoff identifying remaining limitations.

Aim to retain performance near 1.8 Speedometer, but do not make achieving 1.8 or real-Quadra parity (approximately 1.89) a prerequisite for delivering the validated interim build. Explicitly report any performance regression, feature omission, or untested functionality. A/UX testing is deferred to Dani because its disk image is unavailable.

## Operating constraints

Use Luna for routine builds, simulations, monitoring, and hardware operation where practical. Preserve ongoing Quartus jobs; concurrent builds require separate project directories. Use MiSTer hardware only when the user confirms it is available. The latest availability state is that the user is using it. Commit and push meaningful progress to origin/add-ethernet.

## Follow-on work, after the interim build

1. Assess memory placement globally: FPGA block RAM, SDRAM, and DDRAM for VRAM, ROM, CPU caches, and disk buffers. Compare capacity, latency, burst throughput, contention, coherency, and FPGA logic cost. Treat larger on-chip L1 caches with external burst refill as a hypothesis to evaluate, not an agreed redesign.
2. Profile disk performance and identify the measured bottlenecks affecting interactive use.
3. Write an evidence-based disk improvement plan before implementing disk changes.

After the interim build is validated, decide whether further CPU work toward 1.89 or disk work offers the better practical benefit. Do not expand the current fitting effort into either redesign prematurely.
