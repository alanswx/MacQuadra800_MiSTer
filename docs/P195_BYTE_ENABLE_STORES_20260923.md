# P195: cache store hits write their own bytes (byte-enable data RAMs)

A store that hit used to read the old word and merge into it: `lw_merge` against `posted_word` (the
data read made in the store's accept clock, captured in its first C_PASS clock), and for a store
spanning two longwords (Pascal's 2-mod-4 stack longwords) a whole line read (`sline_read`) before the
store could even post (`m_posted` waited for `sline_ready`; P187 then captured the merge words so the
idle read could resume).  That tied every store to the data read in its accept clock -- the read the
hint bus indexes -- which is what kept the next access from being hinted there.

Now the twelve data arrays (`cdata0..3`, the pair mirrors `pairdata0..3`, the instruction mirrors
`idata0..3`) take per-byte write enables (`cd_be0..3`).  One positioned value and one byte mask over
the pair {word w, word w+1} (`st_val`, `st_be`, from the size and offset) serve every store shape: a
store inside one longword writes the high half into `wr_arr`; a spanning store writes both halves
(`wr_arr`, `wr_arr1`); a line-crossing store writes the high half into word 3 of its first line and the
low half into word 0 of the next (`cross_second`).  Fills write all four bytes.  So:

- no store reads the old data: `posted_word`, `lw_merge`, `pair_new` and the cross merges are dead;
- a spanning store posts at once (`m_posted = post_active`), and `sline_read` is gone;
- a store's only remaining dependence on its accept clock is the tag lookup (`look_hit`, `hit_way`) --
  the step that lets the core hint the next access in a store's acknowledge clock is to read the tag
  RAM at the request's own row then (`c_hint_away`), not yet done.

Against P193 (latency 3; Whetstone with writes latency 1): Whetstone 21,664,729 -> 21,299,601 (-1.7 %),
Dhrystone 93,104,302 -> 91,954,305 (-1.2 %), Permutations (lat 0) 996,189 -> 984,476 (-1.2 %), Towers
16,958,527 -> 16,798,324 (-0.9 %).  All six fixture oracles and controls (latency 0 and 3, Quick and
Puzzle with the 8K MMU) and the AP68040 self-tests (`cache`, `cache_snoop`, `cache_xstore`,
`bitfield_cache`) pass.

Synthesis must infer the arrays as byte-enabled M10K (Quartus recognises the per-byte conditional
writes); check the RAM summary in the .map.rpt after the fit.
