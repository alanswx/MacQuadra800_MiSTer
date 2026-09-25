# P119 decode an already resident opcode on its fetch edge

UNQUALIFIED isolated P109 core candidate screened with P113b cache/P105
pipeline. Production remains frozen for P113b's fit. Candidate
scratch/p119_resident_fetch_decode_20260921/ap040_core.v SHA256
c8128fbf15c6e2ada56271a6473b035e2a5ed708de3f864e12467eaeeb593ae1.
Unapplied patch scripts/cpu/resident_fetch_decode.patch.

The normal S_FETCH branch already consumes the buffered opcode and performs
per-instruction initialization, then enters S_DECODE. When the opcode is
registered in the queue, P119 permits existing descriptor/record classes to
use the shared decoder on this edge. It asserts the existing queue-dispatch
request only after S_FETCH's exception/flow-trace checks, with no auxiliary
write, and only for rd_valid or n_apply_ok. S_FETCH is added to the register
descriptor's producer whitelist. The later pipeline-admission exclusions
remain in place; forwarded fetches retain ordinary decode because the queue
head need not yet contain their opcode.

Performance/output screens await completion of the P118 attribution runs.
Any gain still requires full integration/corpus and directed IRQ/trace,
exception-handler entry, privilege/A7-bank transition, immediate-word count,
queue-forward collision and extension/fetch-fault checks. No timing or
hardware result is claimed. This is a fetch/decode overlap experiment, not a
change to architectural instruction semantics or clock frequency.

Initial screens are output-identical but the gain is small: Whetstone
28,720,671 loop/28,721,320 return (26,766 fewer loop clocks,0.0931%);
Dhrystone loop unchanged120,954,440, return120,955,327 (one clock less outside
the measured loop). Root verified all captures and non-core identities,
and ran the independent Dhrystone checker: PASS. Evidence directories
scratch/{whetstone,dhrystone}_full_p119_resident_20260921. Parked without
broader qualification or a fit; P120's admission change has the larger gain.
