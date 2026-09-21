# P161 consume the retirement-time read request

Unqualified correction over P159 (not P160). Source `scratch/p161_alu_read_dispatch_20260921/ap040_core.v`, SHA256 `a0d6053901b044128d9c6ff1513f19d2cc9318ad3285b1ddd226809022359770`; patch `scripts/cpu/alu_read_late_dispatch.patch` applies to P159.

The lookahead apply_record site executes after the common mgo dispatcher. P159's late mrd was therefore never consumed; the following instruction returned through decode instead of launching its read. P161 calls mem_issue immediately after that late mrd, then clears mgo. This is restricted to the same address-register ALU producer and following indirect memory-MOVE dependency. It does not move the global dispatcher or duplicate its earlier calls. Existing RAM/page/port guards remain inside mem_issue.

Original Whetstone screening and a directed before/after-edge forwarding fixture are running with explicitP120/P136. Require positive actual S_PIPE_REGS-to-S_MRD request coverage, correct new-versus-old address selection, flags/guards, and then faults/boundaries/full integration if worthwhile. No correctness, speed, timing or hardware claim yet. Production remains frozen for P150.
