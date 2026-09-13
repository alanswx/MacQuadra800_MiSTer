#!/bin/sh
# Isolated builds recommended. Serial per fixture tree (shared build/incbin).
# Usage: sh run.sh RESOURCE COMPLETE_AP_RTL OUTPUT [WORD_OFFSETS...]
set -eu
cd "$(dirname "$0")"
repo=$(CDPATH= cd ../../.. && pwd)
resource=$1
rtl=$(realpath "$2")
output=$(realpath -m "$3")
shift 3
if [ "$#" -eq 0 ]; then set -- 0 6; fi
mkdir -p build "$output/images"
python3 "$repo/rtl/ap68040/tb/prepare_exact_sieve.py" "$resource" build/exact_sieve.bin
sha256sum "$rtl/ap040_core.v" build/exact_sieve.bin \
 "$repo/rtl/wombat_cpu.sv" "$repo/rtl/wombat_bus32.sv" \
 "$repo/rtl/wombat_store_buffer.sv" "$repo/rtl/sdram_beat32.sv" "$repo/rtl/sdram.sv"
"${VERILATOR:-verilator}" --binary --timing -Wno-fatal -j "${JOBS:-4}" \
 --top-module tb_wombat_sieve --Mdir "$output/obj" +define+SIMULATION=1 -I"$rtl" \
 tb_wombat_sieve.sv "$repo/verilator/tb_sdram.sv" "$repo/verilator/altddio_out_stub.v" \
 "$repo/rtl/wombat_cpu.sv" "$repo/rtl/wombat_bus32.sv" "$repo/rtl/wombat_store_buffer.sv" \
 "$repo/rtl/sdram_beat32.sv" "$repo/rtl/sdram.sv" \
 "$rtl/ap040_core.v" "$rtl/ap040_bus_timeout.v" "$rtl/ap040_regfile.v" \
 "$rtl/ap040_alu.v" "$rtl/ap040_muldiv.v" "$rtl/ap040_mmu.v" \
 "$rtl/ap040_cache.v" "$rtl/ap040_fpu.v" "$rtl/primitives/dpram.v" \
 >"$output/compile.log" 2>&1
for offset in "$@"; do
 case "$offset" in 0|2|4|6|8|10|12|14|16|18|20|22|24|26|28|30) ;; *) exit 2;; esac
 base=$((8192+offset)); base_hex=$(printf '%x' "$base")
 "${VASM:-vasmm68k_mot}" -Fbin -m68040 -no-opt -DKERNEL_BASE="$base" \
  -o "$output/images/sieve-$offset.bin" asm/bench_exact_sieve.s >"$output/images/asm-$offset.log"
 python3 "$repo/rtl/ap68040/tb/bin2hex.py" "$output/images/sieve-$offset.bin" "$output/images/sieve-$offset.hex"
 python3 - "$output/images/sieve-$offset.bin" "$base" <<'PY'
from pathlib import Path
import sys
image=Path(sys.argv[1]).read_bytes(); base=int(sys.argv[2])
assert image[base:base+80] == Path('build/exact_sieve.bin').read_bytes()
assert image[base+80:base+84] == bytes.fromhex('4e714e75')
PY
 "$output/obj/Vtb_wombat_sieve" "+prog=$output/images/sieve-$offset.hex" \
  "+kernelpc=$base_hex" +maxcycles=4000000 >"$output/offset-$offset.log" 2>&1
 grep '^INTEGRATION_COMPLETE ' "$output/offset-$offset.log"
done
