# AP68040 lookup read-ahead: cached hits in the acceptance cycle

AP68040 `b80a79e`/`d325967` (branch `wombat-lookup-readahead`, on top of
Alan's `164a376`), wired in `rtl/wombat_cpu.sv`. 2026-09-12.

## The cost it removes

Every CPU memory access goes core → `ap040_mmu` → `ap040_cache` → bus.
With translation enabled (Mac OS and A/UX both run the MMU) a cached
longword read cost four cycles from the request register to the ack,
because each stage only started its RAM read once the stage in front of
it had finished:

```
edge N    core registers mem_req/mem_addr            (Alan's early issue)
cycle N+1 MMU sees c_req, reads the ATC row           (l_row <= a_row)
cycle N+2 ATC row out -> atc_hit -> pass_ok -> cache c_req; cache reads
          its tag row and data ways                    (rd_accept, C_LOOK)
cycle N+3 C_LOOK compares, ack_r <= 1
cycle N+4 core sees d_ack, retires
```

Alan's full-machine profile of Speedometer had `S_MRD` at 35 % of all
clocks and fetch at 13 %; that chain is most of it.

## What changed

Two independent pieces, either works alone.

**1. Idle read-ahead in the cache.** The cache's tag row already free-ran
on the live address; the data ways were read only on acceptance. Now, in
every `C_IDLE` cycle, all four data ways are read too, at the address the
MMU is presenting (or the hint below). The set index is `addr[9:4]`, inside
the 4 KB/8 KB page offset, so it is right before translation finishes. The
cache remembers `{bank, set, word}` of that read (`rdy_idx`), that it was a
plain idle read with no port-A write on the same edge (`rdy_ld`), and
whether a port-B invalidate landed on that edge (`rdy_poison`, free-running
like the snoops). When a cacheable read is then accepted and the remembered
index equals the request's, no snoop targets the row now, and one of the
four tags (compared against the *live* physical tag) is valid and equal,
the hit completes in the acceptance cycle: `rdata_r`/`ack_r` are registered
exactly as `C_LOOK` would have done one cycle later. Anything else takes the
unchanged `C_LOOK` path. An instruction hit here seeds the sequential
lookahead (`ipred`) the same way a `C_LOOK` hit does.

**2. A one-cycle-early lookup hint from the sequencer.** The operand
address is a register one cycle before `mrd()`/`mwr()` issue it (`ea_addr`
after `S_PIPE_START`, `dst_addr` after `S_PIPE_DEA`), and the fill engine's
next fetch address is `epf_ftail`. The core now exports
`pre_valid/pre_instr/pre_addr/pre_fc`, asserted in the cycle *before* the
request registers, under the same terms as the issue itself (data:
`S_PIPE_SRD`, rmw `S_PIPE_DEA`, `S_EXEC` ALU stores to the RAM window,
aligned, port idle; fetch: the engine's own conditions minus the same-cycle
port claims it cannot see). The MMU reads the ATC row on the hint so
`lk_fresh` already holds when `c_req` arrives, and forwards the hint to the
cache so the read-ahead happens one cycle earlier still. Both consumers
re-validate against the request that actually follows (`lk_fresh` compares
the piped row/tag with the live request; the cache compares `rdy_idx`), so
a hint that does not turn into a request is a wasted RAM read and nothing
else.

Result, translated cached read:

```
cycle N-1 hint: MMU reads ATC row, cache reads tag row + ways   (pre_*)
edge N    core registers the request
cycle N+1 lk_fresh -> pass_ok -> cache accepts, read-ahead matches,
          fast hit -> ack_r <= 1
cycle N+2 core sees d_ack, retires
```

Untranslated / TTR-mapped reads go from three cycles to two (the hint
gives the cache its read-ahead cycle); the sequencer's own states are
unchanged.

## Hazards considered

- **Row written under the read-ahead.** Port A writes (`C_TAGW`, `C_SWEEP`)
  cannot coincide with an idle read (`rdy_ld` requires `C_IDLE` and
  `!tag_we`). Port B writes (snoops, store/CI/fill-error invalidates) are
  free-running; `rdy_poison` records one on the read-ahead edge and the
  fast path yields to `C_LOOK`, which re-reads the row. A snoop in the
  acceptance cycle itself (`snoop_look_row`) also yields, and `look_snooped`
  then forces the miss as before. A snoop earlier than that has been
  re-read cleanly (the tag row free-runs every clock).
- **Data RAM writes** happen only in `C_FILL`/`C_PASS`, never in `C_IDLE`,
  so the read-ahead data cannot be stale relative to the tags.
- **The lookahead's own read** keeps priority for the data port
  (`ipred_read`); a read-ahead never displaces `ipred_data`, which is
  captured from `data_q` on the following edge by non-blocking assignment.
- **ce low.** Reads free-run with the held address; `rdy_ld/rdy_idx` are
  ce-gated, `rdy_poison` is not, matching the snoop port's own domain.
- **Wrong hint.** The hint only chooses which row the RAMs read; every
  consumer validates against the live request, so a hint for an address
  that never issues (or whose FC differs) simply falls back.
- **Fault timing.** The ATC compare still happens on the real request;
  `need_walk`, `atc_fault`, `c_flt` are unchanged, only earlier.

## Verification

- `tb_ap040_cache_snoop` T14 (new): early-address hit and hinted hit each
  one cycle faster than a plain hit; snoop on the read-ahead edge and in
  the acceptance cycle both refetch changed memory; an instruction
  read-ahead hit seeds the lookahead (next word from the predictor, zero
  bus beats). T12's plain-hit baseline moved to a word the read-ahead is
  not holding.
- Complete AP68040 suite (reset, double_fault, walker_cdc, bus16_gap,
  bus_timeout, cache_snoop, integer, exceptions, mmu, cache, fpu): pass.
- SingleStepTests first 100 CPU rows vs the Quadra 800 silicon capture:
  1,696 field groups match, 0 REAL diffs (31,904,073 cycles, unchanged --
  the corpus payload runs with the caches off).
- `bench_loop` (+prof +memlat), all three phases:

| | 164a376 | read-ahead | change |
|---|---:|---:|---:|
| phase 0 (translated) | 147,012 | 133,628 | -9.1 % |
| phase 1 / 2 (cached) | 147,790 | 134,406 | -9.1 % |
| `S_MRD` cycles, phase 2 | 39,338 | 26,554 | -32 % |
| data read request→ack, avg | 2.0 | 1.0 | |
| ifetch request→ack, avg | 1.7 | 1.3 | |

Hardware: see `docs/PERFORMANCE_MEASUREMENTS.md` §14 once built and
gated.

## Cost

Logic: four 22-bit tag compares against the live tag, a 4:1 data mux, the
`rdy_*` registers, the hint decode in the core (a state compare and an
alignment check) and the address muxes in the MMU/cache RAM read ports.
Fit numbers in §14.

## Follow-ups on the same branch (AP68040 `9216f3e`)

**Fill hold behind a resident redirect.** The fill engine no longer starts
a speculative fetch while the word at the head of the queue is a redirect
whose own extension words are already resident (Bcc/BRA, DBcc, JMP/JSR in
the fixed-length modes, RTS/RTE/RTR/RTD): the words past it are the
fall-through path, and a fill in flight when the redirect issues its
target fetch costs the taken branch two to three cycles (the redirect
cannot claim the port, `issue_ifetch` only re-arms the stream and the
engine issues later). Demand fetches are untouched: an empty queue has no
head to classify, and an instruction whose extension words are missing is
never classified.

**Short-branch target hint.** `S_DECODE` for Bcc.B/BRA.B and `S_BCC_EXT`
present the target through `pre_*` in the cycle they issue it, so the
redirect fetch finds its ATC and cache rows read. BSR keeps the ordinary
path (its redirect follows the push). A not-taken branch wastes one RAM
read.

**One-state store (`S_PIPE_STORE`).** `MOVE Dn/An/#imm` to `(An)`, `(An)+`,
`-(An)`, `d16(An)`, `abs.W`, `abs.L`: decode points port A at the source and
port B at the base and enters the new state (through `immf` when extension
words are needed, which decode's resident-immediate path often makes
free). The state captures both, adjusts An with the same restart record
`S_EA_DISP` keeps, sets MOVE's flags (N, Z from the value, V and C clear,
X kept) and issues the write through `mwr`, which issues it in that cycle
when the port is free; `S_MWR` completes or faults it exactly as before.
The generic path spent `S_PIPE_START`, `S_PIPE_SREG`, `S_PIPE_DST`,
`S_EA_DISP`, `S_PIPE_DEA` and `S_EXEC` on the same work, so a register
store drops from about nine cycles to about five. An An source is read in
the cycle its register may be adjusted, so `MOVE.L An,-(An)` stores the
original value, as the generic path does.

Verification: complete AP suite; first-100 silicon corpus 0 REAL diffs,
31,904,073 -> 30,185,494 cycles (-5.4 %, and the corpus runs uncached, so
this is the sequencer alone); `bench_loop` 134,406 -> 134,396 (it has 64
stores and its DBcc loop is served by the refill sector).

## Full-machine A/B (Verilator, fresh Mac OS 8.1 install image)

Half-cycles from reset to the ROM boot's first volume write (lba 98), a
fixed program point that includes the same 239 sector reads at the sim's
fixed 16,000-tick latency:

| core | half-cycles to first write |
|---|---:|
| Alan's 164a376 | 521,367,641 |
| + lookup read-ahead (d325967) | 492,953,061 (-5.5 %) |
| + fill hold and branch hint | 491,296,965 (-5.8 %) |
| + one-state store (9216f3e) | 453,064,767 (-13.1 %) |
