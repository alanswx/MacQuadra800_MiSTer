# Operand extension-request overlap experiment

Updated 2026-09-13: **source-only variant adopted after hardware validation**.
The active CPU SHA256 is
`0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`,
with Speedometer CPU Mix 0.458 / 0.460 / 0.460, +1.99852% over indexed-stage.
See `CPU_SOURCE_OVERLAP_CHECKPOINT_20260913.md` for fit, hardware and cleanup.
The remaining text records the isolated experiment and selection process;
both-caller and destination-only variants remain unadopted.

## Change

The new `ea_operand_start` helper selects the existing base register and sets
up extension length/return/bookkeeping on the same edge. Existing S_IMMF still
consumes the words, allowing a qualified edge for register outputs to settle.
Existing displacement/index/absolute arithmetic, register-write fallback, queue
ownership, fault handling and data-access guards remain unchanged. This is
intra-instruction stage overlap, not a general multi-instruction pipeline.

The initial candidate replaces only the two ordinary operand callers:
S_PIPE_START source and S_PIPE_DST destination. All specialized EA callers
retain their original boundary. Exact mode eligibility is d16, indexed and
mode 111 register fields 0–3; invalid/other modes retain the legacy path.
Immediate `x_ext` and the pre-extension PC are explicitly preserved.

## Candidates and selection

Complete source trees are under `/tmp/cpu-ea-request-overlap.ZTs0sO`:

| Variant | Directory | Core SHA256 |
| --- | --- | --- |
| Accepted baseline | accepted-rtl | `16fc1cc1f7f7e4295cbacf6c5449f2aa485d72290f27d75a3af687a2c7c8c79e` |
| Both callers | rtl | `75eb6faa4ab1cf8f6ede2c02cbf4122e02304fa7fb29776c322a70f634054c41` |
| Source only, selected for further gates | source-rtl | `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614` |
| Destination only | destination-rtl | `76051266af80841382c95f756b402c7416babe0dfa145e718db50306ceff3d41` |

The two-caller prototype improves 15/16 RAM-path placements but regresses
offset 16 by 12,892 cycles (1.57%). Its S_EA_DISP saves 31,381 cycles, but
FETCH adds 28,557, DECODE adds 14,999, IMMF adds 720 and MRD saves three.
Cache/memory transaction counts are unchanged; killed fetch acknowledgements
rise from 1,901 to 16,180. The extra decode count matches the 14,999 inner-loop
iterations. An initial DBcc-specific explanation was disproved: the exact
kernel uses Bcc, not DBcc, and the bounded observer records zero DBcc entries.
The ordinary next-opcode/branch fetch scheduling is under investigation;
do not attribute this to the DBcc refill shortcut.

The replacement observer now proves the immediate cause: retiring MOVE.W
D5,D0 at PC $2042 loses resident-next-opcode readiness (`epf_ready_pc`) exactly
14,999 times in the two-caller candidate. The descriptor-valid, auxiliary-write,
interrupt/trace and pending/request/ACK conditions match baseline. Without the
resident opcode, fetch_next cannot trigger the shared direct dispatch; this
accounts for all 14,999 extra DECODE cycles. Both observed runs retain original
cycle counts and pass the oracle. Evidence:
`/tmp/cpu-ea-request-overlap.ZTs0sO/dbcc-probe/{shared-baseline,shared-both}/offset-16.log`.

The optional observer and exact reproduction commands are preserved in
`scripts/fixtures/operand_overlap/RETIREMENT_READINESS.md` and its adjacent
patch. That document also separates a future returning-opcode bypass hypothesis
from proven eligibility: generic ACK and a descriptor from stale queue storage
are insufficient. Measure the actual forwarded word before implementing it.

Ablation isolates the problem to destination overlap: at offset 16 destination
alone takes 844,018 cycles, while source alone improves to 814,729. At offset 6
destination alone takes 814,926 and source alone 827,427. Do not fix this by
relaxing memory request/ACK guards or adding a placement-specific exception.

**Source-only improves 14/16 placements, ties two, and regresses none.** It is
the selected bounded candidate. Both-caller and destination-only variants stay
experimental until their fetch-scheduling regression is addressed.

## Real CPU/store-buffer/SDRAM first-pass measurements

These use the unchanged 80-byte Sieve kernel and independent complete-array
oracle. They are not full MacOS/Speedometer performance measurements. See
[fixture definition](EXACT_SIEVE_INTEGRATION.md).

| Base mod 32 | Accepted | Both callers | Source only |
| ---: | ---: | ---: | ---: |
| 0 | 874866 | 844928 | 866676 |
| 2 | 833738 | 810532 | 833738 |
| 4 | 835497 | 801624 | 824809 |
| 6 | 838106 | 804253 | 827427 |
| 8 | 839903 | 807904 | 822924 |
| 10 | 832421 | 816817 | 815446 |
| 12 | 852596 | 804845 | 836220 |
| 14 | 845583 | 793181 | 829212 |
| 16 | 822926 | 835818 | 814729 |
| 18 | 863211 | 848207 | 863211 |
| 20 | 901730 | 859670 | 891041 |
| 22 | 867590 | 833726 | 856901 |
| 24 | 906127 | 865956 | 889154 |
| 26 | 886463 | 846304 | 869491 |
| 28 | 904536 | 864983 | 888157 |
| 30 | 883254 | 844203 | 866872 |

All runs exit zero and pass D6=1, D7=1899, array, sentinel, store-drain and
SDRAM protocol checks. Every placement preserves 512 D-cache misses, 517
external reads, 23,190 writes and balanced 23,190 store pushes/pops. For the
two-caller candidate, source early-issue is restored on all but one read at
offsets 0/16; no address/size eligibility check fails.

Evidence: `/tmp/baseline-profiles.oMrKac`, `/tmp/candidate-profiles.wcZdpb`,
`/tmp/ablation-source-20260912`, `/tmp/ablation-destination-20260912`,
`/tmp/ablation-source-all16-20260912`. AP 16-bit-wrapper all-alignment candidate
evidence is `/tmp/ap-alignment-candidate-20260912` and also passes its oracle.

## Correctness gates

New reusable fixture: `scripts/fixtures/operand_overlap/run.sh`.
Baseline, both-caller and source-only runs pass with actual exit zero:

- 27 architectural checks across all six extension forms, immediate ALU/bit
  operations, source postincrement dependencies, absolute-long alignments,
  PC-relative bases, full indexed/indirect forms and stack banks.
- Five page-boundary extension-demand bus faults: d16, second absolute-long
  word, immediate-ALU destination extension, indexed and PC-relative source.
  Checks original PC, exact fault address, format-7 frame, FC6, clear ATC,
  no premature destination register/memory writes, and successful RTE restart.
- All three bus timing phases, read-only entry assertions, clock-enable
  stability and forced architecturally neutral RF/ISP pending-write fallback.

The both-caller candidate additionally passes all eleven CPU suites, unchanged
focused loop (109010 / 109788 / 109788), and the immutable corpus at 34,679,579
cycles versus current baseline 34,742,942 (63,363 fewer). All 1,900 field groups
match, zero real differences. Corpus evidence: `/tmp/cpu-corpus100-gate.bZSqHQ`.
Original full-100 Sieve passes both complete calls at 89,982,263 cold and
89,982,114 repeat versus 92,976,362 / 92,976,214 accepted.

Source-only routine/full-machine/full-100 gates are being collected separately;
do not treat the broader candidate's result as proof for a different source hash.

Source-only all-eleven suite and immutable corpus pass with actual exit zero.
Corpus: 34,740,491 cycles (2,451 fewer than current baseline), 1,900 matching
field groups, zero real differences. Evidence: `/tmp/cpu-corpus100-gate.Z07FRH`.

Final source-only full-machine build passes with actual exit zero. Vemu SHA256:
`6861eafb49ced7b32da22d8b947a596d0d9a40c35d8ebe524e2be516945737b2`.
Original full-100 Sieve phase 0 also exits zero with both complete array/guard
checks passing: 92,157,263 cold, 92,157,114 repeat. This saves 819,100 repeat
cycles versus accepted (0.881%); it is not a hardware Speedometer gain.
Parent verified the final binary/source hashes, full-Sieve output, patch
application check and whitespace checks. The initial build-copy omission of
simulator helper headers was repaired without changing candidate RTL.
Baseline/both/source alignment logs and final source-only build/Sieve logs
are preserved under `scratch/cpu_operand_overlap_20260912/`.

## Recovery and next gates

Exact patches (normal `git apply --check` plus isolated application reproduced
each candidate source hash):

- `docs/checkpoints/cpu-operand-overlap-experimental-20260912.patch`
- `docs/checkpoints/cpu-operand-source-overlap-experimental-20260912.patch`

Both apply against the current accepted indexed-stage CPU, not the earlier
compact checkpoint. Fixture README gives baseline/candidate/source/destination
assertion modes and requires a fresh output directory.

Source-only full-machine tree: `/tmp/MacQuadra800_operand_source_seed24.zXuurP`.
It uses accepted CD-off seed-24 QSF SHA256
`81cb18081df01d55271185855e01a01a94f20aff8e9919f0b235b316bf45d1cb`.
No Quartus fit has been run for this source. Require clean fit/timing and three
guarded Speedometer repeats against 0.450333 before any adoption or speed claim.
Destination overlap remains a separate scheduling investigation.
