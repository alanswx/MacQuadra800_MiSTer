# P162 audit addendum — 2026-09-21

P162/P120/P151 full simulation integration is now root-audited. All 22 CPU
programs and four IRQ/replay programs pass with clean runtime logs; pipeline
handoff accounting balances; the architectural handoff trace exactly matches
the oracle; and every source hash in `identity.json` revalidates.

Evidence: `scratch/p162_full_integration_20260921/root_audit.txt`.

This qualifies simulation integration only. The P150 Quartus flow is still
active, and no P162 or P163 artifact has been fit or deployed. The hardware
Speedometer result therefore remains P120: five valid runs, median Mix 1.313,
mean 1.3124, invalid timers 0.

Next action remains to let P150 reach a terminal state, inspect fresh reports,
then choose and fit the exact combined candidate. Preserve the one-flow
machine-wide Quartus rule and the safe-shutdown hardware gate.
