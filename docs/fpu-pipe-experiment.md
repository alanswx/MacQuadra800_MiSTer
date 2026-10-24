# FPU_PIPE at33 MHz

This isolated experiment branches from the tested memory checkpoint
6bfd9c0, tagged pipelined-040-dual-memory-20261023. The only active FPGA
setting changed is the CPU wrapper FPU_PIPE parameter from0 to1. CPU/bus/
SDRAM remain33/33/99 MHz, seed38, with the VRAM-retirement port enabled.
The other optional CPU features remain off; second-slot loads remain off.

The existing arithmetic pipeline handles ordinary FMOVE/FABS/FNEG/FADD/
FSUB/FMUL operations, forwarding results between stages. Its eligibility
guard requires every FPCR exception enable clear. The sequential engine
still handles ineligible operands and operations. This experiment does
not relax that guard or change architectural results.

The saved memory RBF and this candidate will use the same disposable Mac
image,32MB, Ethernet Off and restored baseline PRAM. Separate FPU first
and after-Mix suites, Mix, and PR will be compared with FPGA area/timing.
The earlier0.744 FPU result predates the VRAM port; a new exact baseline
measurement avoids attributing any memory-port effect to FPU_PIPE.

Validation explicitly sets FPU_PIPE=1, LOOP_PRED=0, EARLY_RES=0, SKID=0,
DC1_ATC=0, DUAL=1, BTIC=1 and S1_CLASSES=011. Earlier general regressions
used testbench defaults with LOOP_PRED/EARLY_RES enabled; these new runs
match the hardware option selection. The Quadra adapter tests exercise
the wrapper including the enabled VRAM-retirement path at both ratios.

225 CPU cases and all six adapter cases pass. The existing differential
FPU bench also passes20,000 mixed commands and20,000 pipeline-focused
commands, comparing registers and FPSR against PIPE=0.

Fit and hardware results are pending. The prior tested memory checkpoint
remains preserved independently.
