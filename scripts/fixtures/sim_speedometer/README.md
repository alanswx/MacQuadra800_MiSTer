# Current CPU Speedometer baseline

`prefix_control.txt` is the historical keyboard sequence for the immutable
`MacQuadra800-Speedometer402-profile.hda` fixture: cold boot, open Speedometer
4.02, choose Benchmark Mix, start profiling, and press Run Set. Its waits
are simulated rising edges, so a full run takes substantial wall time.
It is specific to this disk's Finder layout; screenshots must confirm it.

The current baseline is in `scratch/pipeline_baseline_20260919c/`, launched
by `q800-pipeline-baseline-c-20260919.service`. The monitor is
`q800-pipeline-baseline-monitor-c-20260919.service`. Both are user systemd
units. `identities.json` records the copied simulator, selected development ROM, golden
disk and prefix hashes; `source_sha256.json` and `sources/` preserve source
identity. `run.hda` is disposable; never mount the golden disk directly.

The first cold-boot attempt reached MacAtrium but the host crashed on its
first key: `SimInput::ps2_key` had not been connected to the model port.
That connection is fixed and covered by `test_profile_integration.py`.
The `b` attempt was stopped during RAM testing after confirming that the
legacy `+warmstart` option does not skip this ROM's RAM test. See
`docs/quadra800-ram-test.md`: the low-memory cookie is not the RAM-test gate.
The current `c` development run uses `make -C verilator fastboot` and copies
`quadra800-fastboot.rom.hex`, with the initial wait reduced to 660,000,000
rising edges. Verification confirmed that this ROM differs only in the
RAM-test branch and corrected checksum. **This is development profiling,
not pristine-ROM acceptance.** Later simulator comparisons must use the
same recipe; release acceptance still uses the original ROM.

The simulator invocation, from that scratch directory, is:

```sh
./Vemu --headless --no-cpu-trace --disk run.hda +rom=rom.hex +ram=0 \
  --control control.txt --cpu-profile profile.tsv \
  --speedometer-observe timer.log --max-cycles 14000000000
```

For another run, create a new directory with fresh copies and identities;
do not reuse a mounted or previously interrupted writable image.

The monitor waits for the profile start, requests screenshots at 20-million
guest-clock intervals, and uses Tesseract to identify the completion alert.
It stops the profile, dismisses the alert, captures results, writes a state
and opcode report, then sends `quit` through that run's own control stream. The simulator
flushes its observer summary and exits; the monitor checks its exit status. It is intentionally a **disposable simulation** procedure, not
permission to interrupt a running hardware guest. The completion screenshot
and results still require inspection; a captured screen is not itself a
valid benchmark result.

```sh
python3 scripts/fixtures/sim_speedometer/monitor_baseline.py NEW_RUN_DIRECTORY
python3 scripts/cpu/report_pipeline_profile.py NEW_RUN_DIRECTORY/profile.tsv
```

The bracket includes launch overhead and polling, capture and host-processing delay
after the completion alert. Its state counts cover the complete
bracket, not just benchmark kernels. Dispatch counts are opcode-load events,
which include faulting instructions and may omit folded short branches.
Report them as clocks/opcode load, never retirement CPI. The P0 supported
opcode share is instruction coverage, not an estimate of saved cycles.

Check `timer.log` for a final summary, recognized identities and a capture
cap before interpreting it. Missing anomalies cannot establish timer
correctness. A crash/interrupted run can leave buffered records unwritten.
