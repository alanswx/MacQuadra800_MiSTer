#!/bin/sh
# Run the directed EA tests against either complete baseline or candidate RTL.
# No active sources/builds are modified. Usage: sh run.sh RTL NEW_OUTPUT
set -eu
fixture=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd "$fixture/../../.." && pwd)
rtl=$(realpath "$1")
output=$(realpath -m "$2")
if [ -e "$output" ]; then echo "Refusing existing output: $output" >&2; exit 2; fi
mkdir -p "$output/tb/asm"
cp -a "$rtl" "$output/rtl"
cp "$repo/rtl/ap68040/tb/tb_ap040_program.v" "$output/tb/"
cp "$repo/rtl/ap68040/tb/bin2hex.py" "$output/tb/"
cp "$fixture/asm/t_index_stage.s" "$output/tb/asm/"
cp "$fixture/index_pending_probe.sv" "$output/tb/"
cp "$fixture/run_index_stage_inner.sh" "$output/tb/run_index_stage.sh"
sha256sum "$output/rtl/ap040_core.v"
exec sh "$output/tb/run_index_stage.sh"
