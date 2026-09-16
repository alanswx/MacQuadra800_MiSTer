#!/bin/bash
# Cross-build the Main fork (../Main_MiSTer) for the DE10-Nano inside WSL:
# rsync the tree to ~/Main_MiSTer (ext4 -- the /mnt/c tree is slow and
# case-insensitive) and make with the ARM toolchain the RESUME notes name.
# The binary and its md5 land in this repo's scratch/ as MiSTer_<md5[:8]>.
#   wsl.exe -e bash -lc 'bash /mnt/c/Temp/mistercore/MacQuadra800_MiSTer/scripts/build_main_wsl.sh'
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$HERE/../Main_MiSTer}
DST=${DST:-$HOME/Main_MiSTer}
TC=/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin
mkdir -p "$DST" "$HERE/scratch"
rsync -a --exclude .git "$SRC/" "$DST/"
cd "$DST"
git -C "$SRC" log --oneline -1 2>/dev/null || true
PATH=$TC:$PATH make -j8
MD5=$(md5sum MiSTer | cut -c1-32)
cp MiSTer "$HERE/scratch/MiSTer_${MD5:0:8}"
echo "built MiSTer md5 $MD5 -> scratch/MiSTer_${MD5:0:8}"
