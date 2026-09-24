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
| Full-width explicit barrel after BRF banks | 27,879 | 28,000 | Reject: grows121 |
| Barrel queue line-fill | 29,024 | 28,799 | Useful:54 below static line-fill |
| FPU sticky barrel | 27,879 | 27,979 | Reject: grows100 |
| Shared integer ALU rotates | 27,879 | 27,161 | Useful:718 smaller; combined tests pending |

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

Shared integer rotates are preserved as scripts/cpu/alu_rotate_shared.patch.
One33-bit rotate datapath serves ROL/ROR/ROXL/ROXR. Right rotations become
left rotations by container-width minus amount; the container includes X
only for ROX. Existing result masks and carry/extend choices remain in their
operation arms. No clocked state or instruction latency changes.

The differential miter checks both PIPELINE_SUBSET modes, all byte inputs,
all counts0..63, both X states (flags[4]), word/long one-hot patterns and
randomized data/flags. A wrong-direction mutation fails. Candidate adds
op-dependent muxing before the barrel, so timing must still be measured.
Map-exact ALU hash d6ce0e32a62c19794d165ec6099e5e0ad9281cd2a73785e5dbf1e95cc2b8579f;
whitespace-clean ALU hash72ec6209972d51f6ffd52c4f914de6c7e93c21c7686130e890b2f5369660b93e.
Evidence: scratch/cpu_area/{rolshare_miter,p_rolshare_01e7d41,tree_rolshare}.
Luna is testing combined BRF + barrel line-fill + shared rotates before
promotion. A separate shared logical/arithmetic shifter is still screening.

## Combined candidate for full fitting

BRF + barrel line-fill + shared ALU rotates + bitfield concat rotate maps
at26,864 ALMs/8,966 regs:1,015 belowBRF-only27,879. This is108 fewer ALMs
saved than adding the independent225+718+180 estimates. Source snapshot:
scratch/combined_area_20260924/tree; report:
scratch/cpu_area/p_brf_linebar_alushare_rotconcat_sep24.

Promoted this exact combination for a full-feature fit, interim_mac_muxshare,
withALWAYS routability setting restored. Standalone equivalence checks pass
for each change; integrated regression of the exact combination is running
in parallel with fitting. The previously tested combined candidate omitted
only the bitfield-concat change. No hardware gate is satisfied by compilation.
The separate logical/arithmetic shifter is not included.

## Exact four-way regression completed

The full-feature fit candidate at source commit
55ed03eb901f1ed1222bc599ee59a9ff104bb544 passed its integrated simulation
checks. The legacy CPU suite exited 0: 28 positive tests and three expected
negative controls. This suite does not enable the experimental pipeline;
its IRQ and fault tests must not be presented as pipeline coverage.

All six Speedometer kernel fixtures enable the production experimental
pipeline macros, including memory entry, compare, and early drain. Each
passed its output oracle and negative control. Controlled RAM latency was
three cycles; observed cycles were unchanged:

| Kernel | Cycles |
| --- | ---: |
| Towers | 16,076,616 |
| Puzzle | 22,780,447 |
| Quick | 141,278 |
| Matrix | 2,198,407 |
| Sieve | 271,364 |
| Bubble | 2,958,987 |

Each fixture exercised accepted line offers, nonempty queue fills, and
wrapped destinations. Sieve has only one wrapped destination, so the
standalone exhaustive queue-fill equivalence check remains important.
These tests use a controlled memory responder, not the complete Mac memory
system, and do not establish hardware timing or a Speedometer score.

Evidence: scratch/alu_rotate_linefill_bitfield_20260924/results_four_way.txt,
cpu_tests/run_tests.wrapper.log, fixtures/speedometer_suite.wrapper.log,
and per-fixture identity.json and logs in that same directory. Core SHA256:
a309fd758e9f38f08be9bfa4fe6e707f18e81cf195757740809b6c82d39b3dc0.
ALU SHA256:
72ec6209972d51f6ffd52c4f914de6c7e93c21c7686130e890b2f5369660b93e.

The separate logical/arithmetic shifter maps at 27,756 ALMs on the banked
BRF baseline (123 fewer). Combined with shared rotates it maps at 27,028
versus 27,161 for shared rotates alone, an incremental 133-ALM reduction.
This change is not in the current full fit. Exact integration with all four
current reductions is being tested and measured separately; do not add
independent area savings as though they were guaranteed full-fit savings.
