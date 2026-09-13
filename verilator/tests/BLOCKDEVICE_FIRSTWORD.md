# Block-device first-word regression

The test connects the **actual SimBlockDevice C++ producer** directly to the
**actual scsi_cache RTL**. It does not model their handshake independently.
Only the unused GUI console constructor/destructor are stubbed; no CPU, NCR,
ROM, golden disk or guest boot is required. A generated 64KiB pattern disk is
private to the new output directory.

```sh
VERILATOR=/home/alans/verilator5/bin/verilator JOBS=4 \
sh verilator/tests/run_blockdevice_firstword.sh
```

Optional arguments are a new output directory and an alternate producer
source file, allowing the same test to compare pre-fix and fixed producers.
The wrapper refuses an existing output directory. Each run checks 1024 words:
cold sector0, cached sector0, sector1 in the same transfer, and sector80 after
window rebasing. The runner repeats at latencies1,40,16000 and requires actual
process success; logs report the first ACK edge, words0/1 and mismatch counts.

## Reproduction and fix (2026-09-12)

The original producer raised sd_ack and sd_buff_wr for word0 on the same
BeforeEval tick. scsi_cache was still in C_REQ on that edge and only enabled
its RAM write gate in C_XFER. Word0 was dropped; the following words remained
correctly aligned. The cache later replayed zero at word0, including on hits.
This is a simulator producer/receiver cadence mismatch, not evidence of a
68040 arithmetic or register failure.

The minimal simulator-only correction requires the existing ACK bit already
to be high before presenting a read word. ACK therefore gets one receiver
clock before word0. No new state, address/data packing, read latency setting,
write path or hardware RTL changes are required.

Actual baseline test: exit1,1024 word checks,3 mismatches (only word0 of cold
sector0, its cached repeat, and cold sector80). ACK-edge trace: first_wr=1.
Fixed test: exit0,1024 checks,0 mismatches at all three tested latencies.
ACK-edge trace: first_wr=0. Cold/rebase word0 and all following data match.

Evidence is preserved in `/tmp/scsi-firstword-proof.Z2MR3Q`:
`baseline/run.log`, `fixed/run.log`, `firstword_test.cpp`, and `fix.patch`.
Baseline/fixed producer copies remain separate. Fixed producer SHA256:
`dbc4dbca4cc9956663d22bfd708aa4d52eb399f08055e066a268b726256b70db`.

Complementary existing cache gates (including writes, prefetch, passthrough,
rebasing, targets and randomized operations):

```sh
cd verilator
make V=/home/alans/verilator5/bin/verilator tb_scsi_cache tb_scsi_cache_mbcd
```

Those existing benches already give ACK an edge before their first word,
which explains why they do not expose the old C++ producer mismatch alone.
The bounded full-machine ROM signature check remains a separate integration
gate; a passing first-word test does not claim that MacOS has booted.
