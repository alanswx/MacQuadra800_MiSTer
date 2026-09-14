#!/usr/bin/env bash
# Unattended simulated Speedometer 4.02 CPU Mix run.
#   run_speedometer_sim.sh VEMU ROM_HEX GOLDEN_HDA PREFIX_CONTROL ALERT_SIG OUTDIR
# PREFIX_CONTROL: a control script ending with the Run Set Return (it must
# contain "profile start" just before that Return). ALERT_SIG: md5 of the
# RGB bytes of box (240,110)-(400,195) of the "The tests are done!" alert.
# Polls a screenshot every ~0.6 s of guest time, sends "profile stop" in
# the poll that sees the alert, dismisses it, shoots the results, kills Vemu.
set -euo pipefail
vemu=$1 rom=$2 golden=$3 prefix=$4 sig=$5 out=$6
send=/home/alans/mister/MacQuadra800_MiSTer/scripts/guest/sim_control_send.py
mkdir -p "$out"; cp "$vemu" "$out/Vemu"; cp "$rom" "$out/rom.hex"; cp "$golden" "$out/run.hda"
md5sum "$out/run.hda" | tee "$out/run.hda.md5"
cp "$prefix" "$out/control.txt"
cd "$out"
nohup sh -c './Vemu --headless --no-cpu-trace --disk ./run.hda +rom=./rom.hex --control ./control.txt --cpu-profile ./profile.tsv --max-cycles 40000000000 > run.log 2>&1; echo $? > exit.status' &
echo "launched $(date +%T)"
boxsig() { python3 - "$1" <<'PY'
from PIL import Image; import hashlib,sys
im=Image.open(sys.argv[1]).convert('RGB').crop((240,110,400,195)); print(hashlib.md5(im.tobytes()).hexdigest())
PY
}
# wait until the prefix's profile start has been consumed
until grep -q "CPU-PROFILE\] started" run.log 2>/dev/null; do sleep 15; [ -f exit.status ] && { echo "sim exited early"; exit 1; }; done
echo "profile started $(date +%T)"
seen=$(ls screenshot_f*.png 2>/dev/null | wc -l)
for i in $(seq 1 400); do
  python3 "$send" control.txt "wait 20000000" "shot"
  until [ "$(ls screenshot_f*.png 2>/dev/null | wc -l)" -gt "$seen" ]; do sleep 2; [ -f exit.status ] && { echo "sim exited"; exit 1; }; done
  seen=$(ls screenshot_f*.png | wc -l); new=$(ls -t screenshot_f*.png | head -1)
  if [ "$(boxsig "$new")" = "$sig" ]; then
    python3 "$send" control.txt "profile stop"
    echo "alert seen in $new at $(date +%T), profile stop sent"
    break
  fi
done
until grep -q "CPU-PROFILE\] wrote" run.log; do sleep 2; done
python3 "$send" control.txt "wait 3300000" "down 5a" "wait 330000" "up 5a" "wait 66000000" "shot"
sleep 60; until [ "$(ls screenshot_f*.png | wc -l)" -gt "$seen" ]; do sleep 2; done
ls -t screenshot_f*.png | head -1 > results_shot.txt
pkill -f "$out/Vemu" || pkill -f "./Vemu" || true
grep "CPU-PROFILE\] wrote" run.log; cat results_shot.txt; echo "done $(date +%T)"
