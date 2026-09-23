# P215-P220: associative data translation copies, MOVEM load chains, idle-read validity

All on top of P214 (`73783ab`).  Kernel fixtures unless noted; every change passes the six oracle
fixtures, the AP68040 self-tests, Dhrystone, Permutations, Queens and the Whetstone end-of-run RAM
checksum (`MEMSUM 5892d5df133547e0`).

## P215: the four data translation copies are fully associative (`ap040_mmu.v`)

The MMU keeps copies of its last ATC hits so a hint translates in its own clock.  The four data copies
were indexed by the page's low set bits.  Dhrystone's string copy (`move.b (a0)+,(a1)+`) reads from
page $61F while the stack is on $63F -- the same index -- so every source byte's hint found the copy
replaced (`hq_ok = 0`), took the three-clock lookup, and the MOVE store behind it lost its hint too.
The data copies are now matched on all four entries, filled round-robin (a page already present is
refreshed in place); the four instruction copies (P200) stay indexed.  Dhrystone -4.0 %.  The
compare now precedes the entry select on the hint path, which is the CPU clock's critical path.

## P216: MOVEM load chains (`ap040_core.v`)

`movem.l (a7)+,<list>` took two clocks a register (S_MOVEM_LOOP issues, S_MRD acknowledges).  The
acknowledge now performs the loop's step for the next register (ffs16 of the mask, `mm_reg`, the next
address) and, when the next read was hinted in the predicted acknowledge clock (`hint_mmn`, the P205
pattern), issues it in place (`mm_rd_next` in mem_issue's whitelist and port condition).

## P217: an answered spanning read no longer spoils the next idle read (`ap040_cache.v`)

P216 alone changed nothing: a 2-mod-4 longword (the MOVEM restore reads the stack at $xxx2) is
answered in one clock by the pair banks (`fast_pair_idle`), but `rd_accept` does not exclude reads a
fast path answered, so `idle_span_hit` fired in the same clock and started a line read
(`iline_read`) that replaced the next clock's idle read.  `idle_span_hit` is now suppressed when the
pair hit is predicted from its registered terms (`pair_pred`); a wrong prediction only sends the read
to the registered lookup.  Permutations -2.6 %, Towers -2.8 %, Quick -1.8 %, Queens -1.7 %, Whetstone
-1.4 %, Dhrystone -1.0 %.

## P219: the read-after-read handoff (`ap040_core.v`)

P196's handoff (the next instruction's source read issued in a retiring store's acknowledge) now also
follows a read that retires in its own acknowledge (`retire_operand_alu`: MOVEA, MOVE/ALU to a
register): `hint_rrr` shows the next (An)/d16(An) source in the predicted acknowledge clock and
`retire_read_read` issues it through apply_record's P196 branch.  Not (An)+/-(An) (the retiring
register write holds the one write port) and not when the next base is the register being loaded.
Puzzle -2.3 %, Permutations -1.3 %, Dhrystone -0.9 %.

## P220: an idle read is valid only if the arrays read the hint's row and word (`ap040_cache.v`)

P219's first version corrupted Permutations and Whetstone.  An event-stream diff (every register
write and every RAM write, P217 against P219) put the first divergence in Swap: `move.w (a1),d0`,
issued in place in `movea.l $c(a6),a0`'s acknowledge, read 0 from $400A where memory held 4.  The
MOVEA's source was a cross-line read ($DFAE) answered by `fast_xline_idle`; in that clock its
registered twin `idle_xline_hit` also fired (again `rd_accept` does not exclude answered reads) and
steered the data arrays to the next row (`rd_row`, `rd_w`), while `idle_data_valid`/`idle_data_idx`
recorded the clock as an idle read at the hint ($400A).  The in-place read on the next edge hit on the
other row's data.

`rd_redirect` (`idle_xline_hit || xlook_read || cross_lookup || cross_second`, the terms that move
`rd_row`/`rd_w` off the hint) now clears `idle_data_valid` and `idle_next_valid`.  **This was latent
since the handoffs that issue a read in place in an acknowledge (P198 RTS after UNLK, P205 FPU
operand chains, P216) met P178's cross-line hits; the P205 and P212 hardware builds carry it.**  They
ran cleanly, most likely because those handoffs read the address right after the cross-line one,
which the redirected read happens to fetch at the same alignment; P219's unrelated next address
exposed it.  Cost: Towers +0.7 %, Quick +0.4 %, Whetstone +0.2 % against P217.

## Results (P214 RTL's fixtures -> P220)

| fixture | P212 | P220 |
|---|---:|---:|
| Whetstone (wlatency 1) | 18,052,663 | 17,823,529 |
| Dhrystone | 90.20M | 85.00M |
| Permutations (lat 0) | 955,164 | 918,386 |
| Queens | 48,582 | 47,756 |
| Towers | 16,384,375 | 16,027,548 |
| Puzzle | 22,785,434 | 22,224,546 |
| Quick | 143,003 | 140,977 |
| Int. Matrix / Sieve / Bubble | 2,195,355 / 271,492 / 2,959,115 | 2,193,756 / 271,492 / 2,959,115 |
