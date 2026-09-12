#!/usr/bin/env bash
# Guarded lifecycle for the authorized disposable CPU benchmark fixture.
# Never run during a timed benchmark. No Main replacement or recovery/reboot.
set -euo pipefail

host=root@192.168.1.75
golden=/tmp/MacQuadra800-Speedometer402-profile.hda
disk=/media/fat/games/MacQuadra800/Speedometer402-upstream-test.hda
disk_md5=16790b0577e13b45782214433d34954b
main_md5=dfb5937ba47720c3ae20abc8f381c462
dry_run=0
fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
usage() {
    echo 'Usage: bash scripts/cpu_benchmark_core.sh [--dry-run] restore'
    echo '   or: bash scripts/cpu_benchmark_core.sh [--dry-run] deploy LOCAL.rbf /media/fat/_Unstable/UNIQUE.rbf SHA256'
    exit 2
}
remote() { timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "$@"; }
main_ok() {
    local got
    got=$(remote 'md5sum /media/fat/MiSTer' | awk '{print $1}')
    [[ "$got" == "$main_md5" ]] || fail 'Main hash changed; no action taken.'
    got=$(remote 'pidof MiSTer') || fail 'Main is not running; ask Astra to diagnose.'
    [[ "$got" =~ ^[0-9]+$ ]] || fail 'Expected exactly one Main process.'
}
menu_ok() {
    local core
    main_ok
    core=$(remote 'cat /tmp/CORENAME')
    [[ "$core" == MENU ]] || fail "Disk overwrite refused: core is '$core', not MENU."
}
load_core() {
    local path=$1 expected=$2 old_pid new_pid core attempt
    [[ "$path" == /media/fat/menu.rbf ||
       "$path" =~ ^/media/fat/_Unstable/[A-Za-z0-9_-]+\.rbf$ ]] || fail 'Not an allowed RBF path.'
    main_ok
    old_pid=$(remote 'pidof MiSTer')
    # Timeout on BOTH ends: a missing FIFO reader must not leave a writer behind.
    remote "timeout 8 sh -c 'printf \"%s\\n\" \"load_core $path\" > /dev/MiSTer_cmd'" ||
        fail 'Core command failed; stop for diagnosis, do not overwrite the disk.'
    for attempt in {1..30}; do
        sleep 1
        new_pid=$(remote 'pidof MiSTer' || true)
        core=$(remote 'cat /tmp/CORENAME' || true)
        if [[ "$new_pid" =~ ^[0-9]+$ && "$new_pid" != "$old_pid" && "$core" == "$expected" ]]; then
            main_ok
            printf 'Loaded %s; Main PID %s -> %s; core %s\n' "$path" "$old_pid" "$new_pid" "$core"
            return
        fi
    done
    fail 'No verified Main restart/core transition; stop for diagnosis.'
}
restore_disk() {
    menu_ok
    printf 'Restoring disposable only: %s\n' "$disk"
    timeout 120 scp -o BatchMode=yes -o ConnectTimeout=5 "$golden" "$host:$disk"
    menu_ok
    local got
    got=$(remote "md5sum '$disk'" | awk '{print $1}')
    [[ "$got" == "$disk_md5" ]] || fail 'Restored disk hash mismatch.'
    printf 'Restored MD5: %s\n' "$got"
}

[[ ${1-} != --dry-run ]] || { dry_run=1; shift; }
[[ $# -ge 1 ]] || usage
mode=$1
shift
case "$mode" in
    restore) [[ $# -eq 0 ]] || usage ;;
    deploy)
        [[ $# -eq 3 ]] || usage
        rbf=$1
        target=$2
        expected_sha=$3
        [[ -f "$rbf" && "$rbf" == *.rbf ]] || fail 'Local candidate must be an existing .rbf file.'
        [[ "$target" =~ ^/media/fat/_Unstable/[A-Za-z0-9_-]+\.rbf$ ]] || fail 'Remote target must be a uniquely named _Unstable .rbf.'
        [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || fail 'Expected SHA256 is required.'
        [[ $(sha256sum "$rbf" | awk '{print $1}') == "$expected_sha" ]] || fail 'Candidate SHA256 mismatch.'
        [[ $(od -An -tx1 -N4 "$rbf" | tr -d ' \n') != 7f454c46 ]] || fail 'ELF executable is NOT a bitstream.'
        bytes=$(stat -c %s "$rbf")
        (( bytes >= 1000000 && bytes <= 16000000 )) || fail 'Unexpected RBF size.'
        ;;
    *) usage ;;
esac
[[ -f "$golden" ]] || fail 'Golden fixture missing.'
[[ $(md5sum "$golden" | awk '{print $1}') == "$disk_md5" ]] || fail 'Golden fixture hash mismatch.'
if (( dry_run )); then
    printf 'LOCAL PREFLIGHT PASS: mode=%s host=%s disk=%s\n' "$mode" "$host" "$disk"
    [[ "$mode" != deploy ]] || printf 'Candidate %s -> %s SHA256 %s\n' "$rbf" "$target" "$expected_sha"
    exit 0
fi

main_ok
slot=$(remote 'cat /media/fat/config/MacQuadra800.s0')
[[ "$slot" == games/MacQuadra800/Speedometer402-upstream-test.hda ]] || fail 'Unexpected slot-0 mount.'
if [[ "$mode" == deploy ]]; then
    existing=$(remote "if [ -e '$target' ]; then sha256sum '$target'; fi" | awk '{print $1}')
    [[ -z "$existing" || "$existing" == "$expected_sha" ]] || fail 'Refusing to replace a different existing RBF.'
fi
load_core /media/fat/menu.rbf MENU
restore_disk
if [[ "$mode" == deploy ]]; then
    if [[ -z "$existing" ]]; then
        timeout 120 scp -o BatchMode=yes -o ConnectTimeout=5 "$rbf" "$host:$target"
    fi
    got=$(remote "sha256sum '$target'" | awk '{print $1}')
    [[ "$got" == "$expected_sha" ]] || fail 'Remote RBF hash mismatch.'
    load_core "$target" MacQuadra800
    echo 'Candidate loaded. Disk is now writable/dirty; wait for VISUAL boot readiness before input.'
else
    echo 'CLEANUP COMPLETE: verified MENU, golden disposable, unchanged Main.'
fi
