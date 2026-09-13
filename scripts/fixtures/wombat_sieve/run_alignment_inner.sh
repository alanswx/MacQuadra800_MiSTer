#!/bin/sh
# Partial one-pass diagnostic, all 16 word offsets within a 32-byte sector.
# Usage: sh run_alignment.sh RESOURCE COMPLETE_RTL_DIR OUTPUT_DIR
set -eu
cd "$(dirname "$0")"
resource=$1
rtl=$(realpath "$2")
output=$(realpath -m "$3")
mkdir -p build "$output/images"
python3 prepare_exact_sieve.py "$resource" build/exact_sieve.bin
sha256sum "$rtl/ap040_core.v" build/exact_sieve.bin
"${VERILATOR:-verilator}" --binary --timing -Wno-fatal -j "${JOBS:-4}" \
  --top-module tb_ap040_program --Mdir "$output/obj" \
  -DAP040_EXACT_SIEVE_MONITOR -DAP040_TB_CACHE=1 -I"$rtl" \
  tb_ap040_program.v exact_sieve_monitor.sv \
  "$rtl/ap040_tg68k_compat.v" "$rtl/ap040_core.v" \
  "$rtl/ap040_bus16_adapter.v" "$rtl/ap040_bus_timeout.v" \
  "$rtl/ap040_regfile.v" "$rtl/ap040_alu.v" "$rtl/ap040_muldiv.v" \
  "$rtl/ap040_mmu.v" "$rtl/ap040_cache.v" "$rtl/ap040_fpu.v" \
  "$rtl/ap040_walker_cdc.v" "$rtl/primitives/dpram.v" \
  >"$output/compile.log" 2>&1
for offset in 0 2 4 6 8 10 12 14 16 18 20 22 24 26 28 30; do
  base=$((8192+offset))
  base_hex=$(printf '%x' "$base")
  "${VASM:-vasmm68k_mot}" -Fbin -m68040 -no-opt -DKERNEL_BASE="$base" \
    -o "$output/images/sieve-$offset.bin" asm/bench_exact_sieve.s >"$output/images/asm-$offset.log"
  python3 bin2hex.py "$output/images/sieve-$offset.bin" "$output/images/sieve-$offset.hex"
  python3 - "$output/images/sieve-$offset.bin" "$base" <<'PY'
from pathlib import Path
import sys
image=Path(sys.argv[1]).read_bytes(); base=int(sys.argv[2])
assert image[base:base+80] == Path('build/exact_sieve.bin').read_bytes()
assert image[base+80:base+84] == bytes.fromhex('4e714e75')
PY
  "$output/obj/Vtb_ap040_program" "+prog=$output/images/sieve-$offset.hex" \
    +phase=0 +maxcycles=4000000 +fetchprobe "+kernelpc=$base_hex" \
    >"$output/offset-$offset.log" 2>&1
  grep '^FETCH_PROBE_COMPLETE ' "$output/offset-$offset.log"
  if grep -q 'FAIL' "$output/offset-$offset.log"; then exit 1; fi
done
