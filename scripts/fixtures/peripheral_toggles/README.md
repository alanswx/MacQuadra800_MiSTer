# Peripheral compile-toggle checks

Run from any directory, with an explicit checkout:

```sh
python3 /home/alans/mister/MacQuadra800_MiSTer/scripts/fixtures/peripheral_toggles/run.py \
  --repo /home/alans/mister/MacQuadra800_MiSTer \
  --baseline 50ca69b4bbcc7f1ae4a407f6607ecc9e20d0ebbf
```

Requires Python 3 and Verilator (`--verilator` overrides the default
`/home/alans/verilator5/bin/verilator`). Builds only two small simulators in
a unique `/tmp/peripheral-toggles.*` directory and retains build/run logs.
No Quartus, CPU, disks, remote access, or hardware deployment is involved.
The baseline must precede the compile-toggle edits; do not substitute a
post-toggle HEAD when validating preservation of the original default.

Coverage:

- Token-identical preprocessing of all three modified RTL files against the
  baseline when no new macro is defined. Whitespace/comments are ignored;
  quoted string contents are preserved.
- All 32 combinations of the three new macros, `MISTER_DEBUG_NOHDMI`, and
  `MISTER_FB`: preprocessing plus instance/menu/tie-off structure assertions.
  This is not whole-platform elaboration of all 32 configurations.
- The extracted shadowmask bypass is linted with `--language 1364-2001`.
  An additional explicit loop-declaration check rejects SystemVerilog-local
  `for (integer ...)` syntax and is validated against that negative control.
  Verilator 5.050 and Icarus accept this extension despite their Verilog-2001
  mode, unlike Quartus; simulator language flags alone do not catch this bug.
- Exact extracted trimmed integration blocks: user-port idle, host UART
  RX/TX/RTS/DSR-to-DTR for UART modes 0–4, no MT32 info requests, unchanged
  VGA RGB, stereo EASC/CD sum and saturation. The actual original shadowmask
  module at unity gain is the five-stage RGB/VS/HS/DE latency oracle; randomized
  forced blanking and sync transitions are included. OSD is downstream and
  untouched; full HDMI/OSD hardware operation is not simulated here.
- Actual audio_out with real DC blockers, mixers and output transports:
  48/96 kHz sample cadence, full startup mute duration, signed/unsigned center
  and extrema, stereo isolation, input stability/glitch rejection, CE holds,
  asynchronous reset, filter-rate independence, DC arithmetic, attenuation,
  boost and cross-channel/Linux mixing. Transport activity is checked, not
  end-to-end decoded I2S/SPDIF fidelity. Mixer arithmetic is unchanged and is
  reused as a wiring reference; DC arithmetic has a separate fixed-width model.

The IIR bypass intentionally changes frequency response. It retains signed
sample conversion and registers the stereo pair on sample_ce; DC blockers
consume the previous registered sample. IIR coefficient/rate inputs no longer
affect this path. Startup gate a_en1 opens after four output samples; a_en2
retains the original 8193/16385-sample mute at 48/96 kHz. Existing transport
clock generation, DC state behavior, volume and Linux-audio reset semantics
are not changed. The shadowmask bypass preserves all five clock stages and
framebuffer forced blanking before the unchanged OSD. Disabled macros are
presence tests: defining one to `0` still enables the removal.

Initial passing evidence: `/tmp/peripheral-toggles.7sdhrk4y` (actual exit 0),
5,000 port/shadowmask checks and 49,972 audio sample events, including explicit
startup-duration and glitch checks. Results print their unique evidence
directory and actual process failure is propagated. The default baseline is
pinned to the immutable revision shown above, not the current HEAD.
The subsequent Quartus parser correction changes only the new loop index's
declaration to module scope; the language-mode/negative-control checks above
were added to prevent recurrence. See the runner's latest evidence directory.
