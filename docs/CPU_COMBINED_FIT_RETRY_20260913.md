# Combined overlap: fit failure and bounded retry

Candidate CPU SHA256:
`21d408fa9b2080e73957d6e64b641cc2758797895218a7639317b4ac04958700`.
Accepted source-only CPU remains `0c3a81bd...`, AP commit `7a0306c`, confirmed
Speedometer mean 0.458666667. No combined-candidate hardware result exists.

## Seed 24: failed routing

Tree: `/tmp/MacQuadra800_operand_combined_seed24.ntjCwN`.
Log: `output_files/build_20260913_092103.log`.
Full-machine Verilator compile succeeded after restoring the unchanged local
ROM input omitted during tree preparation. CPU/corpus/full-Sieve gates passed;
see `CPU_OVERLAP_FOLLOWUP_20260913.md`.

Quartus actual exit 3 after 12m09s. Analysis and synthesis succeeded, but
fitting failed: warnings 16684/16618 report routing congestion, followed by
errors 170143 and 11802. No RBF or valid final timing result was produced.
Failed-fit utilization is 37,977 ALMs and 4,022 LABs; these are provisional
placement figures, not evidence of a successful fit or recovered headroom.

## Seed 25: one unchanged-RTL retry

User authorized one alternate seed, then RTL simplification if it also fails.
Tree: `/tmp/MacQuadra800_operand_combined_seed25.uoAK8Q`.
The only QSF change is `SEED 24` to `SEED 25`. CDROM_OFF=1 and all timing
constraints remain unchanged. CPU SHA matches the candidate above.
Seed-25 QSF SHA256:
`7e8c0e892a7bf33c09ca471613b43625ca6d96d210a214d612904ceecc0bb58c`.

Luna owns the tracked build, started with
`bash scripts/build_only.sh --no-wait` after checking actual Quartus processes.
Parent observed active Quartus PID 2572589 and synthesis PID 2573217.
No active source edits, Main changes, disk writes or hardware programming.
Completion and final timing must be reviewed before authorizing deployment.

The unchanged source makes the existing correctness gates applicable; changing
placement does not establish timing success. If routing fails again, inspect
the new actual-opcode mux and boundary qualification fanout, simplify only
with equivalent queue/exception/forwarding behavior, then rerun correctness
and synthesis comparisons. Congestion warnings alone do not identify a
particular RTL net as the cause.
