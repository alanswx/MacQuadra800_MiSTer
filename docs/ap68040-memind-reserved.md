# AP68040: reserved full-extension encodings trap where 68040 silicon executes

**Component:** `ap040_core.v` (AP68040), effective-address decode
**Severity:** wrong exception — instructions that run on real hardware take vector 4
**Found:** wombat33_MiSTer CPU acceptance gate, scored against a **real Quadra 800**
capture (`SingleStepTests/results/allinone/cpu_hardware_quadra800_2026-08-28.jsonl`)
**Patch:** `docs/ap68040-memind-reserved.patch` (one term removed from one line)
**Status:** **APPLIED** to the vendored core on 2026-09-17 (branch add-CPU-fixes; it had been verified but never committed into the submodule). Verification: **VERIFIED** on the scored gate, 2026-08-30 — `cpu` goes from 2 REAL
diffs to 0, exactly as this report predicted, with no regression in any other
suite. See "Verification" below.

## Summary

For a 68020-style **full** extension word, `ap040_core.v` raises an illegal
instruction (vector 4) when the index is suppressed (`IS = 1`) and `I/IS[2] = 1`.
The M68000 PRM does mark that combination *reserved* — but **real 68040 silicon
executes it** and returns a value, so the guard is stricter than the part it
models.

This is the entire remaining CPU delta in the wombat33 gate: **2 REAL diffs out
of 717 rows / 13,585 field-groups**, both from this one term.

## The offending line

`ap040_core.v`, state `S_EA_EXTW2`:

```systemverilog
else if (extw[5:4] == 2'b00 || extw[3] ||
         extw[2:0] == 3'b100 || (extw[6] && extw[2])) begin
    go_illegal;
end
```

`extw[6]` is **IS** (index suppress); `extw[2]` is the top bit of **I/IS**. The
final term is the PRM's "if IS=1 then I/IS must be 0xx" rule. The other three
terms are correct and should stay.

## Evidence

Every memory-indirect row in the corpus, with its extension word decoded. The
guard fires on exactly the two rows that fail — a 4/4 correlation:

| test | extw | BS | IS | BD size | I/IS | guard fires | gate result |
|---|---|---|---|---|---|---|---|
| `MOVE.L ([bd.W,A6]),D1` | `0x0165` | 0 | **1** | word | **101** | **yes** | **FAIL** vec 4 |
| `MOVE.L ([bd.W,A6],D0.L*2,od.W),D1` | `0x0B26` | 0 | 0 | word | 110 | no | pass |
| `MOVE.L ([bd.W,A6,D0.L*2],od.W),D1` | `0x0B22` | 0 | 0 | word | 010 | no | pass |
| `MOVE.L ([bd.W=0,A6],od.W=4),D1` | `0x0166` | 0 | **1** | word | **110** | **yes** | **FAIL** vec 4 |

Silicon, from the hardware capture — all four report `"vec": 0`, i.e. **no
exception taken**. For row 1 the machine returned `D1 = 0x40809AE6` (a ROM
pointer that lives at `$1820` on a real Quadra; the value differs from the
synthetic `0xDEADCAFE` only because the bench read live low memory). The point
is the vector, not the datum: hardware executed, AP68040 trapped.

## Why removing the term is sufficient

The datapath already handles these encodings; only the guard rejects them. With
`IS = 1` the very next lines force the index to zero:

```systemverilog
ea_idx_v <= extw[6] ? 32'd0 : idx;   // IS = 1 -> index is 0
ea_post  <= extw[2];
```

and every later use of `ea_post` adds `ea_idx_v`, which is zero:

```systemverilog
// S_EA_BD
mrd(ea_base_v + bd + (ea_post ? 32'd0 : ea_idx_v), `AP040_SZ_L, S_EA_MIND);
// S_EA_MIND / S_EA_OD
ea_addr <= ea_mind + (ea_post ? ea_idx_v : 32'd0) + od;
```

So with the index suppressed, "pre-indexed" and "post-indexed" are
arithmetically **identical** — adding 0 either side of the indirection. That is
almost certainly why the real part does not bother to trap: the encoding is
harmless, and `I/IS[1:0]` still selects the outer-displacement size, which
`S_EA_MIND` already decodes (`01` null, `10` word, `11` long).

Dropping the term therefore makes the two rows execute and compute the correct
address, with no other change.

## Patch

`docs/ap68040-memind-reserved.patch`, generated against AP68040 `0e76761`. It
deletes `|| (extw[6] && extw[2])` and adds a comment recording why. The other
three illegality checks are untouched — `BD SIZE = 00`, `extw[3] != 0` and
`I/IS = 100` remain rejected.

## History: how this was briefly mis-attributed (2026-08-30, earlier)

The patch was built into a core (`544d7976`) and run on the MiSTer at .143
against the `2026-08-28b` bench image. The bench stalled after the happy Mac at
file offset 65536, without completing the payload read.

**I first recorded that as "the patch regressed hardware". That was wrong.**
The control was then run in all four combinations, and they are identical:

| | hardware | Verilator |
|---|---|---|
| patched CPU | stalls, `pos=65536` | stalls, `ncr=2042`, last `lba=97` |
| stock CPU   | stalls, `pos=65536` | stalls, `ncr=2042`, last `lba=97` |

The bench did not run on this core **with or without** the patch, so the patch
was not responsible. Two lessons worth keeping: the first attribution was made
without running the stock-CPU control, and **both** halves of the comparison used
the HARDWARE-flavor image — which `RESUME-disk-gate.md` says needs
`make-emulator-gate-disk.sh` re-blessing, "FPGA runs need this image too". Every
cell of that matrix is a property of the disk, not of the core.

**Where that left the patch at the time: unverified, not disproven.** The decode
analysis and the 4/4 encoding correlation stood, and the hardware capture showing
`vec = 0` stood; what was missing was a scored before/after, blocked on the bench
not running. That block turned out to be the disk, not the core — see
Verification.

Separately, the last SCSI transaction before the bench stall completes textbook
clean (read `lba=97`, 512 bytes, status, command complete, message accepted, bus
idle). The engine is healthy and idle — the driver simply stops issuing
commands. So the bench stall is a software/CPU-side stop, not a SCSI wedge, and
it wants its own investigation.

## Verification (2026-08-30)

The bench never ran because **`gate.hda` was the hardware-flavor image**, byte
identical (md5 `309e785d…`) to the raw prebuilt on both the MiSTer and the
laptop. `RESUME-disk-gate.md` already said the emulator-flavor re-bless is
needed and that "FPGA runs need this image too"; it had simply never been
applied. Re-blessing it with `docs/tools/make-emulator-gate-disk.sh` makes the
bench run to completion — the stall was never a CPU or SCSI fault.

Full-machine Verilator runs, same blessed disk, same fastboot ROM, scored with
`gen/score_vs_oracle.py` (no `--flat-env`) against the 2026-08-28 Quadra 800
silicon captures:

| suite | rows | stock `ap040_core.v` | with this patch |
|---|---|---|---|
| **cpu** | 717/717 | **2 REAL** (13,585 field-groups) | **0 REAL** (13,623) |
| fpu | 270/270 | 0 REAL | 0 REAL |
| saverestore | 8/8 | 0 REAL | 0 REAL |
| integration | 1328/1328 | 0 REAL | 0 REAL |
| mmu (full) | 24/25 | 13 REAL | 13 REAL (unchanged) |

The two stock-CPU diffs are exactly the rows this report names, and nothing
else:

```
REAL  MOVE.L ([bd.W,A6]),D1  memind no-idx no-od (->DEADCAFE)      vec: oracle 0 candidate 4
REAL  MOVE.L ([bd.W=0,A6],od.W=4),D1  postindexed no-idx (->FEEDFACE) vec: oracle 0 candidate 4
```

Both disappear with the patch, and the field-group count *rises* by 38 — the
instructions now execute and their result fields get compared instead of the
row ending at a trap. **The prediction in this report — "should go from 2 REAL
diffs to 0" — was made before the gate existed and is what the gate returned.**

Raw rows are archived beside this report:
`SingleStepTests/results/ap68040/fullmachine_cpu_stock_2026-08-30.jsonl` and
`…_cpu_memindpatch_2026-08-30.jsonl`.

The MMU 13 are unrelated to this patch (identical in both arms) and are a
full-machine-harness question: `results/ap68040/README.md` records 24/24 with 0
REAL diffs under the `preboot/sim040` corpus harness, which supplies the
identity-translation world the MMU corpus needs. They are not evidence about
this change either way.

The submodule is deliberately left clean at `0e76761`: this is a vendored
upstream tree, so the patch belongs upstream rather than as a local divergence.

## Caveats, stated plainly

- **Scored against a silicon capture, not run on silicon.** The check is the
  wombat33 `cpu` gate against the Quadra 800 capture, and it is now green; the
  patched core has not been run on a real 68040.
- **No evidence this causes the disk corruption** being chased separately in
  wombat33. An illegal-instruction trap is loud — a bomb or Sad Mac — not silent
  data damage. It is a real defect worth fixing on its own merits; it should not
  be assumed to be the corruption's cause without evidence.
- The reserved encodings are not something a compiler emits; this matters for
  hand-written or generated code that uses them, and for any test suite scored
  against silicon.
