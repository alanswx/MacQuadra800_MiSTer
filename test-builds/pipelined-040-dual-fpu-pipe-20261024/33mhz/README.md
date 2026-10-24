# FPU_PIPE 33 MHz experiment

Only FPU_PIPE is enabled over memory checkpoint `6bfd9c0`. CPU/bus/SDRAM
are 33/33/99 MHz, seed 38, stamp 261024. The fit uses 35,631 ALMs (85.02%),
31,097 registers, 497 M10Ks and 38 DSPs. All timing passes: CPU/bus +0.964 ns,
SDRAM +0.377 ns, HDMI +0.357 ns, minimum hold +0.109 ns.

Mac OS 8.1 boots with working input. Matched hardware results: FPU first
0.750, after Mix 0.749; Mix 1.806; PR 1.623 (CPU 1.806, graphics 0.985,
disk 2.417, Math 13.313). Clean Finder shutdown passes; the board is back
at Menu with the original disk selection and PRAM restored.

The smaller baseline keeps FPU_PIPE=0: this candidate adds 1,077 ALMs
(3.12%) for only 0.67–1.21% higher FPU scores, with unchanged PR Math.
Each suite used one iteration. See the [full comparison and evidence](../../../docs/fpu-pipe-experiment.md).

Exact hashes and pinned source are in artifact.json. This is an experiment;
A/UX and CD audio have not been requalified, so it is not a release RBF.
