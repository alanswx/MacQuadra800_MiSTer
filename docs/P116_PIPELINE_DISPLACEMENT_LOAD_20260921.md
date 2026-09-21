# P116 pipeline displacement loads

UNQUALIFIED isolated experiment over P109 core/P105 pipeline, screened with
P113b cache. Production remains frozen for P113b's active fit.
Candidate directory scratch/p116_displacement_pipeline_load_20260921:
- ap040_core.v SHA25612ca13c0a335a7cad55b61396df6f8f48ea55086512491da61e43cd4f16200ec
- ap040_pipeline_integer.sv SHA256293fac83ca3c46ef3f0fcce21f6b197354b29cbe3323f592bf90151862d3b7f1
Unapplied patch scripts/cpu/pipeline_displacement_load.patch.

Adds d16(An) source MOVE.B/W/L to Dn and MOVEA.W/L to An using the existing
pipeline load transaction and retirement path. The address adds the signed
16-bit extension to the forwarded source An; destination partial-register
merging uses the existing ordinary destination port. MOVEA word sign-extension
and CCR preservation reuse the existing address-register load writeback.
Byte-to-An remains illegal. Admission requires the extension, without the
brief-index bit8 restriction; same-page late extensions may wait using the
existing admission wait, while cross-page/fault cases retain fallback.
The sequencer's resident lookahead routes these opcodes to pipeline admission.

Original Whetstone/Dhrystone performance and output screens are pending.
A gain would still require directed positive/negative/full-range displacement,
source/destination aliases, partial Dn values, MOVEA sign/CCR, extension and
operand faults with RTE repair, IRQ/trace/CE pauses, page-crossing accesses,
integration/corpus checks and eventual hardware evidence. No production
promotion, timing or hardware claim is made by this prototype.
