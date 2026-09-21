# P158 memory MOVE preparation origin profile

Observation-only standard Whetstone bench extension; patch `scripts/cpu/move_preparation_origin_profile.patch`. Source `scratch/p158_move_preparation_origin_20260921/tb_cpu_whetstone.sv`, SHA256 `2855311aa61d98d9e6d038cf29903d7c290b0acc566588f2339b91d2e9003f3b`.

Counts the preceding registered core state when S_PIPE_START handles memory-to-memory source operands, by source addressing mode, and separately for hot opcode2f10. Mode2 counters also record portA selection and pending register/auxiliary writes. This observes actual preparation origin without racing the core's blocking rd_queue_pop signal. Current-cycle selected-port counts do not prove the port was settled a cycle earlier.

Run queued on P154/P120/P136, requiring unchanged25,330,407 loop/25,331,035 returned cycles, all three captures and non-bench source identities before interpreting results. No origin measurements yet; no CPU changes. Intended to explain why normal-decode-only P157 did not improve the workload before choosing a different dispatch point.
