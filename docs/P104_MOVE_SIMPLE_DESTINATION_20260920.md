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

Baseline all three modes and P104 modes 2/3 are running under exec78372.
Broad integration is running under exec75762, log
scratch/p104_move_simple_dest_20260920/integration.log.
Dedicated simple-destination fault/restart/interrupt checks remain necessary;
existing indexed/displacement tests alone do not cover this change.
No P104 promotion, fit or hardware test yet. P102 Quartus remains active;
production build sources remain frozen until its entire wrapper finishes.
