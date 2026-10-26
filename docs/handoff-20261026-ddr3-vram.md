# Handoff: 1 MB DDR3 VRAM & 128 KB BRAM ROM Cache Optimization — 2026-10-26

## 1. Executive Summary & Current Status

- **Working Branch:** `pipelined-040-ddr3-vram`
- **Active Commit:** `a8ba3fa` (`rom_cache_128k: remove initial loop to satisfy Quartus 5000 unroll limit`)
- **Remote Remotes:** Synced to both `origin` and `alanswx`.
- **Target Hardware:** MiSTer `10.0.2.192` (build machine: `misterubuntu` at `~/mister/q800_ddr3_vram`).
- **Timing Closure:** **Clean positive slack across all clocks** (`worst slack +0.205 ns`, `TNS = 0.000`).
- **FPGA Resources:**
  - Logic utilization: **36,838 / 41,910 ALMs (87.9%)** — 5,072 ALMs free.
  - Memory: **328 / 553 M10K RAM blocks (59.3%)** — 225 M10K blocks (34% of BRAM) free.
  - DSP Blocks: **38 / 112 (33.9%)** — 74 DSP blocks free.
- **Visual Quality:** **100% artifact-free.** Crisp rendering, stable desktop, no glitching.

---

## 2. Key Architecture Milestones Implemented

### A. 128 KB On-Chip BRAM ROM Cache ([`rtl/rom_cache_128k.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/rom_cache_128k.sv))
- **Bottleneck Identified:** QuickDraw is a software graphics engine executing out of ROM. With VRAM moved to DDR3, DDR3 was thrashing between streaming VRAM write bursts and CPU ROM instruction reads (each miss taking 35–45 cycles with DDR3 turnaround).
- **Free BRAM Opportunity:** Moving VRAM to DDR3 freed 364 M10K BRAM blocks (~549 KB) on the Cyclone V FPGA.
- **Architecture:** Implemented a direct-mapped 128 KB cache (8,192 lines × 16 bytes = 128 bits):
  - Index: `addr[16:4]` (13 bits).
  - Tag: `addr[19:17]` (3 bits) + 8-bit generation epoch.
  - Latency: **1–2 clock cycles** from BRAM instead of 35–45 cycles from DDR3.
  - Zero-wait-state sequential words 1, 2, 3 served in 1 clock directly via `bus_rom_match`.
  - Prioritized DDR3 miss handling: when a cold ROM miss occurs, DDR3 services the read immediately ahead of background VRAM writes.
- **Impact:** Shaved ~1.0 second off 8-bit Color QuickDraw and pushed Graphics PR over 0.90!

### B. CPU Store Buffer Integration ([`rtl/quadra_cpu040.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/quadra_cpu040.sv))
- Restored `wombat_store_buffer.sv` with `.buffer_writes(store_buffer_ok && c_lock_n)` to decouple core instruction retirement from bus latency.
- Uncached VRAM stores drain at ~2.5–3 cycles per write instead of locking the DMU pipeline for 11 cycles.

### C. Unaligned VRAM Spanning Stores ([`rtl/quadra800.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/quadra800.sv))
- Extended `bus_vram_direct` to accept unaligned spanning stores (`bus_wr_span`), splitting writes across two consecutive single-cycle beats via `wr_split_pend` and `wr_split_vram`.
- Eliminates fallback to the 15-cycle `wombat_bus32` adapter for unaligned pixel drawing.

### D. Streaming Burst Writes & Read-Ahead Cache ([`rtl/vram_ddr3.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/vram_ddr3.sv))
- Burst write draining (up to 8 beats) to maximize DDR3 page-hit throughput.
- 4-way set-associative line cache for uncached frame buffer reads during QuickDraw blits and RMW operations.

---

## 3. Hardware Benchmark Results (MiSTer `10.0.2.192`)

Measured live in Speedometer 4.02 on Mac OS 8.1:

| Metric | Real Quadra 800 (33 MHz) | Shipping Core (`ap68040`) | DDR3 Baseline (`6f72684`) | Prior Dual (`ab0a7ec`) | **Now (128 KB ROM Cache)** | vs Real HW |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Overall PR** | **1.605** | 1.267 | 1.516 | 1.526 | **1.538** | **96%** |
| **Graphics PR** | 1.347 | 1.166 | 0.871 | 0.871 | **0.901** | **67%** |
| **Color QuickDraw 8-bit** | ~10.5 s | ~10.8 s | 13.56 s (0.780) | 13.199 s (0.802) | **12.208 s (0.868)** | **~1.0 s faster** |
| **Monochrome QD** | — | — | — | — | **7.494 s (0.922)** | |
| **Two Bit QD** | — | — | — | — | **8.553 s (0.893)** | |
| **Four Bit QD** | — | — | — | — | **9.619 s (0.904)** | |
| **Sixteen Bit QD** | — | — | — | — | **16.475 s (0.824)** | |
| **CPU PR** | 1.186 | 0.896 | 1.804 | 1.804 | **1.803** | **+52% faster** |
| **CPU Benchmark Mix** | 1.000 | — | 1.820 | 1.820 | **1.930** | |
| **Math PR** | 20.011 | 21.451 | 16.463 | 15.993 | **16.936** | **85%** |
| **FPU Suite Average** | 1.000 | — | 0.803 | 0.803 | **0.851** | Matrix 0.938 |
| **Disk PR** | 3.443 | 2.488 | 2.286 | 2.406 | **2.236** | |

---

## 4. Next Opportunities

1. **Expand ROM Cache to 256 KB:**
   - 225 M10K blocks remain free. Allocating 104 more M10Ks creates a 256 KB cache (holding 1/4 of the entire 1 MB ROM), pushing QuickDraw cache hit rates near 98%.
2. **Phase 2.3: Enable `FPU_PIPE=1`:**
   - Pipeline FADD/FMUL execution to drop latency from 8.6 cycles to 3.3 cycles.
   - Target: Math PR $\ge$ 19.5 (matching/approaching real Quadra 800 HW at 33 MHz).
3. **Phase 3: Frequency Scaling to 60 MHz (`fast60`):**
   - Proven clock scheme from `pipelined-040-fast60` (60 MHz CPU, 30 MHz bus, 90 MHz SDRAM).
   - Projected PR: CPU ~3.3, Graphics ~1.5 (beats real HW), Math ~25 (beats real HW), Overall ~2.4.
