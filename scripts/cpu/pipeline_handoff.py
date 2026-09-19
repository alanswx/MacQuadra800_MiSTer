#!/usr/bin/env python3
"""Test opt-in pipeline ownership in the real core, with one shared register file."""
import argparse
from pathlib import Path
import re
import subprocess
from pipeline_prototype import ROOT, RTL, EXP, run, compare


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "scratch/pipeline_p1")
    parser.add_argument("--vasm", default="/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot")
    parser.add_argument("--only-irq", action="store_true")
    parser.add_argument("--force-decode", action="store_true", help="disable sequencer lookahead for full pipeline coverage")
    parser.add_argument("--extended", action="store_true")
    parser.add_argument("--only-reference", action="store_true")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    reference = out / ("prototype_extended" if args.extended else "prototype")
    if not (reference / "oracle.trace").exists():
        subprocess.run(["python3", str(ROOT / "scripts/cpu/pipeline_prototype.py"),
                        "--out", str(reference), *(["--extended"] if args.extended else [])], check=True)
    units = ("ap040_tg68k_compat", "ap040_core", "ap040_bus16_adapter", "ap040_bus_timeout",
             "ap040_regfile", "ap040_alu", "ap040_muldiv", "ap040_mmu", "ap040_cache",
             "ap040_fpu", "ap040_walker_cdc", "primitives/dpram")
    source = [ROOT / "rtl/ap68040/tb/tb_ap040_program.v", EXP / "ap040_pipeline_integer.sv",
              EXP / "handoff_monitor.sv", *(RTL / (u + ".v") for u in units)]
    common = ["iverilog", "-g2012", "-DAP040_EXPERIMENTAL_PIPELINE", "-I", RTL,
              "-s", "tb_ap040_program", "-s", "handoff_monitor"]
    if args.force_decode:
        common.append("-DAP040_PIPELINE_FORCE_DECODE")
    if not args.only_irq:
        run([*common, "-s", "reference_trace", "-o", out / "trace.vvp",
             EXP / "reference_trace.sv", *source], out / "compile_trace.log")
        oracle = (reference / "oracle.trace").read_text().splitlines()
        log = run(["vvp", out / "trace.vvp", f"+prog={reference / 'reference.hex'}", "+phase=0",
                   f"+trace={out / 'handoff.trace'}", f"+count={len(oracle)}", f"+registers={16 if args.extended else 8}"], out / "trace.log")
        compare(out / "handoff.trace", oracle)
        match = re.search(r"HANDOFF entries=(\d+) commits=(\d+) paused=(\d+) cancelled=(\d+)", log)
        assert "ALL TESTS PASSED" in log and match and int(match[1]) > 0 and int(match[1]) == int(match[2]), log[-2000:]
        if args.force_decode:
            assert int(match[1]) == len(oracle), log[-2000:]
        print(f"PASS {len(oracle)} shared-state snapshots; {match[0]}", flush=True)
        if args.only_reference:
            return
        run([*common, "-o", out / "program.vvp", *source], out / "compile_program.log")
        tests = ("integer", "exceptions", "mmu", "bitfield_mmu", "bitfield_cache", "moves_fc",
                 "movem_restart", "atcprobe", "fpu_frames", "fpu_resume", "cache", "fpu",
                 "branch_early", "loops_irq")
        for name in tests:
            asm = ROOT / f"rtl/ap68040/tb/asm/t_{name}.s"
            run([args.vasm, "-Fbin", "-m68040", "-no-opt", "-o", out / f"{name}.bin", asm],
                out / f"{name}.asm.log", cwd=asm.parent.parent)
            run(["python3", ROOT / "rtl/ap68040/tb/bin2hex.py", out / f"{name}.bin",
                 out / f"{name}.hex"], out / f"{name}.hex.log")
            log = run(["vvp", out / "program.vvp", f"+prog={out / (name + '.hex')}"], out / f"{name}.log")
            assert "ALL TESTS PASSED" in log and "FAIL:" not in log, f"{name}: {log[-2000:]}"
            match = re.search(r"HANDOFF entries=(\d+) commits=(\d+) paused=(\d+) cancelled=(\d+)", log)
            assert match and int(match[1]) > 0 and int(match[1]) == int(match[2]) + int(match[4]), log[-1000:]
            print(f"PASS {name}: {match[0]}", flush=True)
    run([*common, "-s", "irq_overlap_monitor", "-o", out / "irq_overlap.vvp",
         EXP / "irq_overlap_monitor.sv", *source], out / "compile_irq_overlap.log")
    run([args.vasm, "-Fbin", "-m68040", "-no-opt", "-o", out / "irq_overlap.bin",
         EXP / "irq_overlap.s"], out / "irq_overlap.asm.log")
    run(["python3", ROOT / "rtl/ap68040/tb/bin2hex.py", out / "irq_overlap.bin",
         out / "irq_overlap.hex"], out / "irq_overlap.hex.log")
    log = run(["vvp", out / "irq_overlap.vvp", f"+prog={out / 'irq_overlap.hex'}"],
              out / "irq_overlap.log")
    match = re.search(r"IRQ OVERLAP injections=(\d+) killed=(\d+)", log)
    assert "ALL TESTS PASSED" in log and match and int(match[1]) >= 2 and int(match[2]) >= 2, log[-2000:]
    print(f"PASS precise interrupt and replay: {match[0]}", flush=True)
    print(f"PASS real-core P1 ownership integration; artifacts: {out}")


if __name__ == "__main__":
    main()
