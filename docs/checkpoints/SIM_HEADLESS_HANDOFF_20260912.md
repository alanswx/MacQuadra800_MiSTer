# Optional headless control and dispatch profiling

Source fixture: `/tmp/ap040-toggle-sim.XjvmAu/verilator`.
This now contains both the toggle observer and optional local control support.
No active repository source, generated build tree, fitted source/RBF, FPGA,
ROM or guest disk was changed. No linked simulator/guest workload was run.

Final sim_main SHA256:
`7ebbe53f5fdc70ce92fe3aa70b2c64a473743a6dfbb8928812111a5f062c53e6`

Combined diff against original active dirty source: `combined-sim.diff`
SHA256 `87987fbdb085504fa4c850cdd12fdfb5ad51d4fe4a00b4585307140988b8795c`.

Controls-only diff against the preserved toggle integration:
`headless-control.diff`, SHA256
`d679a05b31b93a677318728dcfaa1b452100afcfa36019dc333ec80e3cd45b48`.

The earlier toggle-only `dispatch-toggle-sim.diff` is unchanged, with its
sim_main preserved as `toggle_only_sim_main.cpp` (SHA 883079ad...).
The active user sim_main remains SHA c0a33aa5...; the combined diff preserves
all existing profiler counters, TSV fields, options, and other user edits.

Combined source changes: sim_main.cpp plus new cpu_dispatch_observer.h,
sim_control.h, tests/cpu_dispatch_observer_test.cpp and tests/sim_control_test.cpp.
Use a fresh assigned simulator tree with accepted toggle-bearing CPU RTL,
copy all these files, and rebuild sim_main.o. Existing outer Makefile header
dependency limitations mean a clean/reforced C++ rebuild is required when
either new helper header changes. Do not use these sources with the active
memory-retirement CPU alone: it lacks perf_dispatch_toggle.

## Invocation and command protocol

Add these options to the SAME simulator/ROM/disk/application configuration
already selected for the exact Speedometer workload:

```text
--headless --no-cpu-trace --control /tmp/selected-controls.fifo --cpu-profile /tmp/selected-profile.tsv
```

The specified path must already exist as a regular file or FIFO. No path is
created automatically; there is no socket/network listener. Without --control,
no stream is opened and no control-generated guest input occurs. Headless
pixel rendering and the existing screenshots work without an SDL window/Xvfb.

One command per newline, case-sensitive; blank lines and # comments allowed:

| Command | Meaning |
|---|---|
| `down 1c` / `down 0x1c` | Press PS/2 set-2 code 0x1c |
| `up 1c` | Release that code |
| `down 75 ext` / `up 75 ext` | Extended set-2 key event |
| `wait 3300000` | Insert 3,300,000 complete simulated rising-edge waits |
| `shot` | Capture at the next frame boundary; block later commands until capture |
| `profile start` | Same start request as SIGUSR1; clears/includes its sampled edge |
| `profile stop` | Same stop request as SIGUSR2; dumps/excludes its sampled edge |

Profile commands require --cpu-profile FILE. They otherwise report an error.
Screenshots retain existing names `screenshot_f<frame>.png` in the simulator's
working directory. PNG failure is reported rather than printing false success.
No helper changes benchmark settings or auto-selects a different application.
Use screenshots to inspect the existing guest state before navigation.

For example, to issue the guest's Command-O after confirming its selection:

```text
down 11
down 44
wait 3300000
up 44
up 11
wait 33000000
shot
```

These codes are verified against rtl/adb.sv: 0x11 Left Alt maps to Mac Command,
0x44 is O, 0x32 is B, 0x5a is Return, 0x76 is Escape, 0x0d is Tab,
0x12 is Shift, 0x29 is Space. Use Command-B only to open Speedometer setup;
inspect selection/iterations before Return. Every down should have its up.

At nominal 33 MHz, 3,300,000 waits represent about 100 ms of guest time;
main_time counts both clock edges, while wait counts rising edges. Commands
also respect the existing SimInput keyEventWait=50,000 rising-edge gap.
The interval begins only after preceding queued keys/pacing finish. A wait N
inserts N idle clocks after its acceptance; the next command can execute on
the following clock. Input service runs before eval, so the profiler request
from a control command is sampled by prof_step after that same rising edge.

## Bounds and I/O behavior

The reader opens O_RDONLY|O_NONBLOCK|O_CLOEXEC. It polls every 16,384 simulated
rising edges, consumes at most 1,024 bytes per poll, retains a 512-byte read
buffer, caps lines at 160 characters and parsed commands at 64, and accepts
at most one command per simulated rising edge. No blocking host sleeps occur.
Regular files can be appended at EOF; FIFO writers may disconnect/reconnect.
Unterminated lines remain pending. Queue backpressure retains unread input.
Malformed/overlong lines are dropped with an explicit rejection count.
No paths, shell strings, or arbitrary commands are accepted inside the stream.

Control events go through the existing SimInput.keyEvents/BeforeEval path,
including its PS/2 toggle and timer, then the normal RTL PS/2-to-ADB translator.
The previously missing input.ps2_key pointer is now wired to the actual
simulated ps2_key input. No separate guest keyboard implementation was added.

The parser/scheduler pause command execution during reset and while a shot
awaits a frame. File polling remains bounded during the pause. PNG capture
occurs immediately after video.Clock increments count_frame, before a new
visible frame can overwrite the completed image.

## Actual CPU reset proof

This simulator has no extra CPU reset gate: verilator/sim.v line 125 connects
machine.nreset(~reset); rtl/quadra800.sv line 218 connects cpu.nreset(nreset);
rtl/wombat_cpu.sv line 159 connects core.nreset(nreset). The CPU nresetout is
unconnected in quadra800.sv line 254, so the RESET instruction's peripheral
reset output does not reset the core. Thus VERTOPINTERN->reset is exactly the
inverse of the actual AP nreset for this simulator, including GUI/core reset.
Hardware top-level power/reset-controller wiring is not instantiated here.
If the simulator wrapper later gains another reset gate, update the observer
to that actual combined reset and retain machine-cycle counters separately.

The continuous observer and profile/trace sampling contract remain documented
in HANDOFF.md. Generated signal path is:
`SIMEMU->machine__DOT__cpu__DOT__core__DOT__perf_dispatch_toggle` (no __PVT__).
It counts actual opcode loads, not completed/retired instructions.

## Checks and Luna handoff

Both helper tests passed with g++ -std=c++11 -Wall -Wextra -Werror:

- observer_test: repeated PC/state events, held-toggle ce stalls, reset, start,
  stop, simultaneous requests, disabled consumers and reset-spanning requests.
- control_test: optional/no-input default, partial/CRLF/comment lines, numeric
  validation, overflow and overlong-line rejection, queue backpressure, exact
  wait/pause order, FIFO with no writer, writer reconnect and append-at-EOF file.

The final full sim_main passed C++17 syntax-only compilation against the
existing shared-decode generated headers, without writing to that build tree.
The combined diff passed reverse --check. Test programs create only their own
mkdtemp fixture and remove those owned FIFO/file fixtures on success.

Next delegated validation is a clean linked simulator build, then a bounded
headless guest smoke check: request a frame, verify key press/release reaches
the existing ADB path, and verify profile bracket output. Do not launch a long
benchmark until the parent assigns the exact workload/state. No FPGA operations.

No commits or pushes.
