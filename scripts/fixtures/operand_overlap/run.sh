#!/bin/sh
# Usage: sh run.sh COMPLETE_AP_RTL NEW_OUTPUT baseline|candidate|source|destination
set -eu
fixture=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd "$fixture/../../.." && pwd)
rtl=$(realpath "$1")
output=$(realpath -m "$2")
kind=$3
case "$kind" in baseline|candidate|source|destination) ;; *) exit 2;; esac
if [ -e "$output" ]; then echo "Refusing existing output: $output" >&2; exit 2; fi
mkdir -p "$output/tb/asm"
cp -a "$rtl" "$output/rtl"
cp "$repo/rtl/ap68040/tb/tb_ap040_program.v" "$output/tb/"
cp "$repo/rtl/ap68040/tb/bin2hex.py" "$output/tb/"
cp "$fixture/asm/t_index_stage.s" "$fixture/asm/t_ea_fault.s" "$output/tb/asm/"
cp "$fixture/index_pending_probe.sv" "$fixture/ea_overlap_probe.sv" "$output/tb/"
cp "$fixture/run_inner.sh" "$output/tb/"
sha256sum "$output/rtl/ap040_core.v"
exec sh "$output/tb/run_inner.sh" "$kind"
