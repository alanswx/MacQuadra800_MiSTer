# Full-feature fit experiments, September 24

Target: normal MiSTer functions, Ethernet, CD/CD audio and disk caches;
8 KB instruction + 8 KB data CPU caches; CPU speed macros enabled. Hardware
is reserved by the user. No candidate in this table has produced a new RBF.

| Full design | Commit | Fitter ALMs | Result |
| --- | --- | ---: | --- |
| Normal feature baseline | becb472 | 43,806 | 1,896 over capacity |
| Banked BRF seed mux | 01e7d41 | 43,338 | 1,428 over capacity |
| Same BRF RTL, forced routability optimization disabled | e5f189e | 43,736 | Reject:398 larger than BRF ALWAYS |

Capacity is41,910 ALMs. The BRF change saves468 ALMs in the full design,
although standalone CPU synthesis saved1,145. Do not add standalone savings
to predict fitter utilization. Failed fits pass source-manifest checks;
no new timing result was produced. Archives live under scratch/<tag>_fit_20260924.

| Independent CPU screen | Baseline ALMs | Candidate ALMs | Decision |
| --- | ---: | ---: | --- |
| Banked BRF seed | 29,024 | 27,879 | Promoted and full-fit measured |
| Static queue line-fill destinations | 29,024 | 28,853 | Promoted after combined CPU tests pass |
| Shared FSAVE payload | 29,024 | 29,063 | Reject: grows39 |
| Shared FRESTORE payload | 29,024 | 29,151 | Reject: grows127 |
| Explicit barrel after BRF bank selection | 27,879 | 28,072 | Reject: grows193 |

All completed CPU screens retain8,966 registers. Exact settings and source
paths are in scratch/cpu_area/p_<tag>/cpu.qsf, with summaries in results.txt.

BRF + static line-fill passed full CPU self-tests and six integer fixture
oracles/negative controls. All six cycle counts match BRF alone. The bound
real-cache monitor proves nonzero line fills and destination wrap in each
fixture (Sieve has one wrap, the others thousands). Evidence:
scratch/brf_linefill_20260924/{cpu_tests/run.log,suite/,line_fill_cov.sv}.
This is not a hardware Speedometer score or proof of peripheral operation.

Still being screened: a single rotate expression for bitfields, explicit
barrel queue fill, shared integer ALU rotates, and a combinational FPU
sticky barrel. These are scratch variants; do not promote unmeasured forms.

The FPU sticky variant is preserved as scripts/cpu/fpu_shift_jam.patch.
It replaces the variable lost-bit mask with seven combinational barrel
stages, ORing shifted-out bits into bit zero. It retains the one-cycle
F_SHR state and all counter/control updates; it does not restore the old
multi-cycle shifter. Exact old/new calculations passed139,648 comparisons:
all128 shift counts, all67 one-hot inputs, and1,024 random67-bit operands.
A missing final sticky contribution fails the negative control. Evidence:
scratch/fpu_shift_jam_20260924/{prepare.py,tb.sv,equivalence.log,negative.log}.
CPU integration and area are pending.

The NEVER fitter experiment finished Sep24 16:37:50, sourceafter0/build3.
It reused unchanged synthesis through Quartus smart compilation; the wrapper
correctly reports no fresh map/STA/RBF. ALWAYS is restored. Static line-fill
is now promoted on top of banked BRF after exact combined regression; no
other scratch arithmetic change is integrated and no new fit is launched
until the remaining area screens guide the next candidate.
