# Registered cache admission experiment (2026-09-13)

Experimental, not adopted. Active RTL was not changed. No FPGA build or
hardware test was performed for this cache change.

Baseline complete RTL: `/tmp/cache-hit-latency.ZBuCjk/rtl`.
Candidate complete RTL: this directory's `rtl`.
Both use accepted `ap040_core.v` SHA256
`0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
Candidate changes only `rtl/ap68040/rtl/ap040_cache.v`, SHA256
`77882b83f738f711ff16f923688a06031b6b0d86373214fb4bb0d75b040f162b`.
Baseline cache SHA256 is
`55b94aeebca640cb8418eb88c2df0ca6707e7e016a0700f375ae61a6b338599b`.
`cache-early.patch` SHA256 is
`c2e22d2feabee10880629f8fda117f369dc59327c92e6d3fc7dcb66e6f206d8c`.
`git apply --check` against the baseline and an independent apply/hash
roundtrip passed (`/tmp/cache-early-roundtrip.m22ic_j2`). Apply only inside a
new copy of the baseline directory, not the active checkout:

```sh
git apply --check /tmp/cache-early-hit.2goe86/cache-early.patch
git apply /tmp/cache-early-hit.2goe86/cache-early.patch
```

## Measured deterministic opportunity

Real wombat_cpu + MMU + cache + store buffer, deterministic memory/walker
models, no SDRAM timing model. Request issue is the CPU register edge;
consume is the CE-qualified edge sampling acknowledge/error.

| Path | Issue to qualified cache admission | Admission to registered ack | Ack to CPU consume | Total |
| --- | ---: | ---: | ---: | ---: |
| Baseline TC-off/TTR warm ordinary hit | 1 | 1 | 1 | 3 |
| Baseline ATC-hit warm ordinary hit | 2 | 1 | 1 | 4 |
| Candidate eligible ATC-hit | 2 | 0 | 1 | 3 |
| Existing TC-off instruction prediction | 1 | 0 | 1 | 2 |
| Existing translated instruction prediction | 2 | 0 | 1 | 3 |

Phase 2 maps logical $9000 to physical $4000. Seven warm data hits were all
4 clocks at baseline and 3 at candidate. A first ATC walk ending in a cache
hit was 20 versus 19. All eight used data read for this actual request while
translation was pending, not an assumed idle address. Baseline shadow read
data agreed with the later actual response for all eligible ordinary hits.
Across the complete small test, 53 instruction + 8 data hits were eligible;
candidate issued exactly 61 idle completions and finished in 2127 versus
2188 clocks. This is not a workload or Speedometer gain estimate.

TC-off data: six warm hits at 3 clocks, no early eligibility. TTR cacheable:
eight hits at 3 clocks, no early eligibility. Cache-inhibited and D-cache
disabled phases: eight passes each at 5 clocks, no early eligibility. A
three-clock CE pause added exactly three clocks. A snoop forced a refill.
One passed-read bus error took the guest exception handler and RTE-restarted
successfully. This is not exhaustive MMU permission/FC/fault coverage.

## Implementation and invariants

Idle reads reuse the existing four RAM ways and their read port. Index bits
are bank plus address[9:2], entirely within both supported MMU page offsets.
No tag match is trusted until rd_accept supplies a translated, permitted,
cacheable physical request. A registered index/valid record must match both
tag and data outputs; it is not a descriptor or virtual-to-physical cache.

The existing four tag comparators and way mux are shared by choosing live
physical tag only in C_IDLE; all other states keep their captured r_tag.
Response data and acknowledge remain registered. No combinational cache
ack path from the ATC is introduced. The existing predictor keeps priority,
and a new ordinary I-hit seeds its next word using the same read port.

Tag metadata runs on every clock, like the tag RAM; data metadata follows
the CE-gated data read. Reset clears validity. Any port-B invalidate and any
data write invalidate idle data reuse; a concurrent tag write/invalidate or
prior mixed-port tag read forbids early completion. This intentionally
rejects unrelated-row collisions too. CINV, pending CI/store invalidations,
cache disable, misalignment, errors and snoops retain conservative fallback.
Miss/fill/pass state machines and external request interfaces are unchanged.

Estimated RTL addition: 18 metadata flops and compare/control/tag-select
logic, no extra RAM, wide stored data, adder, or CPU decode. Actual area,
routing and timing are unmeasured. The live physical-tag select and MMU
permission-to-registered-ack setup path still need STA; the old long
combinational ack-to-CPU exception path is not restored. Idle RAM reads
increase switching activity. Behavioral RAM tests do not prove M10K
read-during-write behavior; guards must remain even when simulation returns
old data deterministically.

## Commands and evidence

Run from the explicit corresponding directory:

```sh
python3 /tmp/cache-hit-latency.ZBuCjk/run.py
python3 /tmp/cache-early-hit.2goe86/run.py
python3 /tmp/cache-hit-latency.ZBuCjk/summarize.py /tmp/cache-hit-latency.ZBuCjk/run.log
python3 /tmp/cache-hit-latency.ZBuCjk/summarize.py /tmp/cache-early-hit.2goe86/run.log
```

Each runner checks the accepted CPU SHA, builds an isolated Verilator binary,
and bounds the guest to 200000 clocks. `compile.log` and `run.log` are local.
The unchanged cache-snoop test completed with two T12 latency-oracle failures
only (`snoop.log`): its ordinary repeated F000 seed now ties the predictor at
two clocks; returned values and all other checks passed. This is not recorded
as an unmodified all-green gate.

`tb_cache_early.v` preserves the original T1-T13 checks but deliberately
preloads another idle RAM word before T12's ordinary seed. That forces the
ordinary three-clock fallback, retaining the strict predictor-faster test.
T14 adds settled byte/word, stale index, physical tag mismatch and frozen-CE
snoop checks. Run from this directory:

```sh
iverilog -g2012 -I rtl/ap68040/rtl -s tb_ap040_cache_snoop -o early-snoop.vvp tb_cache_early.v rtl/ap68040/rtl/ap040_cache.v rtl/ap68040/rtl/primitives/dpram.v
vvp early-snoop.vvp
```

Require actual exit zero plus `ALL TESTS PASSED` and
`EARLY_ADMISSION_TESTS_COMPLETE`; the legacy bench can exit zero on failure.
This adjusted directed bench passed, actual exit 0 (`early-snoop.log`), bench
SHA256 `18f75284a930e4864b903134eb9fa6e0cd435cb2315dffcad3a5113080799531`.

The complete unmodified AP suite was also run from `rtl/ap68040/tb`:

```sh
VASM=/tmp/wombat-vasm/vasmm68k_mot sh run_tests.sh
```

Actual suite exit was 1, not PASS: only the two documented original T12
latency ties failed. Reset, double_fault, walker_cdc, bus16_gap, bus_timeout,
integer, exceptions, mmu, cache and fpu passed. Logs are in that directory's
`build`. The adjusted directed bench supplements this result; it does not
turn the unmodified suite result into a claimed all-green gate.
Broader architectural gates, actual workload profiles, full-machine behavior
and FPGA implementation are separate acceptance requirements.
