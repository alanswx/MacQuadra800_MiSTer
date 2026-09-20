# P97 full-machine simulation

One all-ten, one-iteration Speedometer 4.02 run completed with Mix **1.270**.
Root-reviewed screenshot: scratch/p97_fullguest_20260920/tree/verilator/screenshot_f7231.png.
Machine-readable result and screenshot hash: scratch/p97_fullguest_20260920/results.json.

| Test | Rating |
|---|---:|
| Whetstone | 3.237 |
| Dhrystone | 0.803 |
| Towers | 0.882 |
| QuickSort | 1.187 |
| Bubble Sort | 1.189 |
| Queens | 0.792 |
| Puzzle | 1.080 |
| Permutations | 0.768 |
| Integer Matrix | 1.186 |
| Sieve | 1.577 |

This is 2.75% above the earlier P89 simulation's 1.236. P97 includes P96's
core, P90's MMU and the four-entry queue, so this comparison cannot attribute
the entire improvement to queue depth. It is not a hardware score or five-run
reproducibility result. The fitted P97 CPU slack is -0.682 ns.

Profile: 839,319,552 clocks / 257,051,623 opcode dispatches = 3.265 clocks
per dispatch, **not retirement CPI**. The bracket contains setup/completion
UI time and a completion tail; it is not a precise per-kernel bracket.
The old host's sb_full_request_samples assumes two entries and is invalid
for this four-entry queue. The timer observer file is empty; independent
timer validation was not captured. No invalid-timer dialog is visible in
the result screenshot, but that does not replace timer instrumentation.

After collecting the screenshot and stopping the profile, host quit was
requested on this authorized disposable-disk simulation to free resources.
This does not establish normal Mac guest shutdown. MiSTer remains untouched;
best verified hardware median is still P96's 1.211.
