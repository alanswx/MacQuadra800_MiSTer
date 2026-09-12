#!/usr/bin/env bash
# grab_fresh.sh — like scripts/grab.sh but FAILS LOUDLY when no NEW frame appears.
# The stock grab downloads the newest stored screenshot, which silently serves a
# stale frame when the core's video is dead (capture produces nothing — seen
# 2026-08-03 on the SEED-7 probes-on black-screen fit). This wrapper records the
# newest mtime BEFORE the POST and only accepts a frame newer than that.
# Usage: bash scripts/grab_fresh.sh <outfile.png>   -> exit 0 fresh, 3 stale/none
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
. scripts/local.env
HTTP="http://$MISTER_HOST:$MISTER_HTTP_PORT"
OUT="${1:?usage: grab_fresh.sh outfile.png}"
mkdir -p -- "$(dirname -- "$OUT")"

newest() {
  curl --fail --silent --show-error --connect-timeout 5 --max-time 20 "$HTTP/api/screenshots" | python -c "
import sys, json
d = json.load(sys.stdin)
d.sort(key=lambda x: x['modified'])
print(d[-1]['modified'] + '|' + d[-1]['path'] if d else '|')"
}

BEFORE=$(newest)
curl --fail --silent --show-error --connect-timeout 5 --max-time 20 -X POST "$HTTP/api/screenshots" >/dev/null
for i in 1 2 3 4 5; do
  sleep 2
  AFTER=$(newest)
  if [ "$AFTER" != "$BEFORE" ]; then
    ENC=$(printf '%s' "${AFTER#*|}" | python -c "import sys,urllib.parse as u; print(u.quote(sys.stdin.read()))")
    if ! curl --fail --silent --show-error --connect-timeout 5 --max-time 20 -o "$OUT" "$HTTP/api/screenshots/$ENC"; then
      echo "FAILED: screenshot download to $OUT" >&2
      exit 4
    fi
    [[ -s "$OUT" ]] || { echo "FAILED: empty/missing screenshot $OUT" >&2; exit 4; }
    echo "FRESH $OUT ($(stat -c %s "$OUT") bytes) <- ${AFTER#*|}"
    exit 0
  fi
done
echo "STALE: no new frame after POST — video capture is dead (newest remains ${BEFORE#*|})"
exit 3
