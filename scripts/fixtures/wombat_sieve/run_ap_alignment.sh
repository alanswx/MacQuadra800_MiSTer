#!/bin/sh
# Same first-pass probe with AP's artificial 16-bit bus, all16 alignments.
# Usage: sh run_ap_alignment.sh RESOURCE COMPLETE_AP_RTL NEW_OUTPUT_DIRECTORY
set -eu
fixture=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd "$fixture/../../.." && pwd)
resource=$(realpath "$1")
rtl=$(realpath "$2")
output=$(realpath -m "$3")
if [ -e "$output" ]; then echo "Refusing existing output: $output" >&2; exit 2; fi
mkdir -p "$output/tb/asm"
for name in tb_ap040_program.v exact_sieve_monitor.sv prepare_exact_sieve.py bin2hex.py; do
 cp "$repo/rtl/ap68040/tb/$name" "$output/tb/$name"
done
cp "$fixture/asm/bench_exact_sieve.s" "$output/tb/asm/bench_exact_sieve.s"
cp "$fixture/frontfetch_probe.sv" "$output/tb/frontfetch_probe.sv"
cp "$fixture/run_alignment_inner.sh" "$output/tb/run_alignment.sh"
(cd "$output/tb" && patch -p0 < "$fixture/ap-monitor-hook.patch")
exec sh "$output/tb/run_alignment.sh" "$resource" "$rtl" "$output/results"
