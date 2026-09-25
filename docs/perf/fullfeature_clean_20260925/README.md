# Full-feature, timing-clean build: hardware validation (2026-09-25)

Build: commit `a0b3072` (recipe), RBF sha256 `ce26df46c0c7d7db0ef2d1088809f20adb2be92a3e8ea8eef9cc991d474e238e`,
md5 `46b85dccbacd8c432fcd372b9d20ecaf`, seed 21, Quartus 17.0.2.  Refitting the committed
source reproduced the RBF bit for bit (`scratch/fitF1_speed` and
`scratch/tc_g_fullfeature_clean_fit_20260925`).  Compact reports are in `build/`.

## Timing (slow 1100 mV 100 °C model)

| clock | setup | hold |
|---|---|---|
| CPU 33 MHz (`general[0]`) | **+0.007 ns** | positive |
| SDRAM 99 MHz (`general[1]`) | **+0.082 ns** | positive |
| HDMI | **+0.044 ns** | positive |
| every other clock | positive | minimum hold +0.219 ns |

Recovery and removal positive; SDRAM crossings sys->ram +0.469, ram->sys
+0.519 ns.  38,329 / 41,910 ALMs (91 %), 509 / 553 M10K.

## Hardware (MiSTer 10.3.89.233, Main `MiSTer.bak_pre_fujinet` md5 d5b50fc4, 32 MB, disposable QuadSquad8 copy)

| check | result | evidence |
|---|---|---|
| Boot to Finder, keyboard, mouse | pass | `run*_complete.png`, `cd_data_boot.png` |
| Speedometer 4.02 Benchmark Mix, 5 runs | **1.661, 1.670, 1.674, 1.666, 1.676; median 1.670** | `run{1..5}_complete.png`, `run{1..5}_table.png`, `results.csv` |
| Ethernet: 1,000 x 1,400-byte pings | pass, 0 % loss, rtt 3.2-6.0 ms | `ethernet_ping1000.log` |
| Ethernet: FTP round trip | **not run** this time | |
| CD-ROM data: HFS ISO in slot 4 | pass: "Q800 Data Test" mounts, README opens in SimpleText with the fixture's text | `cd_data_boot.png`, `cd_data_readme.png` |
| CD audio transport (ToneTest) | pass: Play advanced 35 s in 35 s of wall clock, Pause held for 30 s, Resume advanced 22 s in ~22 s, Stop returned to Track 01 00:00; no "drive not responding" dialog | `cd_audio_player1.png`, `cd_counters.png`, `cd_resume_stop.png`, `cd_stop.png` |
| Normal shutdown (Special -> Shut Down) | pass, four times | `shutdown_after.png`, `final_safe.png` |
| Audible CD output, OSD menu | **not checked** (need a person at the display) | |
| A/UX 3.1 | **not checked** (no image on this box) | |

Slot 4 was restored to its original bytes (sha256 885049f1...) afterwards.

Per-test medians against the 1.828 interim build (`15a1449`, pipeline in,
timing −2.4 ns): Whetstones 1784 vs ~1760-1780, Dhrystones 19,054, Queens
0.446 s, Int. Matrix 0.565 s, Sieve 1.155 s.  The Mix is 8.6 % lower,
consistent with removing the second integer pipeline (the kernel fixtures
predicted 5-28 % on the integer tests and nothing on Whetstone).
