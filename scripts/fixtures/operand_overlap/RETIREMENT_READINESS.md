# Optional retirement readiness observer

`retirement-readiness.patch` adds read-only counters to an isolated copy of
`scripts/fixtures/wombat_sieve/tb_wombat_sieve.sv`. It does not change the
default fixture, CPU RTL, state, stimulus, queue, or memory protocol.

Patch-base SHA256:
`284ae2e616697b08e45e1ea01fd0eea704235d81b43c1462b0bdff852f107b57`.
Patched observer SHA256:
`78cf6fa8e0fbae899f8ec6601ad6882c3f484fbb5725c68e55f7bd72fae2ebf6`.

The harness is **RAM integration, unchanged Sieve, first outer pass only**,
at byte offset 16 (`kernelpc=2010`), CE enabled continuously, with CPU cache,
store buffer, and actual SDRAM model. It is not the AP alignment harness or
the full 100-pass acceptance gate. Existing array, guard, store-drain and
SDRAM protocol assertions remain enabled. Run serially per copied fixture.

## Reproduction

These commands create a new owned fixture root. Use absolute paths and verify
CPU hashes immediately before each run. No active file is patched.

```sh
set -eu
repo=/home/alans/mister/MacQuadra800_MiSTer
observer_root=$(mktemp -d /tmp/operand-readiness.XXXXXX)
mkdir -p "$observer_root/scripts/fixtures" "$observer_root/rtl/ap68040/tb" "$observer_root/verilator"
cp -a "$repo/scripts/fixtures/wombat_sieve" "$observer_root/scripts/fixtures/"
cp "$repo/rtl/ap68040/tb/prepare_exact_sieve.py" "$repo/rtl/ap68040/tb/bin2hex.py" "$observer_root/rtl/ap68040/tb/"
cp "$repo/rtl/wombat_cpu.sv" "$repo/rtl/wombat_bus32.sv" "$repo/rtl/wombat_store_buffer.sv" "$repo/rtl/sdram_beat32.sv" "$repo/rtl/sdram.sv" "$observer_root/rtl/"
cp "$repo/verilator/tb_sdram.sv" "$repo/verilator/altddio_out_stub.v" "$observer_root/verilator/"
cd "$observer_root"
pwd
printf '%s  %s\n' 284ae2e616697b08e45e1ea01fd0eea704235d81b43c1462b0bdff852f107b57 scripts/fixtures/wombat_sieve/tb_wombat_sieve.sv | sha256sum -c -
git apply --check "$repo/scripts/fixtures/operand_overlap/retirement-readiness.patch"
git apply "$repo/scripts/fixtures/operand_overlap/retirement-readiness.patch"
printf '%s  %s\n' 78cf6fa8e0fbae899f8ec6601ad6882c3f484fbb5725c68e55f7bd72fae2ebf6 scripts/fixtures/wombat_sieve/tb_wombat_sieve.sv | sha256sum -c -

accepted_rtl=/tmp/cpu-ea-request-overlap.ZTs0sO/accepted-rtl
both_rtl=/tmp/cpu-ea-request-overlap.ZTs0sO/rtl
resource='/tmp/speedo402-unar/Speedometer 4.02.rsrc'
export VERILATOR=/home/alans/verilator5/bin/verilator
export VASM=/tmp/wombat-vasm/vasmm68k_mot
pwd
printf '%s  %s\n' 16fc1cc1f7f7e4295cbacf6c5449f2aa485d72290f27d75a3af687a2c7c8c79e "$accepted_rtl/ap040_core.v" | sha256sum -c -
sh "$observer_root/scripts/fixtures/wombat_sieve/run.sh" "$resource" "$accepted_rtl" "$observer_root/baseline" 16
pwd
printf '%s  %s\n' 75eb6faa4ab1cf8f6ede2c02cbf4122e02304fa7fb29776c322a70f634054c41 "$both_rtl/ap040_core.v" | sha256sum -c -
sh "$observer_root/scripts/fixtures/wombat_sieve/run.sh" "$resource" "$both_rtl" "$observer_root/both" 16
rg '^(INTEGRATION_COMPLETE|SHARED_GUARD|DBCC_GUARD)' "$observer_root/baseline/offset-16.log" "$observer_root/both/offset-16.log"
```

The driver verifies the immutable resource and extracted 80-byte kernel hashes.
If the preserved complete RTL directories are unavailable, reconstruct them
from the accepted core and the preserved two-caller patch, then verify exactly
the hashes above. Do not silently substitute current active CPU sources.

## Counters and measured interpretation

`SHARED_GUARD` samples before NBA at `S_PIPE_REGS && regs_alu_fire` inside the
measured interval. Its eight bits, from bit 7 to bit 0, are:

| Bit | Value when set |
| --- | --- |
| 7 | `!epf_ready_pc` |
| 6 | `!rd_valid` |
| 5 | `aux_we` |
| 4 | `irq_pend` |
| 3 | `tr_t1 || (tr_t0 && t0_force)` |
| 2 | `epf_pend` |
| 1 | `mem_req` |
| 0 | `mem_ack` |

The low three bits are context, not disqualifiers for resident register
lookahead. `rd_valid` may decode stale queue storage when bit 7 is set; it is
not proof that the acknowledged word itself has a valid descriptor. Neither
this mask nor generic `mem_ack` proves `epf_fwd_pc` or a successful instruction
acknowledgement. A future bypass assessment must count those explicitly.

At retiring PC `0x2042` (MOVE.W D5,D0, next instruction ADD.W D4,D0), the
accepted baseline has `00000111` exactly 14,999 times. The two-caller candidate
has `10000111` exactly 14,999 times. Resident readiness alone changes in this
mask. The normal resident pop and shared descriptor dispatch are consequently
missed, explaining the additional 14,999 S_DECODE cycles. Baseline/candidate
retain 822,926/835,818 cycles, identical request/cache transaction counts, and
pass all integration oracles. Killed fetch acknowledgements rise 1,901 to
16,180; this observer does not fully attribute that separate timing effect.

`DBCC_GUARD` samples taken even-target DBccs. Its bits 7..0 are T1, T0, IRQ,
missing refill window, epf_pend, mem_req, mem_ack, and already-matching stream.
No rows are emitted for this Sieve: it contains Bcc branches and no DBccs.
The earlier proposed DBcc-shortcut explanation was disproved.

Original evidence is in
`/tmp/cpu-ea-request-overlap.ZTs0sO/dbcc-probe/{shared-baseline,shared-both}/offset-16.log`.

## Read-only assessment of a possible next experiment

A retirement-only acknowledged-opcode bypass would target the measured lost
resident opportunity more directly than changing fetch-request scheduling.
Before writing RTL, count how many missed events satisfy `epf_fwd_pc`,
`!i_err`, `!epf_flushed`, and a valid descriptor decoded from the actual
forwarded word. The existing mask does not establish that eligibility.

The smallest initial scope would be `S_PIPE_REGS && regs_alu_fire`, with the
existing register-only next-opcode descriptor and `!aux_we`. Generic
`regs_alu_fire` also covers memory retirement; do not accidentally include
S_MRD or every `fetch_next` caller. A qualifying register producer and register
consumer do not themselves request a data/MMU transfer on the instruction
acknowledgement edge. Existing request ownership can finish normally.

The hazards to resolve before any implementation are:

- Queue pop/fill: `epf_fwd_pc` proves an empty queue, matching current PC,
  instruction context and non-killed instruction completion. Select its
  existing word/longword lane. Append the response through the existing queue
  engine and request exactly one pop through `epf_pop`; the centralized
  count/head/fill/next updates must produce 0 words after a word response or
  1 after a longword response. Do not separately decrement count or lose the
  second word. Flush still wins. All writes remain CE-qualified.
- Opcode/descriptor coherence: `rd_ir` currently reads resident queue storage
  outside S_DECODE. A forwarded opcode must feed both instruction defaults
  and the one existing descriptor; `rd_valid` from stale storage is unusable.
  S_DECODE must keep selecting `ir`. Choose the forward data with qualification
  independent of `rd_valid`, then qualify the decoded descriptor, avoiding a
  combinational loop or a duplicated decoder.
- IRQ/trace/fault: preserve `fetch_next` boundary priority and its registered
  writeback/POST_EXC barrier. No pop or dispatch on IRQ, applicable trace,
  same-edge flush, kill, context mismatch or instruction error. Generic
  `mem_ack` is insufficient. Unqualified/error cases retain their old path;
  this avoids converting a deferred speculative fault into an instruction
  dispatched from faulting data. Exercise simultaneous acknowledgement and
  IRQ/trace, killed response, page boundary, word/longword response and CE gaps.
- Registers: maintain `!aux_we`, stable stack-bank context and existing
  `rf_capture_a/b` predecessor-write forwarding. Same-edge predecessor result
  and CCR updates must settle before the next execution edge. Do not introduce
  an extra operand or architectural register write while selecting the opcode.

Likely logic cost is a qualified 16-bit opcode mux plus control feeding the
shared decoder, with existing PC/queue arithmetic and RF bypass reused. No
new EA adder or speculative data access is needed. This may add an
acknowledgement/data-to-decode timing path and fanout, so small source size is
not proof of negligible ALM/LAB or timing cost. No quantitative area estimate
is justified without synthesis and fit.

Request retiming may use fewer data muxes, but shifts shared-bus ownership,
demand latency, speculative faults and killed-fill timing across all callers
it affects. The observed alignment sensitivity makes a global scheduling
change less locally predictable. Prefer measuring exact forward eligibility
first; keep either future experiment isolated and evaluate all alignments.
No forwarding or request-retiming RTL prototype is included here.
