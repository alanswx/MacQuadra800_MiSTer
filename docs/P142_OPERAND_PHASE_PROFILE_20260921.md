# P142 current operand memory cost profile

Observation-only scratch bench patch `scripts/cpu/whetstone_operand_phase_profile.patch`, measured with P137 core/P120 pipeline/P136 cache. Evidence: `scratch/whetstone_p142_operand_profile_20260921`. Root verified unchanged 26,243,771 loop / 26,244,399 returned clocks, all three captures and every non-bench identity. No independent Whetstone numerical or hardware performance claim.

The counters exclusively partition ordinary S_MRD/S_MWR clocks into unissued setup, prefetch ownership wait, issued response wait, successful acknowledgement and error. A runtime assertion checks complete accounting. Return-consumer totals combine reads/writes when they share a return state; split-transfer states are outside this partition.

| Return consumer | Setup | Prefetch wait | Issued response wait | Successful ack |
|---|---:|---:|---:|---:|
| Ordinary operand S_PIPE_SDONE | 304,898 | 262,427 | 1,117,170 | 1,614,785 |

FPU result-store setup alone costs 241,440 clocks. FMOVEM S_FPU_MVM3 has 104,540 setup clocks across reads and writes. P143 screens early FPU store issue to address these costs.

The hottest ordinary-read opcode is `2f10` (MOVE.L (A0),-(A7)): 806,114 clocks, comprising 160,422 setup, 129,399 prefetch wait, 195,473 issued wait, 320,820 successful acknowledgements. This makes operand issue/prefetch scheduling another concrete target. These are measured state costs, not all removable cycles.
