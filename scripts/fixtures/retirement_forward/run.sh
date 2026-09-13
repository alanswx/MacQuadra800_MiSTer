#!/bin/sh
set -eu
# Usage: sh run.sh COMPLETE_RTL NEW_OUTPUT baseline|candidate
fixture=$(CDPATH= cd "$(dirname "$0")" && pwd)
rtl=$(realpath "$1")
output=$(realpath -m "$2")
case "$3" in baseline) extra=;;candidate) extra=+candidate;;*) exit 2;;esac
if [ -e "$output" ]; then echo "Refusing existing output: $output" >&2;exit 2;fi
mkdir -p "$output"
sha256sum "$rtl/ap040_core.v"
iverilog -g2012 -I "$rtl" -s tb_retirement_forward -o "$output/test.vvp" \
 "$fixture/tb_retirement_forward.sv" "$rtl/ap040_core.v" \
 "$rtl/ap040_regfile.v" "$rtl/ap040_alu.v" "$rtl/ap040_muldiv.v"
vvp "$output/test.vvp" $extra >"$output/test.log" 2>&1
grep 'FORWARD_ALL_PASS' "$output/test.log"
if grep -E 'FAIL|ERROR|FATAL' "$output/test.log";then exit 1;fi
