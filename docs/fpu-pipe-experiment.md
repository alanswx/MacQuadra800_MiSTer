# FPU_PIPE at 33 MHz

This isolated experiment branches from the tested memory checkpoint
6bfd9c0, tagged pipelined-040-dual-memory-20261023. The only active FPGA
setting changed is the CPU wrapper FPU_PIPE parameter from 0 to 1. CPU/bus/
SDRAM remain 33/33/99 MHz, seed 38, with the VRAM-retirement port enabled.
The other optional CPU features remain off; second-slot loads remain off.

The existing arithmetic pipeline handles ordinary FMOVE/FABS/FNEG/FADD/
FSUB/FMUL operations, forwarding results between stages. Its eligibility
guard requires every FPCR exception enable clear. The sequential engine
still handles ineligible operands and operations. This experiment does
not relax that guard or change architectural results.

The saved memory RBF and this candidate will use the same disposable Mac
image, 32 MB, Ethernet Off and restored baseline PRAM. Separate FPU first
and after-Mix suites, Mix, and PR will be compared with FPGA area/timing.
The earlier 0.744 FPU result predates the VRAM port; a new exact baseline
measurement avoids attributing any memory-port effect to FPU_PIPE.

Validation explicitly sets FPU_PIPE=1, LOOP_PRED=0, EARLY_RES=0, SKID=0,
DC1_ATC=0, DUAL=1, BTIC=1 and S1_CLASSES=011. Earlier general regressions
used testbench defaults with LOOP_PRED/EARLY_RES enabled; these new runs
match the hardware option selection. The Quadra adapter tests exercise
the wrapper including the enabled VRAM-retirement path at both ratios.

225 CPU cases and all six adapter cases pass. The existing differential
FPU bench also passes 20,000 mixed commands and 20,000 pipeline-focused
commands, comparing registers and FPSR against PIPE=0.

Fit and hardware results are pending. The prior tested memory checkpoint
remains preserved independently.

Initial synthesis passes the memory/dual guards: 36 RF MLAB banks, 4 tag
M10Ks and 3 framework M10Ks. Mapped registers increase 29,318→30,241;
block-memory bits remain 3,722,339 and DSPs 38. Fitted ALMs/timing remain
pending. The separate project and source manifest preserve the controlled
comparison.

The seed 38 fit passes all setup/hold/recovery/pulse checks. It uses 35,631
ALMs (85.02%), 1,077 more than the memory baseline (3.12% relative).
Fitted registers 31,097; M10Ks 497 and DSPs 38 unchanged. Setup slacks:
CPU/bus +0.964ns,SDRAM +0.377ns,HDMI +0.357ns;minimum hold +0.109ns.
All eight extra path reports and the exact experimental RBF are preserved
under docs/perf/fpu_pipe_20261024/fit-s38 and test-builds/.

Matched memory-baseline hardware results (exact MD5 500c3661...):
FPU first 0.741,after-Mix 0.744; Mix 1.802; PR 1.604 (CPU 1.807,graphics 0.985,
disk 2.228,math 13.313). All suites used one iteration and the same order.
Clean Finder shutdown and original settings restoration pass before the
candidate is loaded. Disk differences remain sensitive to host/storage.
