# Provenance of the already-running timed baseline

This folder reconstructs the input set used by the full run launched at
22:55:31 on 2026-09-27. It was made after a later, host-only diagnostic edit
changed the working simulator binary while the original process continued to
run. No file in the live `baseline_sim` tree was edited during reconstruction.

`source_manifest.sha256` has exactly the prelaunch manifest SHA-256
`7fa63eec2603a26bf99b7378643a2a8c72302228baa6d96150efec1440f07233`.
All 130 listed files pass `sha256sum -c source_manifest.sha256` from this
directory. The binary was copied from the root agent's saved running executable
`../build/Vemu_running_54569322` and hashes
`5456932292677dddddc2e0563927e15dc54aa93e2f3ffaaf6dc3ac519dd7b188`.
The disk was copied from the pinned golden fixture, SHA-256
`80d8479430a66edae161c2bac6a9563dbb4f6bd0f564ee7849a555c447df8888`,
not from a disk that might be written by the active simulator.

`late_diagnostic.diff` shows the sole source change made after launch: the
FPU observer's prefix-abort diagnostic condition changed from
`fpu_prefix_ && !fpu_identified_` to `fpu_prefix_`. The timed-window detection,
span lifecycle, guest model, and RTL did not change. `manifest_late_diff.txt`
shows exactly three manifest row changes: the copied observer header in two
paths and the rebuilt executable. The post-launch test-only change to
`test_fpu_windows.cpp` is not in the source manifest and is not needed to run
the simulator.

`reconstruct.py` documents the reconstruction inputs and verifies that the
resulting manifest matches the recorded prelaunch digest. It writes only under
this `running_source` folder. Preserve the live run and its outputs separately.
