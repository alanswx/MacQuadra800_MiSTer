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
checks; they do not extend the existing fault/RTE gate to A7. Extended CPU integration passed under scratch/p106_move_dest_base_20260921/integration,
including 14,720 architectural snapshots and fault/replay/ownership checks.
The corpus launch initially used system Verilator 4.204, which lacks --binary;
it is being rerun with established /home/alans/verilator5/bin/verilator.
The first Verilator 5 rerun passed 1,900 field groups but used a stale
experimental pipeline file (152c494e...), not production P105 (9b0e3e00...).
That run is NOT qualification of the intended combination. Root caught the
identity mismatch and requested a corrected experimental/ copy and rerun;
valid corpus results remain pending.
The existing value monitor's direct-EA coverage expects MRD->EA_DISP; do not
use --require-direct-ea to claim this new MRD->PIPE_DEA transition is covered.
Existing value/CCR/alias/guard checks and acknowledgement counts remain enabled.
No production RTL changes, full integration, fit or hardware qualification yet.

P105 seed23 fit is active as q800-p105readselector-seed23-fit-20260921,
wrapper4056715 and quartus_fit4056834 at launch. Buildinputs frozen through
whole wrapper/archive/STA. MiSTer readiness screenshot confirmed Main menu,
slot0 disposable test HDA, no hardware inputs or reset sent.

## Corrected qualification

The corrected corpus run uses core 020ba551c9b63a3c7bd3f5370985b6f57fce26a9f3eb9a8487083503f1bad367
and pipeline 9b0e3e00e544e05c29c9b46611a1d2cad9f5aaba144b58d753d889ac22786dbc.
Verilator 5.050: 28,483,982 cycles; all 1,900 field groups match, zero real
differences, first 100 rows only. Evidence: corpus100_v5_correct.log and
/tmp/cpu-corpus100-gate.2xAA1f. The earlier stale-pipeline run stays discarded.
The integration program.vvp file table independently confirms the candidate
core path and production experimental pipeline path. The prototype's results
manifest includes the baseline core because it generates the reference trace;
it is not the source identity of the candidate integration executable.

Candidate is ready for promotion after the active P105 build wrapper finishes.
A P106 build wrapper is prepared under scratch/p106destbase_fit_20260921/run.sh
but has NOT been launched. Production build inputs remain unchanged.

## Promotion

After P105 seed23 completed all archive/STA steps, the exact qualified P106
core above was applied to production. move_destination_base_early.patch is
now historical/APPLIED. Pipeline and supporting RTL are unchanged. The next
fit retains seed23 and the development CD-ROM/Ethernet omissions.
