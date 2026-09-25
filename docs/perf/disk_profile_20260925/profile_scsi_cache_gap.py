#!/usr/bin/env python3
"""Generate and run a scratch-only scsi_cache sequential-write gap diagnostic."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BASE_TB = ROOT / "verilator/tb_scsi_cache.sv"
RTL = ROOT / "rtl/scsi_cache.sv"
DEFAULT_OUT = ROOT / "scratch/disk_cache_gap_profile_20260925"

CUSTOM_INITIAL = r'''integer k, r0, m0, rd0, seed, n, lba, s, tag, t3a, t3b;

// Each case writes eight consecutive sectors and adds the stated idle gap after
// each completed request. At 30 ns/cycle: 333/3,333/6,667/33,333 cycles are
// approximately 10/100/200/1,000 us. Backend response delay is 133,333 cycles
// (4 ms), then the model streams the requested sector data.
task gap_profile(input integer id, input integer gap_cycles);
  integer timeout_cycles, base_writes;
  begin
    scenario_id = id;
    prof_single = 0; prof_group8 = 0; prof_other = 0;
    base_writes = dev_writes;
    $display("SCENARIO_BEGIN id=%0d gap_cycles=%0d nominal_gap_ns=%0d backend_latency_cycles=%0d", id, gap_cycles, gap_cycles*30, dev_lat);
    for (k = 0; k < 8; k = k + 1) begin
      ewrite(0, k, id*16 + k);
      if (k != 7) repeat (gap_cycles) @(negedge clk);
    end
    timeout_cycles = 0;
    while ((dut.dirty[0] != 0 || dut.cst != 0 || d_state != 0) && timeout_cycles < 4000000) begin
      @(negedge clk); timeout_cycles = timeout_cycles + 1;
    end
    if (timeout_cycles >= 4000000) $fatal(1, "SCENARIO_TIMEOUT id=%0d dirty=%h cst=%0d d_state=%0d", id, dut.dirty[0], dut.cst, d_state);
    if (id <= 2) begin
      if ((dev_writes-base_writes) != 1 || prof_single != 0 || prof_group8 != 1 || prof_other != 0)
        $fatal(1, "unexpected grouped transaction counts id=%0d total=%0d single=%0d group8=%0d other=%0d", id, dev_writes-base_writes, prof_single, prof_group8, prof_other);
    end else begin
      if ((dev_writes-base_writes) != 8 || prof_single != 8 || prof_group8 != 0 || prof_other != 0)
        $fatal(1, "unexpected single transaction counts id=%0d total=%0d single=%0d group8=%0d other=%0d", id, dev_writes-base_writes, prof_single, prof_group8, prof_other);
    end
    for (k = 0; k < 8; k = k + 1) dcheck(0, k, id*16 + k);
    if (fails != 0) $fatal(1, "data check failed scenario=%0d failures=%0d", id, fails);
    $display("SCENARIO_END id=%0d transactions=%0d singles=%0d groups8=%0d other=%0d timeout_cycles=%0d", id, dev_writes-base_writes, prof_single, prof_group8, prof_other, timeout_cycles);
    repeat (20) @(negedge clk);
  end
endtask

initial begin
  repeat (5) @(negedge clk);
  nreset = 1;
  mount(0, 64'd128*512);
  mount(1, 64'd128*512);
  mount(2, 64'd128*512);
  $display("PROFILE_CONFIG clk_period_ns=30 FLUSH_IDLE_cycles=%0d FLUSH_IDLE_ns=%0d backend_cycles=%0d backend_delay_ns=%0d sectors_per_group=8", dut.FLUSH_IDLE, dut.FLUSH_IDLE*30, dev_lat, dev_lat*30);
  gap_profile(1, 333);
  gap_profile(2, 3333);
  gap_profile(3, 6667);
  gap_profile(4, 33333);
  $display("PROFILE_DONE failures=%0d", fails);
  $finish;
end
'''

def generate() -> str:
    source = BASE_TB.read_text()
    replacements = [
        ("always #5 clk = ~clk;", "always #15 clk = ~clk; // match core flush-idle calibration at 33.333 MHz"),
        ("integer dev_lat = 40;", "integer dev_lat = 133333; // 3.99999 ms at 30 ns/cycle"),
        ("integer dev_reads = 0, dev_writes = 0, pt_reads = 0;",
         "integer dev_reads = 0, dev_writes = 0, pt_reads = 0;\n"
         "integer prof_single = 0, prof_group8 = 0, prof_other = 0, scenario_id = 0;\n"
         "integer cycle_counter = 0;\nreg [2:0] e_wr_d = 0;\n"
         "always @(posedge clk) begin\n"
         "  cycle_counter <= cycle_counter + 1;\n"
         "  if ((|e_wr) && !(|e_wr_d)) $display(\"ENGINE_WRITE_ACCEPT scenario=%0d cycle=%0d time_ns=%0t\", scenario_id, cycle_counter, $time);\n"
         "  e_wr_d <= e_wr;\nend"),
    ]
    for old, new in replacements:
        if old not in source:
            raise RuntimeError(f"cannot apply scratch transformation; missing: {old!r}")
        source = source.replace(old, new, 1)

    old = """\t\t\td_state <= (p_rd != 0) ? 1 : 3;
\t\t\tif (p_rd != 0 && p_lba >= 32'h40000000) pt_reads <= pt_reads + 1;"""
    new = """\t\t\td_state <= (p_rd != 0) ? 1 : 3;
\t\t\tif (p_wr != 0) begin
\t\t\t\tif (p_blk_cnt == 0) prof_single <= prof_single + 1;
\t\t\t\telse if (p_blk_cnt == 7) prof_group8 <= prof_group8 + 1;
\t\t\t\telse prof_other <= prof_other + 1;
\t\t\t\t$display("BACKEND_WRITE scenario=%0d time_ns=%0t lba=%0d blocks=%0d", scenario_id, $time, p_lba, p_blk_cnt+1);
\t\t\tend
\t\t\tif (p_rd != 0 && p_lba >= 32'h40000000) pt_reads <= pt_reads + 1;"""
    if old not in source:
        raise RuntimeError("cannot instrument platform write request in base testbench")
    source = source.replace(old, new, 1)

    start = source.index("integer k, r0, m0, rd0, seed, n, lba, s, tag, t3a, t3b;\ninitial begin")
    end = source.index("\ninitial begin\n\t#400_000_000;", start)
    return source[:start] + CUSTOM_INITIAL + source[end:]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT,
                        help="scratch output directory (default: %(default)s)")
    parser.add_argument("--emit-only", action="store_true",
                        help="write generated bench but do not compile or simulate")
    args = parser.parse_args()
    iv = shutil.which("iverilog")
    if not iv and not args.emit_only:
        parser.error("iverilog is required to run; use --emit-only to just generate scratch HDL")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    bench = args.out_dir / "tb_scsi_cache_gap.sv"
    bench.write_text(generate())
    print(f"generated scratch bench: {bench}")
    if args.emit_only:
        return 0
    exe = args.out_dir / "tb_gap.vvp"
    command = [iv, "-g2012", "-DSIMULATION=1", "-DVERILATOR=1", f"-I{ROOT / 'rtl'}",
               "-s", "tb_scsi_cache", "-o", str(exe), str(bench), str(RTL)]
    subprocess.run(command, cwd=ROOT, check=True)
    result = subprocess.run([shutil.which("vvp") or "vvp", str(exe)], cwd=ROOT,
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log = args.out_dir / "results.log"
    log.write_text(result.stdout)
    print(result.stdout, end="")
    print(f"raw simulation log: {log}")
    if result.returncode:
        return result.returncode
    if ("PROFILE_DONE failures=0" not in result.stdout or
            result.stdout.count("SCENARIO_END id=") != 4 or
            "FATAL:" in result.stdout):
        raise RuntimeError("simulation ended without all four checked scenarios")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

