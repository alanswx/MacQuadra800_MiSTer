#!/usr/bin/env python3
"""One-shot host filesystem write-latency profile on a unique disposable file."""
import json
import os
import statistics
import tempfile
import time

ROOT = "/media/fat"
SIZE = 4 * 1024 * 1024
BLOCKS = (512, 4096, 16384)


def device_stats():
    with open("/proc/diskstats") as f:
        for line in f:
            fields = line.split()
            if fields[2] == "mmcblk0":
                # Linux diskstats: reads, read merges, read sectors, read ms,
                # writes, write merges, write sectors, write ms, in-flight,
                # io ms, weighted io ms (the final field is retained too).
                return {"counters_after_device_name": list(map(int, fields[3:]))}
    return None


def pct(values, fraction):
    vals = sorted(values)
    return vals[min(len(vals) - 1, int((len(vals) - 1) * fraction))]


def write_sweep(fd, block_size, pattern):
    payload = pattern * block_size
    timings_ns = []
    t0 = time.monotonic_ns()
    for offset in range(0, SIZE, block_size):
        t = time.monotonic_ns()
        n = os.pwrite(fd, payload, offset)
        elapsed = time.monotonic_ns() - t
        if n != block_size:
            raise OSError(f"short pwrite at {offset}: {n}")
        timings_ns.append(elapsed)
    elapsed_ns = time.monotonic_ns() - t0
    return {
        "block_bytes": block_size,
        "writes": len(timings_ns),
        "bytes": SIZE,
        "elapsed_ms_including_syscalls": elapsed_ns / 1e6,
        "syscall_ms_median": statistics.median(timings_ns) / 1e6,
        "syscall_ms_p95_floor_order_statistic": pct(timings_ns, .95) / 1e6,
        "syscall_ms_max": max(timings_ns) / 1e6,
    }


directory = tempfile.mkdtemp(prefix=".disk-profile-20260925-", dir=ROOT)
path = os.path.join(directory, "backend-test.bin")
result = {"host": os.uname().nodename, "path": path, "size_bytes": SIZE,
          "mount_path": ROOT, "mount_options": "see /proc/mounts",
          "sync_sweeps": [], "cleanup": False}
try:
    # Exclusive creation ensures this test cannot replace an existing path.
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_RDWR | os.O_SYNC, 0o600)
    try:
        # Populate and durably flush the one-time allocation before measurements.
        zero = bytes(65536)
        for offset in range(0, SIZE, len(zero)):
            if os.pwrite(fd, zero, offset) != len(zero):
                raise OSError("short preallocation write")
        os.fsync(fd)
        result["diskstats_before"] = device_stats()
        for block_size in BLOCKS:
            pattern = bytes([block_size // 4096 + 65])
            result["sync_sweeps"].append(write_sweep(fd, block_size, pattern))
        result["diskstats_after"] = device_stats()
        result["mounts"] = [line.strip() for line in open("/proc/mounts")
                            if line.split()[1] == ROOT]
    finally:
        os.close(fd)
finally:
    os.unlink(path)
    os.rmdir(directory)
    result["cleanup"] = not os.path.exists(path) and not os.path.exists(directory)
print(json.dumps(result, sort_keys=True, indent=2))
