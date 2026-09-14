# Reference documents

- `MC68040UM.pdf` — M68040 User's Manual (Motorola/NXP, MC68040UM/AD).
  Section 4 (Instruction and Data Caches) is the reference for `ap040_cache`.
- `MC68040UMAD.pdf` — the 1998 addendum: errata and clarifications, including
  the misaligned-read-plus-snoop tearing case (item 9) and the copyback
  misaligned-write fault case (item 10).

## Cache-chapter points checked against `ap040_cache.v` (2026-09-14)

| manual | this core |
|---|---|
| 4 KB per side, 4-way, 64 sets, 16-byte lines, physical tags | same |
| set index from untranslated page-offset bits, in parallel with translation | same since the registered-admission change |
| data reads access a half-line (two longwords); misaligned operands inside it cost one access, across it two | spanning reads inside a line cost one extra cycle (a line read of the hit way); line-crossing reads still bypass the cache |
| replacement: first invalid line, else a counter | first invalid way, else round robin (adopted in the write-path candidate; was round robin only) |
| line fill: requested longword first, IU proceeds when it arrives; hits under fill served | fill waits for all four beats before acknowledging; no hit-under-fill (open) |
| write-through stores update matching lines; no write-allocate | aligned stores update; misaligned or uncacheable stores invalidate the whole set (open: two-word merge) |
| copyback mode with per-longword dirty bits, push buffer | write-through only |
| cache-inhibited access to a resident line invalidates it | same |
| instruction cache line holding register caches short loops | branch-refill sector buffer plus the 128-bit line buffer |
