# Original Speedometer loops on CPU and RAM

These tests execute extracted, unchanged Speedometer 4.02 machine code at
its original CODE-relative addresses. They instantiate `wombat_cpu`, including
its actual cache and store buffer, with a 64 KB byte-addressable RAM responder.
They do not boot Mac OS or implement the Toolbox. Interrupts are masked.
MMU translation defaults off; optional real page-table modes are described
below. RAM acknowledgment latency is controlled.
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

## Real MMU mode

Add `--mmu 8k` (guest-like TC=0xc000) or `--mmu 4k` (TC=0x8000).
The harness supplies resident page tables at physical0x4000/0x4200/0x4400,
sets SRP/URP through guest MOVEC instructions, and serves actual descriptor
reads/writes through the wrapper's walker port. Walker and CPU traffic share
one physical RAM responder and the configured acknowledgment delay. At least
one walk read/write and root/pointer used-bit updates are required to pass.
Kernel bytes and result oracles remain unchanged. Setup and cold translations
are included in cycle counts; these are not isolated steady-state timings.

For Sieve, `--mmu-remap-buffer` maps one buffer page to a different physical
page. Output checks follow that mapping, and the original physical page is
filled with a poison value and checked for unwanted writes. Both4KB and8KB
modes pass. A negative control disabling TC fails the prime-flag oracle,
showing the test cannot pass by silently bypassing translation.

Measured8KB identity-map Sieve cycles, latency0/3/8:

| CPU | latency0 | latency3 | latency8 |
|---|---:|---:|---:|
| P64 | 306,551 | 312,515 | 380,103 |
| P75 CLR plus hint | 291,552 | 297,561 | 378,635 |

Each run performs15walker reads and7writes. P75's middle-latency benefit is
4.79%; translation adds roughly0.94% to its translation-disabled count.
This compact working set does not reproduce the guest's page/ATC/cache
pressure or device scheduling. Evidence: `scratch/sieve64_mmu8_20260920`,
`scratch/sieve75_mmu8_20260920`, and `scratch/sieve75_mmu{4,8}_remap_20260920`.
The remapped runs also yield297,561cycles atlatency3 and preserve both
translated buffer guards and poisoned physical pages.

Quick Sort also passes with8KB translation:179,011cycles atlatency3,
12walker reads/6writes; evidence `scratch/quick75_mmu8_20260920`.

## Original integer Matrix routine

`scripts/cpu/profile_matrix.py` uses unchanged CODE3 bytes0x5dda..0x5e2d,
including its LINK/MOVEM prologue and return. Each call computes one40-term
dot product; a small assembly wrapper makes1600 calls for a40×40 result.
The calling convention uses output pointer, B and A row-pointer tables, row
and column parameters. Original instruction addresses are retained.

The fixture supplies deterministic signed16-bit matrices (seed20260920,
full signed range). An independent Python B×A calculation checks all1600
word results modulo65536. Both input matrices, their row tables, surrounding
memory and output guards must remain unchanged. Removing ADD.W(A2),D2 at
0x5e1a in a disposable program causes the result oracle to fail at index0.
This deliberately tests arithmetic validation, not merely guest completion.

Run with the same options as Sieve, for example `--mmu 8k --early-drain
--compare --latencies 0 3 8 --disassemble --profile`. The fixture excludes
Mac allocation, original input initialization, timing and UI. Its signed
inputs are controlled test data, not a capture of Speedometer's original
matrix contents. CPU/MMU/cache/store-buffer paths remain real; RAM latency
is controlled and these cycles do not predict hardware Mix directly.

| CPU, MMU8KB | latency0 | latency3 | latency8 |
|---|---:|---:|---:|
| P75 | 4,117,756 | 4,149,716 | 4,223,782 |
| P76 | 4,117,755 | 4,149,715 | 4,223,781 |

All1600 results and guards pass, with21walker reads/9writes. The one-cycle
change is negligible; immediate stores do not improve this inner loop.
Evidence: scratch/matrix{75,76}_mmu8_20260920, including source/program/oracle
identities and the P76 negative_no_accumulate log. Compilation took about8s;
each simulated full matrix took about6s on this host.

P76 latency3 occupancy: S_MRD34.51%, S_PIPE_REGS12.53%, S_PIPE_START11.10%,
S_EXPERIMENT_PIPE10.80%, S_MD_WAIT6.17%. These are state occupancies, not
independent pure-stall estimates. The original indexed MULS is a pipeline
exit64000 times. This makes reducing load/operand setup and repeated pipeline
entry around indexed arithmetic worth screening; faster multiply alone has
limited headroom here. Legacy IR occupancy is not verified opcode attribution.

Shared-harness regression after this extension: QuickMMU8K179011 and
SieveMMU8K289371 at latency3, both unchanged, all oracles pass.

## Pipeline read timing by issued PC

`--profile` now reports PIPE_READ using actual launch, response and accepted
retirement handshakes. These counters avoid the stale legacy IR. Each completed
read must retire once, and elapsed response cycles must equal one response cycle
plus the mutually exclusive prefetch/setup/ack-wait/other categories. This is a
fault-free, 64KB fixture profiler, not a general guest exception profiler.

Validated P82 versus P83 with P78 core, MMU8KB, latency3 in
`scratch/matrix83_read_breakdown_20260920`: all1600 results and input/guard
checks pass; cycles remain3702562 and3638968 respectively. Each listed PC
executes64000 reads. Both variants have identical first four read timings:

| PC | Operation | Response cycles total | Prefetch wait | Setup | Ack wait | Retirement gap |
|---|---|---:|---:|---:|---:|---:|
|5df6|indexed MOVEA.L|193731|7|1601|128123|0|
|5e0c|indexed MOVE.W|193474|0|0|129474|0|
|5e10|indexed MOVEA.L|195578|0|0|131578|0|
|5e16|indexed MULS.W|321672|64198|64000|129474|64000|
|5e1a|ADD.W (A2),D2, P83 only|196908|0|0|132908|0|

All other-state counts are zero. Multiply's extra prefetch and setup occupancy
is a concrete optimization lead; ordinary reads already retire on the response
edge. State categories describe observed occupancy, not proof that every such
cycle can be removed. These totals are simulation evidence, not hardware Mix.

P87 prefetch screen (scratch only): defer speculative self-fill while pipeline
ownership is active, pipeline is non-idle and at least N words are buffered.
N=2 removes MULS prefetch/setup waits but regresses total Matrix cycles to
3702936 (+1.76% versus P83); instruction queue starvation offsets the saving.
N=4 and N=6 exactly reproduce P83's3638968 and all read timings. All three
pass the independent matrix/input/guard oracle. None is promoted or fully
qualified. Evidence: scratch/matrix87_prefetch{,4,6}_20260920. This rejects
simple queue-threshold throttling as a useful optimization for this workload.

P88 multiply response-edge retirement screen (scratch only): permit indexed
MULS/MULU to use the existing direct-read retirement handshake, using full
product flags rather than the ALU MOVE flags. Matrix remains exactly3638968
cycles despite removing all64000 multiply response-to-retirement gap cycles.
All1600 matrix results/inputs/guards pass. Independent Python product/CCR
oracle passes128 signed/unsigned cases across3 bus/CE phases, with384 actual
pipeline launches and retirements. Evidence: scratch/matrix88_fastmul_20260920
and scratch/p88_fast_multiply_20260920/oracle. No full fault/IRQ qualification
or fit: reject because it adds a combinational multiply to the retirement path
without improving total cycles. Production retains registered multiply WB.

Inspection also confirms load_req already includes combinational load_issue;
the pipeline load offer is not delayed by a separate request register before
core launch. hint_p2 already carries its effective address on that launch edge.
An earlier hint would require operand/address availability earlier than EX,
not simply exposing the existing load_issue signal. No such change made yet.

## P89: retain four ATC translations per space

New PIPE_READ_BLOCKERS counters inspect hint match, cache acceptance, RAM read
readiness and tag match during issued pipeline reads awaiting response. These
are overlapping prerequisite failures, not additive stall categories. P83
Matrix8KB sees roughly128000 hint-mismatch clocks per64000 reads at each hot
PC; cache-array readiness is rarely the limiting condition. Evidence:
`scratch/matrix83_cache_blockers_20260920` (all existing oracle checks pass).

P89 scratch MMU retains four direct-mapped ATC copies per instruction/data
space, indexed by the low two ATC set bits. Full row/tag comparisons remain;
all copies invalidate on the original reset/fill/sweep/PFLUSH/TC conditions.
Permissions, cache attributes and modified status still come from the copied
ATC entry. Unapplied patch: scripts/cpu/mmu_translation_copies.patch.
Shared fixture accepts --mmu-module and hashes the selected source.

| Workload, latency3 | P83 original MMU | P89 | Result |
|---|---:|---:|---|
| Matrix8KB |3638968|2870854|21.11% fewer cycles|
| Matrix4KB |3771795|3126068|17.12% fewer cycles|
| Quick8KB |178573|178573|unchanged|

All Matrix1600 results, inputs and guards pass, with identical walker counts
for each page-size comparison. Ordinary Matrix8KB pipeline reads now respond
in roughly one cycle, versus three; multiply still has its prefetch/setup
wait. Remapped Sieve8KB passes at286818cycles with all8191 independent flag
checks and poisoned/unmapped-page guards; a matching current baseline remains
to be measured before claiming that remapped test's speedup.
Evidence scratch/{matrix89_mmu8,matrix83_mmu4,matrix89_mmu4,quick89_mmu8,
sieve89_mmu8}_20260920. Existing real-core MMU/protection/ATC/function-code/
exception programs launched via scripts/cpu/mmu_candidate_gate.py; qualification
is pending. No production RTL change, fit or hardware score for P89 yet.

P89 existing real-core MMU gate completed (session62648exit0): t_mmu,
t_bitfield_mmu,t_atcprobe,t_moves_fc,t_exceptions allPASS. This covers existing
translation/protection/nonresident/PTEST/function-code exception cases, but
is not yet evidence of complete multi-copy invalidation coverage. Targeted
coverage plus full integration/corpus and FPGA fit remain before promotion.

P89 focused invalidation gate: scripts/cpu/mmu_copy_invalidation.s warms four
data translations, changes their page descriptors, verifies the old mappings
remain until PFLUSHA, checks all four new mappings after flushing, then disables
translation and checks original physical contents. All3 bus/CE phases pass.
The accompanying mmu_copy_monitor.sv requires simultaneous validity of allfour
data copies and a flush with allfour present, and checks all8 copies clear on
reset/fill/sweep/PFLUSH/TC-change edges. Coverage:4765 full-copy cycles,
3 populated flushes,84 clear checks. Correct source evidence:
scratch/p89_mmu_copies_20260920/invalidation.

Negative control negative_flush_data.v preserves reset and instruction-copy
invalidation but wrongly retains data copies2/3 during flush. Monitor fails on
stale copy2 after987 full-copy cycles and1 populated flush. Earlier broad
mutations failed before allfour data copies were populated; these are not the
final coverage evidence. The broad negative also passed guest-only remapping
because later ATC fills mask the stale-copy window, so the explicit monitor is
necessary and its scope must not be described as a guest-only negative proof.

First100corpus session60860exit0:1900 field groups match, zero differences,
/tmp/cpu-corpus100-gate.J5cwrR. Isolated full pipeline integration session98466
still running under scratch/p89_mmu_copies_20260920/tree, logfull.log; no
production source edits and no promotion yet.

Matching remapped Sieve8KB baseline completed (session73131exit0):289371
cycles versusP89 286818,0.88% fewer. Both use15walker reads/7writes and pass
allprime/guard/remapping checks. Evidence scratch/sieve83_remap8_20260920.

P89 full pipeline integration completed, session98466exit0, ending PASS
real-core pipeline ownership integration. Precise source/store/PEA faults,
interrupt cancellation and replay all pass. With the independent workloads,
existing MMU programs, explicit multi-copy invalidation and first100corpus,
P89 is simulation-qualified for a fit. Prepared (unlaunched) wrapper
scratch/p89devmmucopies_fit_20260920/run.sh guards MMU SHA
37075a31467f4d04f07ad9c83c1eca1efad8c80d36a840743e22bac875bd7fa5,
P78core/P83pipeline, baseline divider/ALU. Wait for P83's complete archive/STA.

P90 area fallback screen retains four data copies but only one instruction
copy (five total versusP89's eight). Matrix8KB2872453 versusP89 2870854,
1599 extra cycles; all1600results/guards pass and walker counts unchanged.
Most P89 benefit is therefore from data translations. Scratch only, not fully
qualified and not selected for the next fit. Evidence:
scratch/p90_mmu_data_copies_20260920 and scratch/matrix90_mmu8_20260920.

## Whetstone extraction dependency inventory

Original CODE3 WStone entry is0x0008 (LINK A6,#-288), ending RTS at0x0834;
Pascal debug name follows at0x0836. Bytes[0x8:0x836] SHA256
0905989f3dc0a32d9c6e3b53fe006f3119a69c9b50236bf0b9f9258f7f7bd6c2.
Static disassembly has36 A9EB SANE trap sites and15 JSR sites: local helpers
0x840 and0x932, plus raw absolute targets0x50,0x58,0x60,0x68,0x70,0x78.
These are resource-file addresses before loader relocation; they must not be
called as physical low-memory addresses in a standalone fixture. The function
also uses A5-relative global data (for example -0x2070 and -0x2066).
A faithful Whetstone fixture therefore needs the actual relocated math/runtime
and SANE trap implementation, stack/global setup and a numerical oracle.
Counting trap/call sites does not establish dynamic frequency or cycle share.
Do not replace those calls with stubs and report it as Whetstone performance.
Source evidence: scratch/speedo_kernel_profile_20260919/CODE3.{bin,dis}.

## Re-screening after the MMU improvement

P91 reuses isolated P84 immediate byte/word CMPI support with P89's MMU:
Matrix8KB latency3 regresses2870854→2875655 (+4801), exactly the old absolute
penalty. Pipeline exit moves from CMPI at0x5e20 to BLE at0x5e24, but instruction
fetches increase275261→339260 and the net result is slower. All matrix oracles
pass. Evidence scratch/matrix91_cmpi_mmu89_20260920 (both baseline/candidate).

P92 reuses P87's two-word prefetch threshold with P89MMU: Matrix2934837,
+63983 versus2870854. Multiply's prefetch/setup waits vanish, but instruction
starvation rises (pipe_ready_empty192000; baseline0). All oracles pass.
Evidence scratch/matrix92_prefetch_mmu89_20260920. Both re-screens rejected;
production remains P89 and no additional qualification/fit is warranted.

P89 Matrix8KB latency robustness check (same P78core/P83pipeline):

| RAM latency | Original MMU | P89 MMU | Cycles saved |
|---|---:|---:|---:|
|0|3607008|2838894|768114|
|3|3638968|2870854|768114|
|8|3713034|2944920|768114|

All1600results/inputs/guards pass in allcases, with21walker reads/9writes.
The benefit is insensitive to these RAM response delays (20.69–21.30% fewer
cycles); this still does not establish a hardware Mix improvement. Evidence:
scratch/matrix{83,89}_latency_sweep_20260920, originalMMU recovered from64af3ae
and recorded ineach identity.json. Sessions37446/44420 bothcompletedexit0.

P90 fallback qualification begun after P89 fit missed CPU timing by1.538ns.
Five-entry sourceSHA2c445c90b1bbd7ea4b8452b6ff3e91bd4fa56e363d0beb9c430ae33f3c033abd;
unapplied scripts/cpu/mmu_data_copies.patch relativeP89. Retains the same four
data translations but only one instruction translation, at index4.
Quick8KB178573 and remappedSieve8KB286818 exactly match P89, all oracles pass.
Existing five MMU/fault/ATC/function-code programs pass (session72958exit0).
Focused remapping/invalidation test passes3phases with4765full-copy cycles,
3populatedflushes/84clearchecks. The monitor now checks the actual array size.
First100corpus1900groups/zero differences, session75079exit0,
/tmp/cpu-corpus100-gate.Sy8o6W. Fullintegration and Matrix4KB stillrunning;
no promotion/fit yet. This is an area/timing fallback, not an established gain.

P90 final simulation qualification: Matrix4KB3127667cycles,1599 more thanP89,
all1600results/guardsPASS (session40699exit0). Fullintegration35760exit0 with
precise load/store/PEA fault, interrupt and replay gates allPASS. Together with
MMU/invalidation/corpus/workload gates, this qualifies P90 for a fit. Promoted
unchanged five-copy source; guarded wrapper scratch/p90devdatacopies_fit_20260920/run.sh.
No claim of area/timing improvement before Quartus completes.

## Full-Mix FPU-state occupancy cross-check

Re-read P67's completed workload.tsv against its immutable core state numbers,
not current opcode histograms. S_FPU*, S_FSAVE* and S_FREST* total5743125clocks
(0.5947% of965772857). Including floating-point conditional control states
S_FBCC/S_FSCC*/S_FDBCC adds9504, totaling5752629 (0.5957%). S_FPU_GO, which
issues/waits for the arithmetic operation, accounts for1707750clocks (0.1768%).
The hardware FPU was enabled and exercised; this is not evidence it was absent.

These are exclusive sequencer-state occupancies over the whole Mix/UI bracket,
not the fraction of Whetstone time spent on floating-point work. SANE dispatch,
operand memory traffic and ordinary instructions can run in shared states and
are excluded here. Nevertheless, the very small dedicated arithmetic wait
makes optimizing the FPU arithmetic unit alone a weak lead compared with
shared instruction, translation and memory paths. A Whetstone-specific bracket
is still needed before attributing its complete cost. No P89 score yet.


P93 tests parallel constant-index retained MMU tag comparisons before selecting
one of P90's five copies. It changes only request-path `u_hit` logic; retained
entry contents, indexing, permissions and invalidation remain unchanged. Patch
`scripts/cpu/mmu_parallel_tags.patch` is relative to production P90. Candidate
MMU SHA256 `be5db2dcb1baa201d40ff3ad674bbfcb0206c377c7cfcf4caba68b67443d470c`.
This targets the tag-mux/equality chain in the measured P89 critical path;
there is no FPGA timing or area improvement claim before a fit.

Matrix 8KB MMU, latency 3: 2,872,453 cycles, exactly P90, all 1,600 results,
inputs and guards pass (`scratch/matrix93_mmu8_20260920`). Five existing MMU
programs pass. Directed invalidation passes all three bus/CE phases with
4,765 full-copy cycles, three populated flushes and 84 clear checks.
Full integration and first-100 corpus qualification are in progress in an
isolated snapshot under `scratch/p93_parallel_mmu_tags_20260920/tree`.
An initial corpus launch used the older default Verilator and failed at
`--binary` before testing; the rerun explicitly uses the established Verilator 5.
Production remains P90 and is frozen for its ongoing Quartus flow.

P93 first-100 corpus completed: 1,900 field groups match, zero differences;
artifacts `/tmp/cpu-corpus100-gate.mtqqAx`, session7731 exit0. This is the
first-100 fixture, not the complete instruction corpus. Integration remains live.

P93 remaining qualification completed: full integration session63505 exit0,
including precise load/store/PEA faults and interrupt/replay monitors. Matrix
4KB latency3 =3,127,667 cycles; remapped Sieve8KB =286,818; Quick8KB =178,573.
All equal P90, with independent result/input/guard checks passing (sessions
53749/79750/40017 exit0). This completes the planned simulation qualification.
Prepared, not launched: `scratch/p93devparalleltags_fit_20260920/run.sh`, checking
exact candidate MMU/core/pipeline/ALU/divider hashes. P90 production remains
unchanged until its entire fit/archive/STA completes. P93 is a candidate for
an FPGA timing comparison, not an established timing fix or speed improvement.


P90 fit completed (commit1bb5f6f): 39,465 ALMs (94%), 25,490 registers,
482 RAM blocks, 42 DSPs. CPU setup slack -0.140 ns / TNS -0.312 ns,
HDMI -0.123 ns, SDRAM +0.380 ns, minimum hold +0.164 ns. The CPU miss is
smaller than P89's -1.538 ns, but this is still a timing-failed development
build, not release acceptance. Build exit1, source verification0, cross STA0.
Archived `MacQuadra800_p90devdatacopies_1bb5f6f.rbf`, 4,550,496 bytes,
SHA256 `3d25065f006bbbf06442748bfaa2890f1242d34680551d19430b57ec18238816`
(root independently verified). Detailed CPU STA and RAM/cross review pending;
production remains frozen until that review completes. No hardware deployment.

P90 detailed CPU STA completed exit0: remaining worst path tc[14] through
MMU retained-tag mux/comparison, physical address and store-buffer acknowledgement
to core rr_a[2], -0.140ns. Crossings sys-to-RAM +2.386ns, RAM-to-sys +0.489ns.
P93 therefore still targets a measured critical chain. With all P90 flows
terminal, promoted the simulation-qualified P93 MMU unchanged for its next fit.

P89 full-guest run reached Speedometer 4.02 and the full Mix setup. Root
reviewed screenshot f5080: all ten benchmarks selected, one iteration each.
CPU profiling started at simulator cycle4,311,678,977 immediately before
Return on Run Set. Screenshot f5220 confirms the Whetstone phase running.
A local watcher polls screenshots, stops profiling on the completion alert,
and leaves the simulator alive for visual review and normal guest shutdown.
No completed score or hardware performance claim exists yet.


Dhrystone dependency inventory (original CODE3, no benchmark changes): DStone
starts at0x0bca (`LINK A6,#-86`), ends with RTS0x0dc8, debug name at0x0dcb.
Bytes[0x0bca:0x0dca] SHA256
`aa1e3cbd001a0619a30a7013a49d3bfe1acb6c00091ef41d39e783d73f12c026`.
The actual workload loops0x0cb0..0x0dae, comparing an unsigned-expanded word
counter with50,000. Helpers Proc1..8 start0x0dd4,0x0e66,0x0e96,0x0ed4,
0x0f00,0x0f1a,0x0f8c,0x0fae; Func1..3 start0x1048,0x106a,0x10e6.
Disassembly from each proper routine boundary is in
`scratch/dhrystone_inventory_20260920/routines.dis`; Proc6's embedded jump
table at0x0f52 requires separate code/data handling, so its linear decode
stops at the indexed JMP and is not a complete Proc6 listing.

The workload includes word multiply/divide, indexed arrays, record copying,
procedure calls, stack locals and A5 globals. Runtime calls to raw resource
target0x48 occur twice during initialization and once per loop (string-copy
calling context); Func2 calls raw0x40 with two string pointers and compares
the returned word with zero (string-comparison context). Their precise runtime
implementations/relocations still need verification. The surrounding DStone
wrapper also allocates/frees two40-byte records and performs timer calibration.
An isolated loop can supply deterministic storage and omit the timing wrapper,
but must preserve actual string routines, helper code, A5 data and numerical
oracles to represent the complete Dhrystone workload. No such fixture or
Dhrystone-specific speed claim has been produced by this inventory.


P93 parallel-tag fit completed from5eec8fb:39,432ALMs94%,25,510registers,
482RAMblocks,42DSP. CPU -1.612ns/TNS-143.132, SDRAM +0.095ns, HDMI +0.133ns.
Buildexit1(timing),sourcecheck0,crossSTA0. Archived artifact
`MacQuadra800_p93devparalleltags_5eec8fb.rbf`, SHA256
`4f66d666b182b51775d242530edbcab659f30a376c1e92c2341dbc75e210e63e`
independently verified. This is worse CPU timing than P90's -0.140ns with no
cycle improvement. Reject as a timing candidate; detailed CPU STA pending,
then restore qualified P90 MMU before choosing the next timing experiment.
No P93 hardware test or timing improvement claim.

P93 final archive review: detailed STA exit0, hold minimum+0.247ns,
crossings sys-to-RAM+0.476ns and RAM-to-sys+0.628ns. Worst path now starts
at cache ctag RAM write-enable register and ends at core epf_data[1][9].
RAM inference remains healthy:ctag M10K44,032bits, ATC M10K5,888bits,
extra register-bank E MLAB512bits. All flows terminal before restoring
production to the exact previously qualified P90 MMU SHA2c445c90.
No new correctness test is required for this byte-identical restoration;
P90's existing qualification evidence remains the applicable evidence.


P89 full-guest Mix completed: root reviewed `screenshot_f7116.png`, explicit
"The tests are done" dialog, final simulated Mix **1.236**. All ten tests ran
once. Ratings: Whet3.124,Dhry.785,Towers.829,Quick1.157,Bubble1.189,
Queens.767,Puzzle1.068,Permute.690,Matrix1.178,Sieve1.576. This is simulation,
not five-run MiSTer acceptance. Prior P67 final Mix1.187 was independently
rechecked against its original f6222 screenshot: overall gain about4.1%.

Correction to interim conversation comparisons: P67's Towers.797,Quick.638,
Bubble.621,Queens.529,Puzzle1.083 are **elapsed seconds**, not normalized
ratings (their rating column is hidden by its completion dialog). Do not claim
Quick/Bubble nearly doubled or Queens rose from.529 to.767. Corresponding P89
elapsed times are.771,.616,.639,.526,1.023 seconds. Quick elapsed improved
about3.4%; Bubble elapsed regressed about2.9%. Matrix ratings.981→1.178 and
Sieve1.441→1.576 are visible valid rating comparisons. Multiple RTL changes
separate P67/P89, so none isolates a single optimization.

P89 profile stop completed; watcher exited normally, guest remains running.
`workload.tsv`:899,212,537 CPU clocks,260,165,724 observed opcode loads,
3.456 clocks/load (not retirement CPI). Matching snapshot report:
S_MRD23.03%,S_PIPE_REGS12.71%,S_MWR11.85%,S_DECODE11.01%,S_FETCH8.45%,
S_EXPERIMENT_PIPE7.40%,S_PIPE_START7.04%. Bracket includes UI launch and
queued post-completion waits; do not treat its total as pure benchmark time.
Legacy opcode histogram is unsuitable for exact pipeline attribution.
Timer observer stream still needs final flush/review; no all-ten timer-validity
claim. Normal guest shutdown and final timer review remain to do.

P89 post-run closure: simulator exited through its `quit` control with
ExecMainStatus0. This was **not guest shutdown**: Speedometer's save dialog
remained open; `n` did not activate No. The immutable headless runtime has
keyboard controls but no mouse-control command; the GUI mouse path is not
active. Only the disposable run.hda was mounted. Normal guest shutdown is
not validated by this run and remains a hardware acceptance requirement.

The flushed observer file contains **zero identities/records/start/stop**
with242,934 contexts, uncapped. Therefore it supplies no independent timer
validation for this P89 run, despite the visually verified full completion.
Do not report all timers valid or infer the intended Queens/Sieve coverage
actually occurred. The profile and screenshot remain usable within their
reported scope; hardware five-run and timer-validation requirements remain open.


P95 scratch screen: bypass S_PIPE_START→S_PIPE_REGS only for SK_REG/DK_REG
EK_ALU when rr_a/p_sreg and rr_b/p_dreg already match, using forwarded
rf_capture ports and existing retire_operand_alu. Quick8KB latency3=178573,
Matrix8KB latency3=2872453, exactly P90; all independent result/input/guard
oracles pass. Candidate `scratch/p95_register_start_20260920/ap040_core.v`;
evidence quick95_mmu8/matrix95_mmu8. No measured benefit, no promotion or
broader qualification. Production remains exact P90 RTL for live P94seed23fit.

Profiling interpretation correction: S_PIPE_REGS is the legacy operand
capture/**retirement** state and directly performs ALU/shift retirement;
it is not solely pipeline setup or register-seeding overhead. Its12.71%
share cannot be treated as removable startup cost. S_PIPE_START's7.04%
includes source/destination memory address setup. Inspect actual transitions
and measure each proposed bypass before attributing savings to these states.


P96 extends indexed/d16 source early-read eligibility from register destinations
to ordinary memory-to-memory MOVE (EK_ALU/MOVE, no RMW); destination register
selection is changed only for register destinations. Existing source fault and
destination sequencing remain. Unapplied patch `scripts/cpu/memmove_early_read.patch`
is relative to P78 core; scratch `p96_memmove_early_read_20260920`.
Quick8KB latency3:178573→176265 (-2308 cycles,1.29%); Matrix8KB2872453 and
Bubble MMUoff3394944 unchanged. Independent results/guards pass. Directed
144 memory-MOVE fixtures across3bus/CE phases pass:432 acknowledgements,
315direct-EA transitions. Fault qualification started; full qualification,
FPGA timing and hardware improvement remain unproven. Initial scratch-generation
assertion failed on indentation before source creation; screening launched only
successfully after correcting generation. No production change.

P94 placement-only seed23 completed:39543ALMs94%,CPU-2.117/TNS-158.712,
HDMI+.289,SDRAM+.178; build1/source0/cross0. Worse than identical P90 RTL
seed22's-.140 CPU. Detailed STA/archive review pending; restore seed22 after
it completes. No hardware deployment or timing improvement claim.
