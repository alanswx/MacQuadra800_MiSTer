#!/bin/bash
# Build and run the graphics microbench (tb_gfx.sv + gfx.s) against ../../rtl.
# Needs vasmm68k_mot and verilator on PATH; ~1 min build, ~5 s run; see RESULTS.md.
set -e
cd "$(dirname "$0")"
TREE=$(cd ../..; pwd)
FAST040=$TREE/rtl/ap68040_faster/rtl
SRC=$(grep -o '"[^"]*v"' $FAST040/ap68040.qip | tr -d '"' | sed "s|^|$FAST040/|")

vasmm68k_mot -m68040 -Fbin -quiet -o gfx.bin gfx.s
xxd -p -c4 gfx.bin > gfx.hex

verilator --binary --timing -j 8 -Wno-fatal -Wno-lint -Wno-style \
	-I$FAST040 -I$FAST040/gen -I$FAST040/fpu \
	--top-module tb_gfx --Mdir ./obj_gfx -o tb_gfx -GVRAM_POST=1 \
	$SRC $TREE/rtl/quadra_cpu040.sv $TREE/rtl/wombat_store_buffer.sv tb_gfx.sv

./obj_gfx/tb_gfx "$@"
