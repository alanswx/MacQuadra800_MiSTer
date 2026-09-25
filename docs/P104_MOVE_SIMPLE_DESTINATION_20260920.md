# P104 early simple MOVE destination setup

The completed opcode profile (scratch/whetstone_operand_opcodes_20260920)
accounts for all 5,389,204 S_PIPE_SDONE read cycles across 57 opcodes.
The largest are 2f10 MOVE.L (A0),-(A7), 1,148,221 cycles, and 206e
MOVEA.L d16(A6),A0, 640,118 cycles. 2f20 MOVE.L -(A0),-(A7) costs
588,037 read cycles. Full loop cycles and captured stack/globals/code match
P102 exactly. These are read-state cycles, not full instruction costs.

P104 broadens the existing successful memory-MOVE read completion shortcut
from indexed/displacement destinations to (An), (An)+ and -(An). It captures
src_val and calls the existing ea_start on acknowledgement, skipping
S_PIPE_SDONE and S_PIPE_DST. S_EA_DISP still settles the destination base,
performs postincrement/predecrement, and records rollback through u_rec.
Faulting and split reads retain their existing paths. No P103 change included.

Unapplied patch: scripts/cpu/move_simple_destination_ack.patch.
Candidate: scratch/p104_move_simple_dest_20260920/ap040_core.v.
Full Whetstone at latency 3: 31,784,029 -> 30,236,820 clocks (-4.868%).
Captured stack/globals/CODE3 match byte-for-byte with identical non-core sources,
image, ROM and flags. Evidence: scratch/whetstone_full_p104_20260920/comparison.json.
Numerical oracle remains pending; simulation gain is not a hardware Mix result.

Extended pipeline_memmove_values.py with --simple-destination 2/3/4.
The fixtures independently calculate values, CCR, destination updates and
source/destination An aliases, including source overlap with guard locations.
Predecrement P104 run: 144 fixtures across 3 phases PASS; 432 qualifying
read acknowledgements and 429 observed direct destination transitions.
The transition counter is sampled only when CE is enabled, so it is coverage,
not an equality oracle for acknowledgements. It must be nonzero on candidates.

Baseline and P104 all three modes completed with exit 0 (exec78372 and earlier predecrement run).
Broad integration is running under exec75762, log
scratch/p104_move_simple_dest_20260920/integration.log.
Dedicated simple-destination fault/restart/interrupt checks remain necessary;
existing indexed/displacement tests alone do not cover this change.
No P104 promotion, fit or hardware test yet. P102 Quartus remains active;
production build sources remain frozen until its entire wrapper finishes.

## Fault and boundary qualification

Extended pipeline_memmove_faults.py and pipeline_memmove_boundaries.py with
--simple-destination 2/3/4. Fault checks include failed source reads in plain,
postincrement and predecrement forms, then destination faults with all three
source forms. For every case the handler checks stacked SR/PC/fault address,
format 7, unchanged following instruction, destination sentinel, and both
address registers restored to their pre-instruction values. There is no
source/destination alias in this fault set. Extension-fault cases are excluded
for simple destinations because these addressing modes have no extension.

Both P102 baseline and P104 pass all six cases, three destination modes and
three bus phases (54 case/phase combinations per core). Exec38691 exited 0.
Logs: scratch/p104_move_simple_dest_20260920/{base,p104}_faults{2,3,4}.log.
These tests stop in the exception handler; they do not prove RTE retry.

Both cores also pass IRQ, T1 trace, source/destination-register alias and
page-split source fallback for all three modes and all three bus phases
(36 case/phase combinations per core). Exec86695 exited 0. The split case
uses the real MMU configuration with transparent translation and requires
S_MRD_B coverage. IRQ and trace checks verify stacked next PC/SR and that
the destination write has completed. Logs in the same directory named
{base,p104}_boundaries{2,3,4}.log.

Remaining before promotion: complete broad integration (exec75762 still live),
dedicated fault recovery through RTE for these modes, and candidate corpus
comparison. Fit inputs remain frozen for active P102; no hardware change.

Update: broad integration exec75762 has now completed with exit 0, including
all programs and final precise IRQ/load/store/PEA replay gates. Dedicated RTE
recovery and corpus comparison remain pending.

## RTE recovery and corpus results

New scripts/cpu/move_simple_restart.py builds real 4K MMU page tables with
an invalid source or destination page. The handler verifies the format-7
frame, stacked PC/SR/fault address, both rolled-back address registers and
that the following instruction has not changed D2. It repairs the descriptor,
flushes the ATC and executes RTE. The resumed program requires exactly one
fault, correct final CCR/data and exactly the expected address updates.

Both P102 and P104 pass 36 cases each across three bus phases (108 case/phase
combinations per core): byte/word/long, postincrement/predecrement sources,
plain/postincrement/predecrement destinations, source/destination invalid page.
Exec76136 and exec17114 completed with exit 0. Evidence:
scratch/{base,p104}_simple_restart_20260920 and
scratch/p104_move_simple_dest_20260920/restart_summary.json. This gate uses
separate source/destination registers and 4K pages; same-register fault alias
and 8K-page recovery are not covered by it. Successful aliases are covered
by the earlier value and boundary tests.

Candidate first-100 corpus comparison completed with exit 0 (exec13784):
1,900 field groups match, zero differences. Artifacts:
/tmp/cpu-corpus100-gate.x7wk5R. This is only the fixed first-100 payload,
not the full corpus. Candidate and supporting RTL were copied to
scratch/p104_move_simple_dest_20260920/tree before compilation.

The planned simulation qualification is complete. P104 remains isolated
while P102's fit wrapper is active. Next inspect P102 timing/archive, then
choose the next hardware build without mixing candidates mid-flow.
No P104 hardware speed or timing claim is made.

## Full-machine simulation launched

Isolated tree: scratch/p104_fullguest_20260920/tree, archived from 5331351
with only ap040_core.v replaced by the qualified P104 candidate. Untracked
Mac CD helper sources are copied and hashed too. identity.json records all
simulation source hashes and the original/disposable seed disk hashes.
The disk is a fresh copy of MacQuadra800-Speedometer402-profile.hda.

User service q800-p104-fullguest-20260920 is active, MainPID 3466299, building
with the same development flags as P97 (CD/audio and Ethernet omitted).
After build it runs the full quadra800 simulator with the fastboot ROM,
which skips the ROM RAM test. This does not exercise MiSTer's emu top wiring.
The initial control stream waits 1,200,000,000 CPU rising edges and takes a
screenshot. No keyboard or benchmark commands have been queued. Review the
boot screenshot before navigating; do not assume the old replay still matches.
Build, run and control files are all in that isolated run directory.

Boot, Benchmark Mix, timer validity and normal guest shutdown remain pending.
The observer must be inspected for actual coverage; an empty log cannot
establish timer validity. No full-machine score is available yet.
P102 Quartus remains active and its source hash verification passes.
