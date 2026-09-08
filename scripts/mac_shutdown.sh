#!/usr/bin/env bash
# scripts/mac_shutdown.sh — shut Mac OS down from INSIDE the guest (Special ->
# Shut Down) before swapping cores.
#
# WHY THIS EXISTS. Reloading the core while Mac OS is running is a hard
# power-cut on a mounted HFS volume. Doing it repeatedly on 2026-08-30 corrupted
# the Quad Squad image badly enough that it hung mid-boot at a repeatable offset
# — which then got misdiagnosed as an RTL fault more than once. Always shut the
# guest down first; only load a new core once the screen says it is safe.
#
# HOW IT DRIVES THE MOUSE. mrext sends RELATIVE motion and Mac OS applies mouse
# acceleration, so one big delta does NOT move a predictable number of pixels.
# Everything here therefore moves in 1-pixel steps, which stays under the
# acceleration threshold and tracks 1:1. The cursor is first "pinned" to the
# top-left by driving it hard into the corner, giving a known origin — the ADB
# mouse only reports deltas, so there is no absolute position to read back.
#
# STATUS 2026-08-30 (evening): WORKING. The click failed until the via6522
# shift-clock fix (docs/adb-via-shift.md) -- the mouse button is bit 7 of ADB
# Talk R0 byte 0 and every delivered byte reached the driver shifted one place
# left, so the button bit was thrown away. mrext's payloads were always right;
# it was the core. (Note the payloads ARE `left_down`/`left_up`; `mouseBtn:1`
# and `:0` are logged by mrext and do nothing.)
#
# The step counts below were RE-MEASURED after that fix and are motion EVENTS,
# not pixels: ~1.5 px each. They were 1:1 before, because the same bug also
# doubled the deltas -- so do not restore the old numbers, and re-measure with
# a screenshot rather than trusting either set blindly.
#
# Pacing matters: 0.008 s between motion events outruns the ~90 Hz ADB poll and
# the moves are silently lost. 0.02 s is what these counts were measured at.
#
# Usage:
#   bash scripts/mac_shutdown.sh            # do it, with verification shots
#   bash scripts/mac_shutdown.sh --dry-run  # print the plan only
#
# Verify before you trust it: shots land in scratch/shutdown_*.png.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
[ -r scripts/local.env ] && . scripts/local.env
: "${MISTER_HOST:?set MISTER_HOST in scripts/local.env}"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

WS="python scripts/mister_ws.py --host $MISTER_HOST --delay 0.008"

# Menu-bar geometry as MOTION EVENTS at 0.02 s (see STATUS above), measured
# 2026-08-30 against the Mac OS 8 Finder at 640x480: 100 events lands on View,
# 120 on Special -- but the scale is NOT stable between runs (a later run put
# 120 events at x=330, past Help), so this is only a starting point and the
# loop below corrects by screenshot. Titles in pixels: apple 26 | File 53 |
# Edit 88 | View 127 | Special 180 | Help 230, y = 9.
SPECIAL_X=70
MENUBAR_Y=4

# Emit N one-pixel steps in a direction.
steps() { local n=$1 dx=$2 dy=$3 out=""; while [ "$n" -gt 0 ]; do out="$out mouse:$dx,$dy"; n=$((n-1)); done; echo "$out"; }

PIN=$(steps 60 -12 -12)        # drive hard into the top-left corner
# down onto the menu bar FIRST, then across: y=0 is the very top row of the
# bar and a press there does not always land on the title.
TO_SPECIAL="$(steps $MENUBAR_Y 0 1) $(steps $SPECIAL_X 1 0)"

if [ "$DRY" = 1 ]; then
    echo "would pin to (0,0), then move to Special ($SPECIAL_X,$MENUBAR_Y), open it,"
    echo "screenshot, walk down to Shut Down and click."
    exit 0
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }
mkdir -p scratch

log "pinning cursor to top-left"
$WS $PIN >/dev/null 2>&1

log "moving toward Special ($SPECIAL_X,$MENUBAR_Y) and opening a menu"
$WS $TO_SPECIAL >/dev/null 2>&1
$WS mousebtn:left_down sleep:0.4 >/dev/null 2>&1

# The event-to-pixel scale is NOT stable -- moves get coalesced into one ADB
# report and Mac OS accelerates the coalesced delta -- so a fixed step count
# lands one menu over often enough to matter (it opened Help, not Special, on
# the first run after the ADB fix). Slide along the bar with the button held,
# which drags the pulled-down menu with it, until the open title is Special.
# Titles on a 640x480 Finder: apple 9 | View 105 | Special 149 | Help 208.
SPECIAL_MIN=140
SPECIAL_MAX=195
SPECIAL_MID=170
x0=""
found=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    bash scripts/grab_fresh.sh scratch/shutdown_menu.png >/dev/null 2>&1
    read -r st a b <<<"$(python scripts/menubar_probe.py scratch/shutdown_menu.png)"
    if [ "$st" != "OPEN" ]; then
        # a press in the empty part of the bar, right of Help, opens nothing
        log "no menu open (probe: $st) — stepping left"
        $WS $(steps 12 -1 0) >/dev/null 2>&1
        continue
    fi
    x0=$a
    if [ "$x0" -ge "$SPECIAL_MIN" ] && [ "$x0" -le "$SPECIAL_MAX" ]; then
        log "Special is open (title x=$x0)"
        found=1
        break
    fi
    # the event-to-pixel scale is unstable (measured between ~1.3 and ~12 px
    # per event depending on guest and coalescing), so MEASURE it from what
    # the previous move actually did and step by half the remaining error;
    # a fixed divisor oscillated View <-> Help for minutes on 2026-09-07.
    if [ "${prev_x0:--1}" -ge 0 ] && [ "${sent:-0}" -gt 1 ]; then
        moved=$(( x0 - prev_x0 )); am=${moved#-}
        [ "$am" -gt 0 ] && scale=$(( am * 100 / sent ))
        [ "$scale" -lt 50 ] && scale=50; [ "$scale" -gt 900 ] && scale=900
    fi
    scale=${scale:-400}
    err=$(( SPECIAL_MID - x0 ))
    aerr=${err#-}
    n=$(( aerr * 100 / scale / 2 ))
    [ "$n" -lt 1 ] && n=1
    [ "$n" -gt 40 ] && n=40
    prev_x0=$x0; sent=$n
    if [ "$err" -gt 0 ]; then
        log "open title at x=$x0 scale=$scale — stepping right $n"
        $WS $(steps "$n" 1 0) >/dev/null 2>&1
    else
        log "open title at x=$x0 scale=$scale — stepping left $n"
        $WS $(steps "$n" -1 0) >/dev/null 2>&1
    fi
done

if [ "$found" != 1 ]; then
    log "could not land on Special — releasing above the menu, nothing selected"
    $WS $(steps 40 0 -1) mousebtn:left_up >/dev/null 2>&1
    exit 3
fi

# Special menu (Mac OS 8.1): Clean Up Window / Empty Trash / Eject / Erase Disk
# / --- / Sleep / Restart / Shut Down.  Items are 16 px; Shut Down is the last.
# The menu is held OPEN with the button down and released over the item, which
# is the classic Mac press-drag-release a real user performs.
# Walk down to Shut Down. Same unstable scale as the horizontal walk, and here
# it matters more: Restart is the row directly above Shut Down. The probe
# reports the highlighted band AND the panel bottom, so the screenshot says
# where the pointer actually is -- step, re-probe, and only release once the
# LAST item (gap 0-4) is the highlighted one.
SHUTDOWN_DY=${SHUTDOWN_DY:-20}    # deliberately an UNDERshoot; the loop closes it
log "walking down $SHUTDOWN_DY events into the menu"
$WS $(steps "$SHUTDOWN_DY" 0 1) >/dev/null 2>&1

seen_item=0
ok=0
for attempt in $(seq 1 25); do
    bash scripts/grab_fresh.sh scratch/shutdown_hover.png >/dev/null 2>&1
    probe=$(python scripts/menuitem_probe.py scratch/shutdown_hover.png "$x0")
    case "$probe" in
        ITEM*)
            seen_item=1
            gap=${probe##*gap=}
            if [ "$gap" -le 4 ]; then
                log "Shut Down is highlighted ($probe)"
                ok=1
                break
            fi
            n=$(( gap / 4 )); [ "$n" -lt 1 ] && n=1
            log "highlight is ${gap}px above the panel bottom — stepping down $n"
            $WS $(steps "$n" 0 1) >/dev/null 2>&1 ;;
        NOITEM*)
            if [ "$seen_item" = 1 ]; then
                log "below the last row — stepping back up"
                $WS mouse:0,-1 >/dev/null 2>&1
            else
                log "not inside the menu yet — stepping down"
                $WS $(steps 3 0 1) >/dev/null 2>&1
            fi ;;
        *)
            log "menu vanished (probe: $probe) — aborting"
            break ;;
    esac
done

if [ "$ok" != 1 ]; then
    log "could not confirm Shut Down — releasing back on the menu title, nothing selected"
    $WS $(steps 60 0 -1) mousebtn:left_up >/dev/null 2>&1
    log "hover shot for diagnosis: scratch/shutdown_hover.png"
    exit 3
fi

log "hover shot: scratch/shutdown_hover.png"
# Released in place. Do NOT nudge the pointer to release: Restart is the row
# directly above Shut Down, and Erase Disk two above that.
$WS mousebtn:left_up >/dev/null 2>&1

log "released over Shut Down; waiting for the guest to park"
sleep 12
bash scripts/grab_fresh.sh scratch/shutdown_done.png >/dev/null 2>&1
log "final shot: scratch/shutdown_done.png"
log "Only load another core once that shows the shutdown screen."
