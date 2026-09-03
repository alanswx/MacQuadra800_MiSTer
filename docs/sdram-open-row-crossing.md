# The `open_row` clock crossing — a placement-dependent memory fault

**Symptom (2026-09-02, reported by the user):** on the CLUT-fix build
(`648b6653`) Speedometer 4.02's Benchmark Mix returned **Queens = −17,482 s**
and Bubble Sort 2.503 s (normally 1.574 s and 2.75 s), on the app's first run
after a fresh boot. Every other test was exact. 26 further runs on the same
bitstream, including a first-run-after-launch, were clean, so the fault is
rare and tied to conditions this harness reaches only occasionally.

**What TimeQuest showed** (`scratch/trim/sta_ram_setup_full.txt`, reports
regenerated from a bit-identical rebuild): the worst path in the 99 MHz
SDRAM domain, in every seed-19 fit, is

```
launch  clk_sys (33 MHz)  ->  M10K open_row_rtl_0 (port B address/WE register)
        -> open_row[req_bank_idx] == req_row  ->  sdram|command[2]
latch   clk_ram (99 MHz)
setup relationship 10.101 ns, clock skew -1.555 ns, data 8.04 ns
slack: +0.916 ns (release fit)  ->  +0.344 ns (CLUT-fix fit)
```

`open_row` is Alan's per-{rank,bank} open-page table in `rtl/sdram.sv`,
declared `reg [12:0] open_row [0:7]` and read combinationally every clk_ram
cycle to decide page hit vs. activate. Quartus inferred it as an **M10K in
simple dual-port mode** and, because the read index comes straight from
`sdram_beat32`'s clk_sys request register `r_addr`, it **retimed that
register into the RAM's address port**. The result on silicon is a
dual-clock RAM: the read port is clocked at 33 MHz, the write port at
99 MHz, with `READ_DURING_WRITE_MODE_MIXED_PORTS = DONT_CARE`. That is not
the register array the RTL describes and `verilator/tb_sdram.sv` verifies;
its output then reached the SDRAM command lines through the longest
cross-domain path in the design, whose margin depends entirely on where the
fitter put things and on real PLL output skew that `derive_pll_clocks` does
not model. Alan's qsf history calls this exact path "the known
seed-sensitive open_row → command[0] crossing".

The DAFB CLUT rewrite (`3047610`) touches nothing on this path. It freed
2.5k ALMs, the fitter re-placed the whole design, and the margin on this
crossing dropped from 0.916 to 0.344 ns. The CLUT change exposed the
defect; it did not create it.

**Fix** (`rtl/sdram.sv`, `rtl/sdram_beat32.sv`):

1. `open_row`, `bank_age` and `row_open` carry `(* ramstyle = "logic" *)`,
   so they stay flops read combinationally, as written. No M10K, no
   retiming, no mixed-port semantics.
2. `sdram_beat32` re-registers the request fields on clk_ram
   (`a_ram/d_ram/be_ram/we_ram`) in the cycle it takes the request; the
   controller and the clk_ram-side burst bookkeeping consume those copies.
   `r_addr` & co. are held for the whole beat, so this costs nothing and
   turns every clk_sys → clk_ram data crossing into a plain
   register-to-register hop.

**Result:** `tb_sdram` 45/45 (0 protocol errors), `tb_memory_path` and
`_registered_first_miss` 0 failures, numbers unchanged. Fit at seed 19:
33,160 ALMs, timing met at **+0.176 ns** worst (HDMI PLL hold), clk_ram
setup **+0.427 ns** and now an ordinary single-clock path (`a_ram[23]` →
`command[0]`); the crossings themselves sit at +2.43 ns (`req_tgl` →
`req_handoff`) and ≥ +5.1 ns (`r_addr` → `a_ram`). No `open_row` altsyncram
in the map report. Hardware: Mac OS 8.1 boots clean; the first
Benchmark Mix after launch after boot (the failing condition) reads
Queens 1.574 s, Bubble Sort 2.754 s.

**Still unproven:** because the fault never reproduced in my hands, the fix
is argued from the netlist, not demonstrated on a reproducer. The user's own
run on this build is the confirmation that matters.
