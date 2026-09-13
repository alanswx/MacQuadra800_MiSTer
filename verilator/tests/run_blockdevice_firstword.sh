#!/bin/sh
# Real simulator block producer + actual scsi_cache, no CPU/ROM/guest needed.
# Optional args: NEW_OUTPUT_DIRECTORY [ALTERNATIVE_sim_blkdevice.cpp]
set -eu
tests=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo=$(CDPATH= cd "$tests/../.." && pwd)
if [ "$#" -gt 0 ]; then
 output=$(realpath -m "$1")
 if [ -e "$output" ]; then echo "Refusing existing output: $output" >&2; exit 2; fi
 mkdir -p "$output"
else
 output=$(mktemp -d /tmp/blockdevice-firstword.XXXXXX)
fi
producer=${2:-"$repo/verilator/sim/sim_blkdevice.cpp"}
producer=$(realpath "$producer")
printf 'First-word test artifacts: %s\n' "$output"
sha256sum "$producer" "$repo/rtl/scsi_cache.sv"
"${VERILATOR:-verilator}" --cc --exe --build -j "${JOBS:-4}" -Wno-fatal \
 --top-module scsi_cache --Mdir "$output/obj" \
 -CFLAGS "-I$repo/verilator/sim -I$repo/verilator/sim/imgui" \
 "$repo/rtl/scsi_cache.sv" "$tests/blockdevice_firstword_test.cpp" "$producer" \
 >"$output/compile.log" 2>&1
for latency in 1 40 16000; do
 FIRSTWORD_IMAGE="$output/pattern-$latency.hda" "$output/obj/Vscsi_cache" \
  "+blkdev_latency=$latency" >"$output/latency-$latency.log" 2>&1
 grep '^FIRSTWORD_RESULT ' "$output/latency-$latency.log"
done
