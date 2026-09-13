# Retirement forwarding experiment, 2026-09-13

Baseline is accepted source-only EA overlap, CPU SHA256
`0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
This is not the older indexed-stage-only baseline `16fc1cc1...`.

Selected experimental combination CPU SHA256:
`21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`.
Complete RTL: `/tmp/cpu-retirement-forward.NKvcGq/combined-rtl`.
It includes destination extension-request setup overlap AND the retirement
opcode mux. It does not include the separate destination-selection experiment.
Neither the selected combination nor the forwarding-only variant has FPGA
timing or hardware acceptance from this experiment.

## Frozen patches and alternatives

All CPU patches are relative to the accepted `0c3a81bd...` baseline and target
`rtl/ap68040/rtl/ap040_core.v` in a copied top-level repository layout.

| Artifact | SHA256 |
| --- | --- |
| `cpu-combined-experimental-20260913.patch` | `6945247f1a4de8cf0062bd33b9ed54f0d9f8dd376a1a07f3ce578ebfc8bb2d98` |
| `cpu-forward-only-experimental-20260913.patch` | `c0212ce44f01892bbcd51845c5c71ac5f16e7a81988a35616616898e686ef2fb` |
| `sieve-forward-observer.patch` | `d34578ff2f64ec9c6c52baf0ba4b1c7c7fce4d36b06003b9bf7fb91df9d03a08` |
| `tb_retirement_forward.sv` | `ab7bd4e9c2341b46f40273cade9010fc8bbd61ea4e351baa67a44a7fb3eaf8ba` |

The combined CPU patch and observer patch passed `git apply --check` and
isolated roundtrip application, reproducing their exact source hashes.
The forwarding-only CPU is
`9d80fe4e66ddaf5dae144c7aa450472d1a8b8fc16b7fcfee51fd650cbd35d063`.
It improves only four integration placements by 0.14-0.19%, leaves the
original-placement Sieve unchanged, and is not selected independently.
Its immutable first-100 corpus matches all 1,900 field groups at the unchanged
34,740,491 cycles; evidence `/tmp/cpu-corpus100-gate.e1jvYd`.

The separate, unselected destination-selection CPU is
`d9fe845df458275917023991dede6a38ffeecbc48bd4ab71e3183c9da11467f0`,
in `/tmp/cpu-destination-select.sWLPJd/rtl`. It bypasses S_PIPE_DST while retaining
S_EA_DISP and does not contain the forwarding mux. It regresses offset 16 by
21,088 cycles; its focused nine-case/98-check capture oracle passes against
both baseline and candidate. This alternative is not part of the combined patch.

## RTL scope and invariants

The new response selector is limited to `S_PIPE_REGS && regs_alu_fire`, with
`!aux_we`, `epf_fwd_pc` and `!i_err`. It feeds the actual returning opcode into
the existing descriptor; selector eligibility does not depend on `rd_valid`,
avoiding a combinational decode loop. S_DECODE retains priority for `ir`.
`fetch_next` accepts the selected response only when its descriptor is a
supported register operation and its existing IRQ/trace/flush boundary passes.
The same actual word supplies `ir`, per-instruction defaults and the descriptor.

The existing queue engine still appends the complete response. Exactly one
shared `epf_pop` consumes the opcode, preserving a longword's second word and
ring wrap. There is no extra queue writer, EA adder, decoder or speculative
data request. The current predecessor register/CCR forwarding remains in use.
All other producer states and non-register next opcodes use the old path.
The additional acknowledgement/data-to-descriptor path must be checked by
synthesis/fit; passing simulation does not establish its timing or area cost.

## Focused tests

```
sh /tmp/cpu-retirement-forward.NKvcGq/export/fixtures/retirement_forward/run.sh /tmp/cpu-retirement-forward.NKvcGq/baseline-rtl NEW_BASELINE_OUTPUT baseline
sh /tmp/cpu-retirement-forward.NKvcGq/export/fixtures/retirement_forward/run.sh /tmp/cpu-retirement-forward.NKvcGq/combined-rtl NEW_CANDIDATE_OUTPUT candidate
```

The runner refuses an existing output directory. Seventeen controlled boundary
cases cover actual versus stale opcode selection; word and longword queue
append/pop, ring wrap and PC page crossing; predecessor RAW, carry and sticky
zero through an executed ADD.L/ADDX.L chain; aux-write fallback; non-register
opcodes and other callers; killed/context/PC-mismatched responses; deferred
instruction fault and acknowledge-plus-error fallback; IRQ, T1, applicable T0,
combined IRQ/trace, same-cycle flush, and CE gaps.

The bench deliberately seeds decoded internal state to isolate boundary
conditions. Its ADDX chain checks architectural results, but its fault guard
cases do not constitute a complete exception-frame/RTE restart test. The
separate operand fixture covers five extension fault/RTE restart programs.

Focused baseline: 17 cases, 67 checks, PASS.
Focused combined: 17 cases, 73 checks, PASS.
Logs: `/tmp/cpu-retirement-forward.NKvcGq/focused-baseline-final/test.log` and
`/tmp/cpu-retirement-forward.NKvcGq/combined-focused/test.log`.
Combined existing operand fixture passed in `candidate` mode, including all
three bus phases and pending RF/ISP probes:
`/tmp/cpu-retirement-forward.NKvcGq/combined-existing-directed/tb/build`.

## Read-only forwarding observer

Apply `sieve-forward-observer.patch` only to a copied
`scripts/fixtures/wombat_sieve/tb_wombat_sieve.sv`, base SHA256
`284ae2e616697b08e45e1ea01fd0eea704235d81b43c1462b0bdff852f107b57`.
Patched observer SHA256:
`4f029c444b3fc1e5d3e220439a738f52922a5e953c7b62630824f6904f84f583`.
The fixture and reproduction layout are those documented in the existing
operand_overlap/RETIREMENT_READINESS.md; use this new patch and hash instead.
An already isolated complete copy is at
`/tmp/cpu-retirement-forward.NKvcGq/integration`.

Example all-placement reproduction (one owner per fixture; fresh output):

```
cd /home/alans/mister/MacQuadra800_MiSTer
pwd
printf '%s  %s\n' 21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700 /tmp/cpu-retirement-forward.NKvcGq/combined-rtl/ap040_core.v | sha256sum -c -
VERILATOR=/home/alans/verilator5/bin/verilator VASM=/tmp/wombat-vasm/vasmm68k_mot sh /tmp/cpu-retirement-forward.NKvcGq/integration/tb/run_integration.sh '/tmp/speedo402-unar/Speedometer 4.02.rsrc' /tmp/cpu-retirement-forward.NKvcGq/combined-rtl NEW_OUTPUT 0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30
```

This is unchanged 80-byte Sieve, first outer pass, real CPU/store-buffer/SDRAM
integration, not a full-100 or hardware measurement. `FWD_WORD` records actual
response and stale storage separately. `FWD_ELIGIBILITY` samples register-ALU
retirement, counts absent resident words, `epf_fwd_pc`, fault/aux/IRQ/trace/flush
disqualifiers, actual returning-opcode descriptor validity and final eligibility.
A simulation-only validity classifier checks itself against the RTL descriptor
on every observed `rd_ir`. This is an observation aid, not a second RTL decoder.
`SHARED_GUARD` bits 7..0 remain: !ready, !descriptor, aux, IRQ, applicable trace,
pending fetch, request, acknowledge. The last three bits are context rather
than resident-dispatch disqualifiers. There are no DBcc instructions in Sieve.

Actual response proof on prior two-caller overlap `75eb6faa...` at offset 16:
all 14,999 retiring-PC-0x2042 events return opcode D044 with `epf_fwd_pc`, valid
actual descriptor and no disqualifying guards. The stale queue word is not
usable. Combining the bypass recovers this opportunity. Forward-only at some
other placements merely removes decode cycles while adding equal later FETCH
waits, so eligible event counts are not end-to-end savings.

## Selected combination integration results

All sixteen runs completed with actual exit zero and array, guard, store-drain
and SDRAM protocol oracles passing. Baseline/combined evidence:
`/tmp/cpu-retirement-forward.NKvcGq/{profile-baseline,profile-combined}`.

| Offset | Accepted source-only | Combined | Saved cycles |
| ---: | ---: | ---: | ---: |
| 0 | 866676 | 844720 | 21956 |
| 2 | 833738 | 810532 | 23206 |
| 4 | 824809 | 800449 | 24360 |
| 6 | 827427 | 804253 | 23174 |
| 8 | 822924 | 806730 | 16194 |
| 10 | 815446 | 816817 | -1371 |
| 12 | 836220 | 804845 | 31375 |
| 14 | 829212 | 793181 | 36031 |
| 16 | 814729 | 793703 | 21026 |
| 18 | 863211 | 848207 | 15004 |
| 20 | 891041 | 858028 | 33013 |
| 22 | 856901 | 833726 | 23175 |
| 24 | 889154 | 864303 | 24851 |
| 26 | 869491 | 846304 | 23187 |
| 28 | 888157 | 864983 | 23174 |
| 30 | 866872 | 844203 | 22669 |

Offset 0 saves 2.533%, offset 16 saves 2.581%. Offset 10 regresses 0.168%:
23,190 removed S_EA_DISP cycles are outweighed by 24,573 added S_FETCH cycles,
partly offset by 12 fewer S_MRD cycles. Killed acknowledgements rise exactly
8,191 (1,180 to 9,371); all request/cache/data/store transaction counts are
unchanged. Other state counts are unchanged. This proves a scheduling cost;
the exact per-PC killed-fetch sequence has not been separately attributed.

Combined all-eleven, immutable corpus and original full-100 gates are assigned
to the routine test agent. Their completion/results must be recorded separately;
this README does not imply they or any full-machine/Quartus/hardware gate passed.
