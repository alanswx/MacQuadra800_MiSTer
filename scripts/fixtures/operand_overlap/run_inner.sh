#!/bin/sh
set -eu
cd "$(dirname "$0")"
kind=$1
extra=
if [ "$kind" = candidate ]; then extra=+overlap_expect; fi
if [ "$kind" = source ]; then extra=+overlap_source; fi
if [ "$kind" = destination ]; then extra=+overlap_destination; fi
mkdir build
for name in t_index_stage t_ea_fault; do
 "${VASM:-vasmm68k_mot}" -Fbin -m68040 -no-opt -o "build/$name.bin" "asm/$name.s"
 python3 bin2hex.py "build/$name.bin" "build/$name.hex"
done
rtl=../rtl
iverilog -g2012 -I "$rtl" -s tb_ap040_program -s index_pending_probe -s ea_overlap_probe \
 -o build/tb.vvp tb_ap040_program.v index_pending_probe.sv ea_overlap_probe.sv \
 "$rtl/ap040_tg68k_compat.v" "$rtl/ap040_core.v" \
 "$rtl/ap040_bus16_adapter.v" "$rtl/ap040_bus_timeout.v" \
 "$rtl/ap040_regfile.v" "$rtl/ap040_alu.v" "$rtl/ap040_muldiv.v" \
 "$rtl/ap040_mmu.v" "$rtl/ap040_cache.v" "$rtl/ap040_fpu.v" \
 "$rtl/ap040_walker_cdc.v" "$rtl/primitives/dpram.v"
for name in t_index_stage t_ea_fault; do
 vvp build/tb.vvp "+prog=build/$name.hex" $extra +exctrace >"build/$name.log" 2>&1
 grep 'ALL TESTS PASSED' "build/$name.log"
 grep 'EA_OVERLAP_COVERAGE' "build/$name.log"
done
vvp build/tb.vvp +prog=build/t_index_stage.hex $extra +index_pending >build/pending.log 2>&1
grep 'ALL TESTS PASSED' build/pending.log
grep 'INDEX_PENDING_PASS kind=1' build/pending.log
grep 'INDEX_PENDING_PASS kind=2' build/pending.log
if grep -E 'FAIL|MISSING|ERROR|FATAL' build/*.log; then exit 1; fi
