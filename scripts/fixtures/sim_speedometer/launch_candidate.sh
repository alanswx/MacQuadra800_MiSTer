#!/usr/bin/env bash
# Boot A/B (420 M CPU clocks of the Mac OS 8.1 boot with the Speedometer disk, per-state profile)
# and then the simulated Speedometer 4.02 CPU Mix of one candidate RTL tree.
# Usage: CAND=<tree with rtl/ap68040/rtl and rtl/wombat_cpu.sv> NAME=<tag> SIMTREE=<built verilator tree> \
#        GOLDEN=<Speedometer402-profile.hda> bash launch_candidate.sh
# Run it as a systemd user unit; every path it writes is /tmp/simboot-$NAME.* and /tmp/simspeedo-$NAME.
set -u
CAND=${CAND:?candidate tree}; NAME=${NAME:-cand}; SIMTREE=${SIMTREE:?a built verilator tree}; GOLDEN=${GOLDEN:-$GOLDEN}; HERE=$(cd "$(dirname "$0")" && pwd)
C=$(mktemp -d /tmp/simboot-$NAME.XXXXXX); echo "$C" > /tmp/simboot-$NAME.path
cp -a $SIMTREE/. "$C/"
rm -rf "$C/run"
# the hint bus makes the wrapper's mem_instr an alias Verilator folds away: the harness reads the core's registered request flag instead
sed -i 's/__PVT__machine__DOT__cpu__DOT__mem_instr\b/__PVT__machine__DOT__cpu__DOT__core__DOT__mem_instr_q/' "$C/verilator/sim_main.cpp"; grep -c "core__DOT__mem_instr_q" "$C/verilator/sim_main.cpp"
cp "$CAND/rtl/ap68040/rtl/ap040_cache.v" "$C/rtl/ap68040/rtl/ap040_cache.v"
cp "$CAND/rtl/ap68040/rtl/ap040_core.v"  "$C/rtl/ap68040/rtl/ap040_core.v"
cp "$CAND/rtl/ap68040/rtl/ap040_alu.v"   "$C/rtl/ap68040/rtl/ap040_alu.v"
cp "$CAND/rtl/ap68040/rtl/ap040_mmu.v"   "$C/rtl/ap68040/rtl/ap040_mmu.v"
cp "$CAND/rtl/ap68040/rtl/ap040_tg68k_compat.v" "$C/rtl/ap68040/rtl/ap040_tg68k_compat.v"
cp "$CAND/rtl/wombat_cpu.sv" "$C/rtl/wombat_cpu.sv"
sha256sum "$C/rtl/ap68040/rtl/ap040_cache.v" "$C/rtl/ap68040/rtl/ap040_core.v" "$C/rtl/ap68040/rtl/ap040_alu.v"
cd "$C/verilator"
make -j6 V=/home/alans/verilator5/bin/verilator > "$C/build.log" 2>&1 || { echo "BUILD FAILED"; grep -m5 "rror" "$C/build.log"; exit 1; }
echo "build ok $(date +%T)"
R="$C/run"; mkdir -p "$R"; cp obj_dir/Vemu "$R/mq800sim"; cp quadra800-fastboot.rom.hex "$R/rom.hex"
cp $GOLDEN "$R/run.hda"; md5sum "$R/run.hda"
cp $HERE/boot_control.txt "$R/control.txt"; cd "$R"
./mq800sim --headless --no-cpu-trace --disk ./run.hda +rom=./rom.hex --control ./control.txt --cpu-profile ./profile.tsv --max-cycles 900000000 > run.log 2>&1; echo "run exit $? $(date +%T)"
grep "CPU-PROFILE\] wrote" run.log; md5sum screenshot_f*.png | head -2
grep -c "double\|HALT\|halted" run.log
# Speedometer sim, same binary
rm -rf /tmp/simspeedo-$NAME
cd "${MQ_REPO:-/home/alans/mister/MacQuadra800_MiSTer}"
bash $HERE/run_speedometer_sim.sh \
  "$C/verilator/obj_dir/Vemu" "$C/verilator/quadra800-fastboot.rom.hex" $GOLDEN \
  /home/alans/mister/MacQuadra800_MiSTer/scripts/fixtures/sim_speedometer/prefix_control.txt ed8e56c29bb6476c282ce2facaa35d46 /tmp/simspeedo-$NAME > /tmp/simspeedo-$NAME.log 2>&1
echo "speedo driver exit $? $(date +%T)"
