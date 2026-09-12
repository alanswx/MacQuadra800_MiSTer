#!/usr/bin/env bash
# Deterministic navigation for the verified golden CPU benchmark fixture.
# PRECONDITION: visually confirmed MacAtrium, or idle Finder with volume selected.
# Never use during a benchmark. Leaves Run Set UNSTARTED for visual verification.
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ $# -eq 2 && ( ${1-} == --macatrium-ready || ${1-} == --finder-ready ) ]] || {
    echo 'Usage: bash scripts/guest/speedometer402_setup.sh --macatrium-ready|--finder-ready scratch/perf_NAME' >&2
    exit 2
}
start_mode=$1
out=$2
[[ "$out" =~ ^scratch/perf_[A-Za-z0-9_-]+$ ]] || {
    echo 'Use a scratch/perf_NAME output directory.' >&2
    exit 2
}
mkdir -p "$out"
export MISTER_TYPE_DELAY=0.2
key() { python scripts/mister_ws.py --host 192.168.1.75 --delay 0.3 "$@"; }
snap() { bash scripts/grab_fresh.sh "$out/setup_$1.png"; }
open_selected() { key down:56 raw:24 up:56 sleep:2; }

# MacAtrium -> Finder. Do not send another Return in Finder: it renames icons.
if [[ $start_mode == --macatrium-ready ]]; then
    key raw:1 sleep:1 raw:15 raw:15 raw:28 sleep:3
fi
snap finder

# The fresh Finder desktop already selects the Mac7-5-5 volume.
open_selected
snap volume

# "app" selects Apple Extras. The extra "li" disambiguates Applications.
bash scripts/guest/type.sh appli
open_selected
snap applications

bash scripts/guest/type.sh 'Speedometer 4'
open_selected
snap folder

bash scripts/guest/type.sh spe
key down:56 raw:24 up:56 sleep:8
snap splash

key raw:28 sleep:2 raw:1 sleep:3 down:56 raw:48 up:56 sleep:2
snap ready
echo "COMMANDS SENT ONLY: visually verify $out/setup_ready.png has all ten CPU tests at one iteration."
echo 'Run Set has NOT been activated. Do not start timing if the final screen is wrong.'
