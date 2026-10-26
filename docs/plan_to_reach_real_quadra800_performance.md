# Architecture Plan: Matching & Surpassing Real Quadra 800 Performance

**Date:** October 26, 2026  
**Status:** Approved Architecture Plan  
**Target Platform:** MacQuadra800 on MiSTer FPGA (Cyclone V 5CSEBA6U23I7)  
**Reference Targets:**
- **Real Quadra 800 HW (33 MHz):** Overall PR **1.605**, CPU **1.186**, Graphics **1.347**, Math **20.011**, Disk **3.443**
- **MiSTer Shipping Core (`rtl/ap68040`):** Overall PR **1.267**, CPU **0.896**, Graphics **1.166**, Math **21.451**, Disk **2.488**
- **Current DDR3 VRAM Dual Core (`6f72684`):** Overall PR **1.516**, CPU **1.804**, Graphics **0.871**, Math **16.463**, Disk **2.286**

---

## 1. Executive Summary & Root Cause Analysis

### Is Math Performance Limited by FPU, Memory, or CPU?
**Conclusion: Math performance is 100% CPU & FPU pipeline bound. It is NOT limited by memory.**

#### Concrete Evidence:
1. **Clock Scaling Invariance:** In `docs/dual-speedometer-comparison.md`, when the CPU clock was doubled from 33 MHz to 66 MHz with the memory bus strictly pinned at 33 MHz, the Math PR score scaled from **13.313 to 26.824** (a perfect **2.01x linear speedup**). If Math were memory-bound or stalling on SDRAM, doubling the CPU alone could not double the score.
2. **Working Set Locality:** All Speedometer Math/FPU kernels (Whetstone, Matrix Multiply, FFT) operate on arrays that comfortably fit inside the 68040's 8 KB on-chip data cache in copyback mode (`m4.x.cm == 2'b01`).
3. **Microarchitectural Cycle Breakdown (from `docs/fp-gap-attribution.md`):**
   - **`FMOVEM` Register Stalls:** On function calls and context saves, `fmovem.x` of two registers takes **79 cycles** on the dual core vs **18 cycles** on the shipping core (a **4.4x slowdown**). The dual core's microcode sequencer mechanically steps through all 8 register slots regardless of the register mask.
   - **FP Store Path (`fmove.d fpN, <mem>`):** Takes **11.0 flat cycles** on the dual core vs **7.0–7.5 cycles** on the shipping core. Four extra serialization and uop cycles are consumed passing the operand across the `ap68040_fpif` to DMU interface.
   - **FP Arithmetic Latency:** `FADD/FSUB/FMUL` takes **8.6 cycles** on the unpipelined dual core vs **6.5 cycles** on the shipping core.
   - **Divider Throughput:** The dual core imports a 2-step/clock non-restoring divider (`DIV_STEPS=2`, ~24.6–43 cycles) whereas the shipping core used a 3-step/clock restoring divider (~19.4–31 cycles).

---

### Why Did the Shipping Core Achieve 1.166 Graphics vs the Dual Core's ~0.87?
QuickDraw is a CPU-driven graphics software library. The Graphics benchmark renders lines, rounded rectangles, polygons, and text via 68040 CPU execution.

1. **Uncached VRAM Stores:**
   - **Shipping Core (`rtl/ap68040`):** Posts non-cacheable VRAM stores through a hardware store buffer in **3.0 cycles**.
   - **Dual-Issue Core (`rtl/ap68040_faster`):** Takes **11.2 cycles** through the DMU engine. Even with early writeback retirement (`PA_VRAM_POST=1`), the DMU engine remains locked until the bus transaction completes.
2. **Unaligned VRAM Stores Missing Direct Path:**
   - In [`rtl/quadra800.sv#L710-L725`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/quadra800.sv#L710-L725), direct 1-cycle writes for RAM support unaligned spanning stores (`bus_wr_span`) by splitting them across two consecutive cycles (`wr_split_pend`).
   - However, VRAM direct writes strictly require `!bus_wr_span`. When QuickDraw writes unaligned pixels (very frequent in arbitrary polygon and pattern fills), the write misses the direct path and falls back to the **15-cycle `wombat_bus32` adapter**.
3. **Uncached Framebuffer Reads (RMW Blits):**
   - In QuickDraw `CopyBits` and XOR drawing modes, the CPU reads the destination framebuffer before writing back. Uncached reads take **14.1 cycles** on the dual core vs **5.2 cycles** on the shipping core.

---

## 2. Strategic Roadmap to Reach & Exceed Real Quadra 800 HW

```mermaid
flowchart TD
    subgraph Step 1: Graphics Fast Paths
        A["VRAM Spanning Store (wr_split_pend)"] --> B["Immediate 1-cycle unaligned VRAM writes"]
        C["Pipelined DMU VRAM Release"] --> D["Unlock DMU engine during VRAM store buffer drain"]
    end

    subgraph Step 2: Math & FPU Pipeline
        E["FMOVEM Register Mask Filter"] --> F["Skip unused FP slots (79 clk -> 18 clk)"]
        G["FP Store Handshake Collapse"] --> H["Collapse FPIF->DMU uops (11 clk -> 7 clk)"]
        I["FPU Pipelining (FPU_PIPE=1)"] --> J["FADD/FMUL drops from 8.6 to 6.0 clk"]
    end

    subgraph Step 3: Clock Frequency Scaling
        K["CPU 60 MHz / Bus 30 MHz (fast60)"] --> L["Full Hardware Sweep & Timing Closure"]
    end

    Step 1 --> M["Target: 1.25 - 1.35 Graphics PR @ 33 MHz"]
    Step 2 --> N["Target: 21.0+ Math PR @ 33 MHz"]
    Step 3 --> O["Target: 1.6+ Graphics, 26+ Math, 2.5+ Overall PR"]
```

---

## 3. Detailed Implementation Steps

### Phase 1: Graphics Optimizations (Estimated Gain: +25–35% Graphics PR)

#### 1.1 Extend `wr_split_pend` to VRAM Direct Writes
* **Target File:** [`rtl/quadra800.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/quadra800.sv)
* **Problem:** Unaligned 16-bit or 32-bit stores to VRAM currently fail `!bus_wr_span` in `bus_vram_direct` and incur a 15-cycle penalty through `wombat_bus32`.
* **Fix:** 
  1. Update `bus_vram_direct` condition:
     ```verilog
     wire bus_vram_direct = (DIRECT_WRITES != 0) && (svc == S_IDLE) && !walker_pend && !cpu_berr &&
                            !bus_miss_ack && !bus_line_ack && !bus_adapter_active && !wr_split_pend &&
                            !bus_ack_adapter && bus_req && bus_write &&
                            (!bus_wr_span || (decode(bus_addr[31:2] + 30'd1) == 3'd2)) &&
                            (decode(bus_addr[31:2]) == 3'd2) && mem_vram_wq_room;
     ```
  2. In the `bus_vram_direct` action block, when `bus_wr_span` is asserted, pulse `mem_vram_wp` for the first half and arm `wr_split_pend` for the second half:
     ```verilog
     else if (bus_vram_direct) begin
         mem_vram_wp    <= 1;
         mem_addr       <= bus_addr[31:2];
         mem_be         <= (4'b1111 << (3'd4 - bus_wr_bytes)) >> bus_addr[1:0];
         mem_wdata      <= bus_wr_left >> {bus_addr[1:0], 3'd0};
         if (bus_wr_span) begin
             wr_split_pend <= 1;
             wr_split_addr <= bus_addr[31:2] + 30'd1;
             wr_split_be   <= 4'b1111 << (4'd8 - {1'b0, bus_wr_end});
             wr_split_data <= bus_wr_left << {3'd4 - {1'b0, bus_addr[1:0]}, 3'd0};
             wr_split_vram <= 1; // route second beat to mem_vram_wp
         end
         else begin
             bus_miss_ack   <= 1;
             bus_miss_rdata <= 0;
         end
     end
     ```

#### 1.2 Uncouple DMU Engine Lock on Posted VRAM Stores
* **Target File:** [`rtl/ap68040_faster/rtl/ap68040_dmu.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/ap68040_faster/rtl/ap68040_dmu.sv)
* **Problem:** In line 944, `wb_vram_post` retires at WB, but `e_st` remains occupied waiting for `bus_ack`. Subsequent integer instructions with memory operands stall unnecessarily even though the DDR3 VRAM FIFO absorbs the write.
* **Fix:** When `wb_vram_post` fires, permit non-dependent subsequent loads to check the cache immediately rather than stalling in DC2 (`dc2_slow`).

---

### Phase 2: Math & FPU Performance Recovery (Estimated Gain: +30–50% Math PR)

#### 2.1 Fast-Path Masking for `FMOVEM`
* **Target File:** [`rtl/ap68040_faster/rtl/fpu/ap040_fpu.v`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/ap68040_faster/rtl/fpu/ap040_fpu.v) & microsequencer
* **Problem:** Currently, `fmovem` iterates 8 times through all registers regardless of the register mask. For a typical 2-register push (`FP0-FP1`), it wastes 61 cycles doing null slot transfers.
* **Fix:** Skip unmasked register steps with priority-encoded next-register stepping, dropping 2-register `FMOVEM` from 79 cycles to ~18 cycles.

#### 2.2 Collapse FP Store Interface Latency
* **Target File:** [`rtl/ap68040_faster/rtl/ap68040_fpif.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/ap68040_faster/rtl/ap68040_fpif.sv)
* **Problem:** Passing double-precision FP registers from FPU to DMU requires 4 sequential handshake states (`CHK`, `GET_HI`, `GET_LO`, `END`).
* **Fix:** Forward 64-bit FP registers directly to the DMU store buffer in 1 cycle, dropping FP store cost from 11.0 to 7.0 cycles.

#### 2.3 Evaluate `FPU_PIPE=1` with Area Verification
* **Target File:** [`rtl/quadra_cpu040.sv`](file:///Users/alans/dev2/MacQuadra800_MiSTer/rtl/quadra_cpu040.sv)
* **Action:** Enable `FPU_PIPE=1` (pipelined FADD/FMUL at 3.3 cycles). Verify with Quartus that ALMs remain under the 41,910 device ceiling.

---

### Phase 3: Frequency Scaling to 60 MHz / 66 MHz

Once single-cycle spanning stores and FPU latency are closed at 33 MHz:
1. **Branch `pipelined-040-fast60`:** 
   - CPU: 60 MHz, Memory Bus: 30 MHz, SDRAM: 90 MHz.
   - Initial seed tests reached **57.5 MHz Fmax** (-0.729 ns slack).
   - Registering the critical `ex_u.op` decode comparator cone will achieve full timing closure (+slack).
2. **Performance Projection at 60 MHz:**
   - **CPU PR:** ~**3.3** (vs 1.18 real HW, **2.8x faster**)
   - **Graphics PR:** ~**1.45 – 1.55** (vs 1.35 real HW, **beats real HW**)
   - **Math PR:** ~**24 – 27** (vs 20.0 real HW, **beats real HW**)
   - **Overall PR:** ~**2.4** (vs 1.61 real HW, **1.5x faster**)

---

## 4. Verification & Gate Criteria

| Stage | Benchmark Test | Target Metric | Gate Criteria |
| :--- | :--- | :--- | :--- |
| **Phase 1** | Speedometer 4.02 Color QuickDraw 8-bit | $\le$ 10.5 s | No regression in screen rendering; timing slack $> +0.050$ ns |
| **Phase 1** | Speedometer 4.02 Graphics PR | $\ge$ 1.10 | Must approach shipping core's 1.166 |
| **Phase 2** | Speedometer 4.02 Math PR | $\ge$ 20.0 | Reach or exceed real Quadra 800 HW (20.011) |
| **Phase 2** | Speedometer 4.02 FPU Suite | $\ge$ 0.95 | Eliminate dual core FP deficit |
| **Phase 3** | Full PR Benchmark Suite | $\ge$ 2.40 | Timing closure at 60 MHz across all PLL clock domains |
