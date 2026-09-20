# P102 load payload selection — isolated timing experiment

P99's worst fitted CPU path is 27 logic levels, 31.129 ns data delay,
from mem_instr_q through MMU/cache/store-buffer acknowledgement, pipeline
load operand selection, ALU flags, and branch refill into epf_data[5][1].
CPU slack is -1.531 ns. This motivates removing acknowledgement from the
payload mux rather than adding latency to every read.

The unapplied patch `scripts/cpu/load_payload_state_select.patch` selects
m_val only in S_PIPE_LOAD_RETURN, otherwise mem_rdata. Existing response,
fault, flush, and retirement qualifications remain intact. Successful direct
responses select the same bus data; split returns select the same buffered
data. Values outside qualified responses may differ and are not valid results.

Candidate: scratch/p102_load_payload_20260920/ap040_core.v
SHA256: da5640f4c0087d72f7f52e179da180631726ebbc7c36c1784d9073f270ce4b32

Full original Whetstone at latency 3: 31,784,029 loop clocks, exactly P99.
Stack, globals and code captures match byte-for-byte against the P99 run
with identical instrumentation in scratch/whetstone_memory_profile_20260920.
Comparison: scratch/whetstone_full_p102_20260920/comparison.json.
This is differential evidence, not an independent numerical oracle.
The older P99 run correctly fails the comparison's non-core-source guard
because the bench instrumentation changed; the matching-instrumentation
baseline was used without relaxing that guard.

Read-completion IRQ gate passes all three bus phases, with three injected
interrupts and three cancelled pipeline records:
scratch/p102_load_payload_20260920/read_irq.log.
Broader pipeline_handoff integration is running under exec session 59618;
log scratch/p102_load_payload_20260920/integration.log. Its completion and
fault/split/CE-pause coverage must be reviewed before promotion.

Production RTL unchanged. No synthesis/fit or hardware test of P102 yet;
no timing improvement is claimed. MiSTer remains on the last P96 state.
