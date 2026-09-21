# P146 successful MOVE read to ordered write handoff

Unqualified isolated P137 core candidate SHA256 `eb2b7b80bc927fdb67bafac49c477cfb4cfdabbd6c05f6c48f7d0da6c4ca0f6b` at `scratch/p146_move_read_write_handoff_20260921/ap040_core.v`; patch `scripts/cpu/move_read_write_handoff.patch`. Use P120 pipeline/P136 cache. Production remains frozen for P136 FPGA fitting.

For ordinary memory-to-memory MOVE with a settled simple destination base, consume the successful source response into the existing ALU and issue the destination write on the same edge. Preserve destination An undo/update ordering. Read errors retain precedence; split source reads and unsettled/extension destination modes keep the existing path. The early request remains restricted to on-board RAM and a within-page destination; other destinations retain delayed issue. No speculative write or new address hint is added.

This changes the core/MMU/cache consecutive-request contract and is not qualified by existing read-only checks. First screen full original workloads and exact captures, then require directed read-to-write exact-once, source/destination faults, same-An updates, partial/page-spanning writes, stalls and integration before any FPGA use. No gain or correctness claim yet.
