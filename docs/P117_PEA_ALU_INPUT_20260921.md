# P117 remove unused PEA address from integer ALU input

Isolated timing experiment over P105 pipeline, with P109 core/P113b cache.
Candidate scratch/p117_pea_alu_input_20260921/ap040_pipeline_integer.sv SHA256
3a655f6901beaaf40d8fd17a2f5181f22177e750fab5249757bdb3b3f25e5e11.
Unapplied patch scripts/cpu/pipeline_pea_alu_input.patch.

P112's worst CPU path starts at sr[13], traverses banked A7 selection,
pipeline pea_index and an integer ALU flag calculation, then branch lookahead
and epf_data. PEA's computed push address reaches the ALU via load_wdata even
though PEA preserves CCR and writes back only the updated SP. This creates a
combinational path through logic whose result PEA does not architecturally use.

P117 feeds the store-side ALU from held load_wdata_r when load_pending, or
source_full otherwise. For ordinary stores this equals the existing load_wdata;
for a live PEA offer it omits the computed effective address from the unused
ALU input. The real memory push data/address, held request fields, store flags,
SP update and retirement controls are unchanged. It adds no cycle or clock.

Original workload exact-cycle/output screens and extended integration,
including PEA faults/trace/IRQ/replay, are pending. Synthesis may restructure
this differently than expected; only a later fit can establish timing impact.
Production inputs remain frozen for the P113b fit.

Both original workload screens preserve exact baseline clocks: Whetstone
28,747,437 loop/28,748,087 return; Dhrystone120,954,440/120,955,328.
Root verified all3/5 captures and all supporting identities except pipeline
against P113b. Independent Dhrystone checker passes. Evidence directories:
scratch/whetstone_full_p117_20260921 and scratch/dhrystone_full_p117_20260921.
Extended integration is running in scratch/p117_integration_20260921;
its intermediate passing stages are not yet a final qualification result.
