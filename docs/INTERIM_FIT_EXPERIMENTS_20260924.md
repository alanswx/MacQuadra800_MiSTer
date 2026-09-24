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

## Full four-way fit result

`interim_mac_muxshare`, source 55ed03e, finished with build exit 3. Mapping
estimated 40,434 ALMs; fitting required **42,058 / 41,910 ALMs** and
**4,252 / 4,191 LABs**. Error 170012 reports insufficient LABs. This saves
1,280 fitted ALMs versus the banked-BRF-only attempt (43,338), but remains
148 ALMs and 61 LABs over capacity. Those deficits are different resource
constraints; removing 148 estimated ALMs alone does not guarantee a fit.

Source integrity passed (source_check_after=0). No fresh STA or RBF was
produced; crossing and CPU timing stages were skipped (exit 77). Reports,
exit files, and source manifests are archived in
`scratch/interim_mac_muxshare_fit_20260924`. Existing output RBF files must
not be mistaken for this candidate. Exact integrated simulations passed as
recorded above; hardware validation remains pending a fitted artifact.

Next measurements are the exact five-way shared-shifter combination and
an optional common ALU for pipeline and legacy execution. The latter needs
additional ownership, dependency, fault, and interrupt validation before
promotion. A read-only review of packing overhead is also in progress.

## Five-way shared-shifter candidate

Adding the shared logical/arithmetic shifter to 55ed03e maps at 26,722 ALMs
and 8,966 registers, saving 142 estimated CPU ALMs versus 26,864. The exact
candidate passed 323,296 differential ALU comparisons and the legacy CPU
suite (28 positives, three expected negative controls). Six production-
pipeline Speedometer fixtures are running in parallel with full fitting;
this is not yet a fully validated candidate or a fitted artifact.

The only post-map change corrects an obsolete ASR comment. Mapped ALU SHA256:
7e83d5118b76ab6500fb86d261c5db9fdec948d0d276e379802f109ad032a277.
Production/fixture ALU SHA256:
3c7f2f1329d72959718fbf96b8797f8e476123824ce7f328a07e68268903a7b2.
Core remains a309fd758e9f38f08be9bfa4fe6e707f18e81cf195757740809b6c82d39b3dc0.
Evidence: scratch/alu_shared_fourway_20260924/{miter,cpu_tests,fixtures}
and scratch/cpu_area/p_alushared5_55ed03e.

The completed packing review found only one recoverable ALM and 1,075 ALMs
unavailable from LAB input limits. Prior register-packing experiments did
not improve density, so the next full fit retains existing fitter settings.
All normal Mac features and current cache sizes remain enabled unchanged.

### Five-way simulation checks complete

The exact production ALU hash 3c7f2f1329d72959718fbf96b8797f8e476123824ce7f328a07e68268903a7b2
passed all six production-macro fixtures at RAM latency three. Every oracle
and required negative control passed; cycles and line-fill coverage counts
match the four-way results above. Evidence:
`scratch/alu_shared_fourway_20260924/results.txt` and its wrapper logs and
per-fixture identities. This completes these simulation checks, not timing
or hardware validation.

The full-feature `interim_mac_shiftshare` build is running from source
86d48df77b6944c682a6f3e24b7163a42f5f11b0, archive
`scratch/interim_mac_shiftshare_fit_20260924`. Tracked HDL remains frozen.

Additional directed pipeline fault/IRQ baseline results on 55ed03e are
recorded in `docs/PIPELINE_BASELINE_VALIDATION_20260924.md`. They distinguish
exact production admission from specialized tests using FORCE_DECODE.

## Full five-way fit result

`interim_mac_shiftshare` at source 86d48df finished with build exit 3.
Mapping estimated 40,055 ALMs; final ALMs needed were **41,764 / 41,910**,
but the design requires **4,226 / 4,191 LABs**, so error 170012 still prevents
fitting. Relative to the four-way result, this removes 294 fitted ALMs and
26 LABs. The remaining deficit is 35 LABs, despite 146 ALMs of reported
headroom. ALM utilization alone is therefore not an adequate success gate.

Final placed ALMs were 40,592, with one recoverable by dense packing and
1,173 unavailable (53 from LAB-wide conflicts, 1,120 from LAB input limits).
Source-after integrity passed. No fresh STA/RBF; crossing and CPU timing
stages skipped with exit 77. Archive:
`scratch/interim_mac_shiftshare_fit_20260924`.

Keep this shared-shifter change as the best measured full-feature baseline.
The common-ALU prototype remains separate, pending its area screen and
production fault/interrupt tests before combining with this baseline.

## Common ALU integration candidate

The isolated common-ALU prototype on the four-way 55ed03e baseline maps at
25,950 ALMs / 8,966 registers, saving 914 CPU ALMs against 26,864. It shares
the complete core ALU with the integer pipeline when `pipe_rf_owner` is
true. The pipeline's standalone default retains its internal subset ALU.
No pipeline stages, ready signals, or instruction cycles are added.

The legacy fast-operation capability predicate remains separately decoded:
during a direct pipeline memory retirement, stale legacy decode state can
still gate branch lookahead even though the pipeline owns the ALU result.
A simulation assertion checks EX work owns the external ALU. The prototype
passes a 49,344-case full/subset ALU contract check, the legacy CPU suite,
all six benchmark kernels with unchanged cycles, directed dependency tests,
and the fault/IRQ matrix in
`scratch/alu_owner_shared_20260924/PIPELINE_FAULT_IRQ.md`. Some specialized
IRQ cases force admission; production P6 and branch tests do not.

The next full-fit candidate combines this ownership change with the existing
shared shifter from86d48df. Exact combination passes the contract miter and
production dependency/drain test (742/1086/1086 cycles; all required counts).
Its six-kernel suite and CPU map continue in parallel with full fitting.
Added ALU input muxing may affect timing; area/functional tests cannot prove
clock closure. Do not call this hardware validated.

Combined source: scratch/alu_owner_combined_86d48df. Core SHA256:
2b92366c91720f49ba7e16b740169b7e6601dc2d833960aa874037b3b265b63e.
Pipeline SHA256:
92ea4d96a5b2da0784e65fe2015118e4889353a7df83e4ccca8bf6a1e7059435.
ALU remains3c7f2f1329d72959718fbf96b8797f8e476123824ce7f328a07e68268903a7b2.

### Exact common-ALU/shared-shifter fixtures completed

The combined candidate promoted at4f90d54 passes all six production-macro
fixtures at RAM latency three, with the same cycle counts as the preceding
candidates. All six required negative controls passed, including Puzzle's
KOUNT increment mutation (expected2005 becomes4010). Evidence:
`scratch/alu_owner_combined_86d48df/regress/speedometer/*.log` and per-fixture
identities. Combined contract miter evidence is `contract_miter.log` in
that snapshot: 49,344 checks pass. Full fit `interim_mac_onealu` is running
from4f90d5409fbef11f481477035cb298f1fd1ce20b; no timing claim yet.

The hardware procedure is preserved in `docs/INTERIM_HARDWARE_VALIDATION.md`.
It requires current hardware availability and includes separate data-CD and
audible CD-audio checks, protected-original/disposable-disk handling, and
explicit limits on historical performance comparisons.

### Exact combined fault/IRQ validation and deferred test maintenance

The exact4f90d54 combined core/pipeline/ALU hashes now pass the complete
established directed matrix: MOVE standard and d16 seven-case fault tests,
production P6 and CMP/TST faults, five branch-boundary cases, IRQ handoff,
and read-ack IRQ. Required event counts match the prototype. Test-only
FORCE_DECODE remains limited to the specialized IRQ runners. All wrapper
exits are zero. Evidence is preserved under
`scratch/alu_owner_combined_86d48df/regress/fault_coverage/`; complete commands,
hashes, warnings, and scope are in that snapshot's `RESULTS.md`.

Exact combined CPU map:25,865ALMs/8,966registers, an857ALM reduction versus
shared-shifter-only26,722. Full design map for the active `interim_mac_onealu`
run estimates39,354ALMs,701 below the prior40,055. Fitting is still pending.

Two tested harness patches are preserved but MUST wait until the active
full flow and source-after check finish before application:

- `scripts/cpu/pipeline_optional_alu_tb_tieoffs.patch`: three standalone
  wildcard benches require explicit zero inputs/open outputs for the new
  optional ALU interface. Their default internal-ALU mode is unchanged.
- `scripts/cpu/pipeline_store_oracle_mutation.patch`: the prior wrong-An
  mutation matched an obsolete assignment and did nothing. The corrected
  mutation changes only the store update and requires exactly one match;
  the cancellation mutation now requires exactly one match too.

In scratch, prototype modes0-5 each pass8,608 retirements and forwarding
negative; all8 PEA configurations pass5,006 retirements/1,056 requests and
both negatives; all8 store configurations pass5,799 retirements/996 stores,
wrong-An negative, cancellation positive, and cancellation negative. Logs:
`regress/default_stores/` and other standalone outputs listed in RESULTS.md.
These fixes do not change synthesizable CPU behavior, but the tracked .sv
benches are included in the current build integrity manifest and remain
untouched until that build is terminal.

## Common-ALU full fit: placement passes, routing fails

`interim_mac_onealu` at4f90d54 finished build exit3, source-after0, cross77,
CPU timing77. Final resources: **41,002 / 41,910 ALMs**, **4,155 / 4,191 LABs**.
Placement succeeded (170137), but routing failed with16684/16618/170143.
Average interconnect estimate50%, peak82% inX45_Y23..X55_Y34. Diagnostic188005
reports excessive hold-delay demand;188026 suggests a seed change or
aggressive routability. ALWAYS routability is already enabled. No fresh
STA/RBF; archive scratch/interim_mac_onealu_fit_20260924.

Next controlled experiment changes only fitter seed28 to21; CPU RTL,
features, timing constraints, and all other fitting settings stay unchanged.
Unlike earlier capacity failures, this failure explicitly reaches placement
and identifies routing congestion, making a seed trial relevant. A separate
read-only review will inspect actual hold-delay endpoints rather than
relaxing constraints. Seed21 is an experiment, not a predicted timing fix.

After the terminal source-after check, the two previously validated test
patches were applied: optional ALU port tieoffs in the three standalone
benches and robust store/cancellation mutations in the oracle runner. These
are test maintenance and do not alter the synthesizable design. Positive
and negative validation was completed on their exact scratch contents.

### Read-only hold-delay diagnosis of seed28 failure

The largest hold-summary bucket is1,116.1ns for clk_sys-to-clk_sys, followed
by video578.6ns andHDMI467.3ns. These are aggregate inserted delays across
many paths, not single-path requirements. The largest listed individual
path is hps_io.sd_rrb[2] to io_dout[11],1.950ns. Of the top100 detail rows,
66 are within sdram_beat32,16 in the FPU,10 end in hps_io,4 at ADB keyboard
FIFO RAM, and4 in CPU pipeline/core logic. This does not identify a giant
erroneous single hold constraint.

SDRAM write-queue/request registers are in clk_sys; a_ram/d_ram capture in
clk_ram. The clocks are related main-PLL outputs at33/99MHz. The loaded SDC
keeps these outputs in the same group, preserving their timing checks.
Do not false-path them to make congestion disappear. Dynamic video PLL
exceptions reflect existing dual-clock memory/2FF CDC boundaries. No SDC
change was justified by this review, and none was made.

Existing coverage limits: sys_top.sdc uses exclusive groups for several
concurrently operating independent clocks (semantically imprecise but not
identified as the source of this hold burden); there are no board-I/O
input/output delay constraints in the reviewed SDCs. Any eventual STA pass
must be described within the configured constraints, not as exhaustive
external-interface timing proof. Hardware validation remains necessary.

Seed21 mapping completed with the same39,354ALM estimate; full fitter is
active. A separate scratch-only ADD/SUB sharing screen is being evaluated
as a possible additional area reduction; no new arithmetic change is in
this build.

### Shared ADD/SUB arithmetic rejected

The scratch shared-adder prototype passed1,363,280 differential vectors in
both PIPELINE_SUBSET modes, including exhaustive byte pairs/X/Z states for
ADD/ADDX/SUB/SUBX/CMP, word/long edges, and50,000 random word/long cases.
A deliberate borrow-polarity mutation failed. However, the valid CPU map
`addsub_shared_s21b` grew from25,865 to25,890ALMs (+25), with8,966registers
unchanged. Reject this candidate; no production arithmetic change.

Evidence: scratch/alu_addsub_20260924/README.md, miter/positive.log,
miter/mutation.log, mapped_alu.v; CPU map scratch/cpu_area/p_addsub_shared_s21b.
Mapped ALU SHA256 acb40351d37f08d3d0fe0941c34a0ca8773c57b595b1d0f270b7b33e76883f28.
The initial `addsub_shared_s21` map failed from a scratch entity-name error
(ap040_alu_new instead of ap040_alu), not a logic or capacity result. It was
corrected only in the separate successful run; do not use that failed map
as area evidence. The active full seed21 build is unaffected.

## Seed21 also congested; controlled placement-effort trial

`interim_mac_onealu_s21` atc61087e is terminal:40,997/41,910ALMs,
4,156/4,191LABs, placement successful, routing failed16618/170143 with188005
hold-delay demand. Map stayed39,354ALMs. build3/source-after0/cross77/timing77;
no freshSTA/RBF. Archive scratch/interim_mac_onealu_s21_fit_20260924.
Seed21 therefore did not resolve the seed28 routing failure.

The next trial keeps seed21 and all CPU/feature/SDC settings, changing only
PLACEMENT_EFFORT_MULTIPLIER from reported1.0 to3.0. Installed Quartus17
Cyclone V DSE explicitly tests1.0/3.0/5.0/10.0 with STANDARD FIT:
`/home/alans/intelFPGA_lite/quartus/common/tcl/packages/dse/dse-cyclonev-lib.tcl:1187`.
The installed advisor recommends2-4 for congestion and explains that extra
placement work can reduce routing demand:
`/home/alans/intelFPGA_lite/quartus/common/advisors/oa_resource_table.oaw:3524`.
This is a documented placement-effort experiment, not relaxed timing or a
guarantee of route success. ROUTER_EFFORT_MULTIPLIER is deprecated/ignored
according to the installed warning database and is not being changed.

## Placement effort 3.0 failed routing; resume structural reduction

`interim_mac_onealu_s21p3` (source `24e6b4e`) completed in 19m51s.
The report confirms effort 3.0; placement succeeded with 40,997/41,910 ALMs
and 4,156/4,191 LABs, but routing failed (16618/188026/170143/11802).
Average interconnect usage was 55.7%, peak 82.8% (vertical peak 105.5%).
There is no fresh STA or RBF. The post-flow source check passed; crossing and
timing analysis correctly skipped with exit 77. Archive:
`scratch/interim_mac_onealu_s21p3_fit_20260924`.

Restore placement effort 1.0 for subsequent RTL trials. Additional placement
effort did not solve congestion. Next scratch investigation: share the FPU
divider/square-root arithmetic stages without changing their three-digit
iterations or cycle counts. This is an unproven candidate, not integrated RTL.
The latency-increasing one-digit alternative remains deferred.

## Share FPU DIV/SQRT stages without changing latency

The divider and square-root engine now share three 69-bit compare/subtract/
select stages. DIV retains its 65-bit recurrence truncation, initial integer
quotient step, and terminal count 23; SQRT retains its 69-bit recurrence and
terminal count 22. Both still calculate three result bits per iteration.
Final normalization/GRS logic, state, counters, and registers are unchanged.

Candidate FPU SHA-256:
`78f51d66b20c4a28d08f632559fa786d8c8e3a5280c35c7713460834384b0889`.
CPU-only map: 25,676 ALMs / 8,966 registers, saving 189 ALMs versus the exact
combined common-ALU baseline (25,865). No new map warning codes.

Actual-source recurrence miter passed 100,056 comparisons, including random
high bits and directed thresholds; a stage-2 truncation mutation failed with
18,580 mismatches. The full directed CPU suite passed with LEA/XSTORE enabled,
including FPU arithmetic/exceptions, saved frames, and BUSY resume tests.
This is not exhaustive floating-point proof or full-chip timing evidence.
Evidence: `scratch/alu_divsqrt_shared_20260924/RESULTS.md`, `miter.log`,
`negative.log`, and `cpu_suite_evidence/`; CPU map in
`scratch/cpu_area/p_p_divsqrt_shared_86d48df/`.

Promote this validated candidate for a full-feature fit at seed 21, placement
effort 1.0. Feature and timing constraints remain unchanged. A separate fused
borrow arithmetic screen is scratch-only and is not part of this candidate.

## Borrow-derived comparison follow-on, validated but deferred

A separate scratch variant derives each shared DIV/SQRT comparison from a
70-bit zero-extended difference, using the high borrow bit and the low
69-bit result. Exact FPU SHA-256:
`2d53db3ae4a04310add04eeb7919f0219197a98827ed92e410e6d4a4a90f5465`.
The CPU map measured 25,514 ALMs / 8,966 registers: 162 fewer than the
integrated shared-stage candidate, 351 fewer than the common-ALU baseline.
The actual-source recurrence miter passed 100,056 checks; the truncation
negative failed as expected. The fresh full directed CPU suite with LEA and
XSTORE enabled exited 0 with all tests passed, including FPU/frame/resume.
Evidence is in `scratch/alu_divsqrt_shared_borrow_20260924/RESULTS.md` and
`scratch/cpu_area/p_p_divsqrt_borrow_86d48df/`.

Do not integrate while `interim_mac_divsqrt` is running. That full flow is
building source 3791bf6 (FPU 78f51d66...), session 90296, wrapper 1765334,
fitter 1772156. Its fresh full-map estimate is 39,313 ALMs, only 41 fewer
than the preceding full-map 39,354; isolated CPU savings do not transfer
one-for-one to the complete design. Final placement/routing/timing pending.

## Interpreting fitter growth and a deferred settings experiment

Review of the seed21/effort3 report distinguishes ALMs actually used from
ALMs needed: A=39,778 used, B=1 recoverable, C=1,220 unavailable gives
A-B+C=40,997 needed. Relative to the 39,354 map estimate, actual used growth
is 424, not 1,643. Of the unavailable estimate, 1,181 are due to LAB input
limits and 39 to LAB-wide signal conflicts. Register counts fall from
29,141 mapped to 28,478 fitted. The 341 logged register duplicates occur
in register packing even though performance register duplication is off.

The reports do not attribute hold-repair demand to these physical-synthesis
settings. If the validated borrow reduction still fails routing, one
controlled setting trial is to turn PHYSICAL_SYNTHESIS_COMBO_LOGIC off while
leaving PHYSICAL_SYNTHESIS_COMBO_LOGIC_FOR_AREA on and all other settings
fixed. The former is the performance pass, and the latter is for fitting.
This is only a proposed experiment: the previous report credits the
performance pass with an estimated 1,590 ps slack improvement, so removing
it may hurt timing. Do not relax clock constraints or assume routing will
improve. No such settings change is part of the active divsqrt build.

## Shared-stage full fit failed; promote validated borrow reduction

`interim_mac_divsqrt`, source 3791bf6, is terminal: placement succeeded but
routing failed congestion (16618/188026/170143/11802). The fitter reports
41,077 ALMs needed, comprising 39,910 actually used, 2 recoverable and 1,169
unavailable; 4,165/4,191 LABs and 28,437 registers. Routing average/peak was
71.7%/95.0%. The fresh map estimate was 39,313. No STA or fresh RBF exists.
Source-after passed; build exit 3, crossing/timing exits 77. Evidence is
`scratch/interim_mac_divsqrt_fit_20260924`. The lower CPU map count did not
translate to better full placement/routing; retain that limitation explicitly.

Promote the independently tested borrow variant FPU SHA
`2d53db3ae4a04310add04eeb7919f0219197a98827ed92e410e6d4a4a90f5465`.
It replaces each shared comparison/subtraction pair with one zero-extended
70-bit subtraction; the borrow bit supplies the unsigned comparison. It
passed the recurrence miter, mutation control, and full directed CPU suite
with LEA/XSTORE enabled. CPU map is 25,514 ALMs (162 below the preceding
shared-stage variant), with 8,966 registers. See the preceding validation
entry and archived candidate `cpu_suite_evidence/`.

Next full fit: `interim_mac_divsqrt_borrow`, seed 21, placement effort 1.0.
Keep all features, timing constraints, and physical-synthesis settings fixed
so this tests only the validated arithmetic reduction.

## F_ADDX sharing screen: validated, small saving, deferred

A scratch-only FPU variant shares the 68-bit F_ADDX addition/subtraction
through conditional RHS inversion and carry-in. Candidate FPU SHA-256:
`6fd0a29d37aae9a4878f68872a8623855ba392f447af0141178bc9e43e6063ab`.
Its CPU map is 25,484 ALMs / 8,966 registers, saving only 30 ALMs versus
the integrated borrow baseline (25,514). Source-derived miter: 100,064
checks passed, inverted-carry negative rejected. The complete directed CPU
suite with LEA/XSTORE passed; fresh logs and hashes are archived under
`scratch/alu_fpu_addsub_shared_20260924/cpu_suite_evidence/`, with exact
commands and source identities in that candidate's `RESULTS.md`.

Do not integrate this merely because the map is smaller. The saving is
small and no full-chip routing benefit is established. Stop additional
small screens while awaiting the current `interim_mac_divsqrt_borrow` fit.
That flow builds source 7af6a29, FPU 2d53db3..., at seed 21/effort 1.0;
session 69047, wrapper 1793732, fitter 1798838. Fresh full map: 39,021 ALMs,
292 below the preceding 39,313. Tracked inputs stay frozen until the full
flow and source-after check finish.
