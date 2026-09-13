# Full-ROM profiling diagnostic (not a CPU benchmark)

The accepted compact CPU (SHA256 beginning `5ab7603019ab`) repeatedly reads
SCSI LBA 0 and displays the question-mark disk in the full-machine simulator.
No full MacOS Speedometer 4.02 interval has been captured in this session.
This is separate from the passing RAM-path fixture and the isolated indexed-EA
candidate. No MiSTer hardware or production RTL was changed by these diagnostics.

## Reproducible bounded stop

Build in `verilator` using
`make -j4 V=/home/alans/verilator5/bin/verilator`. The system Verilator is too
old for this Makefile's warning flags; do not remove flags to work around it.
Copy the resulting Vemu, the verified fastboot ROM, and a fresh golden disk
into a new owned temporary directory. Run from that directory, in the foreground:

```sh
timeout 900 ./Vemu --headless --no-cpu-trace --disk ./run.hda \
  +rom=./quadra800-fastboot.rom.hex \
  --stop-at-pc 40807246,40807247 --max-cycles 1000000000 > run.log 2>&1
```

Latest actual exit: 0. Run directory `/tmp/MacQuadra800_romcmp_a7.BX8v89`.
Vemu SHA256 `e252b9eee7dde4be04fc28e584b0ae0af6501980e2138b5113549251b0ba3739`.
ROM SHA256 `045c02746b5f15f83132d33c5414f806e7b049f3bfe53a7bd0ecacb8e072d673`.
Golden disk MD5 `16790b0577e13b45782214433d34954b`.

The stop reaches ROM `CMPI.W #$4552,(A7)` at PC `40807246`, half-edge count
462523949. A7 is `003FF980`, TC `0000C000`, SR `2004`, overlay 0. Raw backing
RAM at the numeric A7 address starts:

```text
00 00 02 00 00 02 B0 5B 00 01 00 01 00 00 00 00
00 01 00 00 00 40 00 13 00 01 00 00 00 00 00 00
```

These match the golden driver descriptor except the first word, which should
be `45 52`. Since translation is enabled, this raw numeric-address dump alone
does not prove the logical stack contents. Establish mapping and the actual
CPU read result before attributing a SCSI, cache or CPU defect.

## Independently proven simulator handshake defect

A bounded regression connects the actual SimBlockDevice producer to the actual
scsi_cache RTL, without CPU, NCR or translation. The old producer sends word 0
on the same edge that ACK moves the cache from C_REQ to C_XFER; the RAM write
gate still sees C_REQ and drops that word. Baseline exits 1 with exactly three
word-0 mismatches among 1,024 checked words (cold sector 0, its cache hit, and
a new window at sector 80); sector 1 is intact. Requiring the previous ACK bit
to be high before emitting a read beat fixes all checks, including latencies
1 and 16000. This one-condition simulator-only fix is active; FPGA RTL is not
changed. See `verilator/tests/BLOCKDEVICE_FIRSTWORD.md` and run
`VERILATOR=/home/alans/verilator5/bin/verilator sh verilator/tests/run_blockdevice_firstword.sh`.
Existing cache regressions and a corrected full-ROM stop are pending separately.

Subsequent validation passed with actual exit zero: producer regression at all
three latencies, existing scsi_cache (279,315 checks) and MBCD suite, full-machine
build, and corrected ROM stop. New Vemu SHA256:
`35ba3ac8ecd9125e9a3ed1a11d27e55581d53d639a2715b903e41540fe5c298f`.
Run `/tmp/MacQuadra800_romcmp_a7.PLCU7S` reaches the same PC/cycle/configuration
but raw backing RAM now starts `45 52 02 00 00 02 B0 5B`, as expected.
A bounded boot beyond that comparison is the next integration check; no full
MacOS boot or CPU Mix profile is claimed yet.

The subsequent fresh-disk boot probe `/tmp/MacQuadra800_bootprobe.HKd1EJ`
completed its 900,000,000-half-edge bound with actual exit 0. Sector reads
advance well beyond LBA 0 (including LBA 26637 near the end). Parent visually
verified frame 800 as "Welcome to Macintosh" and frame 1000 as the Mac OS
"Starting up..." progress screen. This clears the earlier boot-sector loop,
but is not yet Finder or a Speedometer interval. Captures/log are preserved in
`scratch/profile_boot_fixed_20260912`. Next full-machine profiling run should
allow a longer boot bound and use in-place runtime controls for a CPU-only bracket.

## Diagnostic/tooling corrections

- The old STOP register dump incorrectly indexed `areg[7]`; that array contains
  only A0-A6. A7 is banked and must use `debug_a7` (SR-selected USP/ISP/MSP).
  The earlier `2F3C0000` A7 print was diagnostic garbage, not CPU corruption.
- Profiling TSV now records end PC/CACR/TC plus counts of cycles with I-cache,
  D-cache and translation enabled. End configuration alone cannot characterize
  a whole interval in which software changes those controls.
- Use `scripts/guest/sim_control_send.py EXISTING_STREAM "shot"` or
  `"profile start"` / `"profile stop"` to append controls in place. Atomic
  replacement leaves an already-open simulator reader on the old inode.
- Keep each simulator's cwd and screenshots in its owned run directory. Poll
  nested execution sessions until an actual exit; never treat outer tool
  completion as process completion. All ROM diagnostic processes above ended.

The current hardware speed checkpoint remains 0.447, not a new simulated score.
