# Whetstone memory consumers

P102 core, full original fixture, latency 3. Read-only profiling adds cycles
by the sequencer return state during S_MRD/S_MWR. Source saved at
scratch/whetstone_consumers_20260920/tb_cpu_whetstone.sv, matching the run's
recorded bench hash. Loop clocks remain exactly 31,784,029; stack, globals
and CODE3 captures match the earlier P102 run byte-for-byte. Numerical oracle
remains pending. This is attribution, not a CPU optimization.

| Return consumer | Read cycles | Write cycles | Percent of total loop cycles |
|---|---:|---:|---:|
| Ordinary operands (S_PIPE_SDONE) | 5,389,204 | 0 | 16.96% |
| Instruction-completing stores (S_NEXT) | 0 | 1,942,703 | 6.11% |
| FPU operand reads | 821,155 | 0 | 2.58% |
| FMOVEM transfers | 426,224 | 291,507 | 2.26% |
| FPU result stores | 0 | 485,749 | 1.53% |
| Return-address reads | 411,242 | 0 | 1.29% |
| UNLK reads | 279,767 | 0 | 0.88% |

All consumer counts sum to 11,422,774, exactly the S_MRD/S_MWR state total.
These counts include setup, prefetch arbitration and issued response time;
they are not exclusively RAM latency. Split-transfer states are outside this
partition. Counters cover the complete constructed fixture including its short
entry/exit; percentages use the loop count (650 cycles shorter).
Acknowledgement counters count sampled cycles, not guaranteed unique transfers.
Raw results and capture hashes: consumer_summary.json in the run directory.

Ordinary operand reads are the largest measured memory category. Next measure
which opcodes contribute before changing MOVE, arithmetic or compare paths.
Follow-up run scratch/whetstone_operand_opcodes_20260920 is active under exec
session 37417, using its own saved bench through the new --bench runner option.
It adds an opcode histogram only for S_MRD returning to S_PIPE_SDONE. Completion
and capture comparison are still pending.

Instrumentation is preserved as the unapplied
scripts/cpu/whetstone_consumer_profile.patch. The tracked bench was restored
before further work because the fit wrapper hashes all tracked Verilog files,
even testbenches; the Quartus source hash check passes. Neither bench is a
Quartus project input. Use --bench for further scratch profiling during the fit.
P102 Quartus remains active and all build inputs remain frozen.

## P106 read-line reuse screen

A scratch bench only prints the existing transfer/shadow counters; it leaves
P106 at 29,454,150 loop clocks and all three captures identical. Root verified
all RTL, fixture, ROM, flags and latency match, with only the bench differing.
Evidence: scratch/whetstone_full_p106_readline_20260921/instrumentation_check.json.

The shadow remembers the last data-read line and invalidates on every store.
587,712 subsequent reads fit that line, but only 264,130 observed wait clocks
lie in those reads: under 0.90% of the loop even if all could be removed.
This is an opportunity estimate, not a implemented buffer or predicted gain;
it does not model filling a whole line, physical tags or coherence overhead.
Do not prioritize this conservative last-read buffer over reducing operand
sequencing. Transfer totals: instruction 1,543,478 / 4,086,801 clocks; data read
2,767,871 / 6,968,936; data write 2,399,252 / 2,741,966.
