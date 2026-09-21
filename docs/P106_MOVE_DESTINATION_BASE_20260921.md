# P106 settled MOVE destination base

Isolated candidate over production P105, while the P105 seed23 fit runs.
UNAPPLIED scripts/cpu/move_destination_base_early.patch.
Candidate core scratch/p106_move_dest_base_20260921/ap040_core.v.

The previous P104 change starts simple destination EA setup on successful
source acknowledgement. P106 also selects that base register while S_MRD
waits. If the selector already matches and neither ordinary nor auxiliary
register writes are pending, it performs the existing S_EA_DISP address
calculation and postincrement/predecrement rollback recording at acknowledgement,
then enters S_PIPE_DEA. The loaded source is still captured separately and
ordinary destination store/flags handling follows. Otherwise the P104 path
remains. Source faults and split reads keep their existing completion paths.
Preparing a register selector causes no memory access or architectural update.
Byte A7 adjustments still use an_adj, and rollback still uses u_rec.

Initial Luna screen passed: full Whetstone 30,236,820 -> 29,454,150 loop
clocks (2.588% fewer), with identical stack/global/code captures. This is
differential correctness, not an independent numerical oracle. Simple
destination modes 2/3/4 passed value, boundary and fault gates; the 4K MMU
restart gate passed. Additional A7 source/destination gates pass for both P105 and P106: each
of the 12 invocations covers 144 value/CCR/address/guard fixtures across
three bus phases, including byte adjustment by two and aliased A7. Generated
assembly and completed run logs were inspected. These are successful-access
checks; they do not extend the existing fault/RTE gate to A7. Broader CPU
integration/corpus is running under Luna; results pending.
The existing value monitor's direct-EA coverage expects MRD->EA_DISP; do not
use --require-direct-ea to claim this new MRD->PIPE_DEA transition is covered.
Existing value/CCR/alias/guard checks and acknowledgement counts remain enabled.
No production RTL changes, full integration, fit or hardware qualification yet.

P105 seed23 fit is active as q800-p105readselector-seed23-fit-20260921,
wrapper4056715 and quartus_fit4056834 at launch. Buildinputs frozen through
whole wrapper/archive/STA. MiSTer readiness screenshot confirmed Main menu,
slot0 disposable test HDA, no hardware inputs or reset sent.
