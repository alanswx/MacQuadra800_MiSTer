#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build-index
"${VASM:-vasmm68k_mot}" -Fbin -m68040 -no-opt -o build-index/t_index_stage.bin asm/t_index_stage.s
python3 bin2hex.py build-index/t_index_stage.bin build-index/t_index_stage.hex
rtl=../rtl
iverilog -g2012 -I "$rtl" -s tb_ap040_program -s index_pending_probe \
 -o build-index/tb.vvp tb_ap040_program.v index_pending_probe.sv \
 "$rtl/ap040_tg68k_compat.v" "$rtl/ap040_core.v" \
 "$rtl/ap040_bus16_adapter.v" "$rtl/ap040_bus_timeout.v" \
 "$rtl/ap040_regfile.v" "$rtl/ap040_alu.v" "$rtl/ap040_muldiv.v" \
 "$rtl/ap040_mmu.v" "$rtl/ap040_cache.v" "$rtl/ap040_fpu.v" \
 "$rtl/ap040_walker_cdc.v" "$rtl/primitives/dpram.v"
vvp build-index/tb.vvp +prog=build-index/t_index_stage.hex >build-index/ordinary.log 2>&1
grep 'ALL TESTS PASSED' build-index/ordinary.log
vvp build-index/tb.vvp +prog=build-index/t_index_stage.hex +index_pending >build-index/pending.log 2>&1
grep 'ALL TESTS PASSED' build-index/pending.log
grep 'INDEX_PENDING_PASS kind=1' build-index/pending.log
grep 'INDEX_PENDING_PASS kind=2' build-index/pending.log
if grep -E 'FAIL|MISSING|ERROR|FATAL' build-index/ordinary.log build-index/pending.log; then exit 1; fi
