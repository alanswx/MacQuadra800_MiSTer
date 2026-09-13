# Exact Sieve partial diagnostics

See [measurement definitions and results](../../../docs/EXACT_SIEVE_INTEGRATION.md).
These wrappers use the original 80-byte kernel, stop after its first original
outer pass, and check the independently derived array/count/guards. They do
not replace the full100 fixture or generate an absolute Speedometer score.

Use Verilator5 and the 68040-capable VASM. From an isolated repository copy:

```sh
export VASM=/tmp/wombat-vasm/vasmm68k_mot
export VERILATOR=/home/alans/verilator5/bin/verilator
export JOBS=4

# Real CPU/storebuffer/bus32/SDRAM path, chosen offsets0 and6:
sh scripts/fixtures/wombat_sieve/run.sh RESOURCE COMPLETE_AP_RTL /tmp/unique-integration 0 6

# Artificial AP16-bit path, all16 even offsets modulo32:
sh scripts/fixtures/wombat_sieve/run_ap_alignment.sh RESOURCE COMPLETE_AP_RTL /tmp/new-alignment
```

RESOURCE and COMPLETE_AP_RTL should be absolute paths. The AP RTL directory
must include support modules, not only ap040_core.v. Use a fresh output path
for every comparison. Run serially per source fixture tree: the integration
assembler uses a shared build/exact_sieve.bin; the alignment wrapper creates
its own isolated testbench beneath the new output path.

The alignment setup copies the existing program testbench and exact monitor,
then applies the tiny include/instance hook in ap-monitor-hook.patch. The
partial observer uses the existing monitor's independent oracle; the inherited
full100 observer remains fixed at the original base and is not used for this
relocated partial diagnostic. run_alignment_inner.sh is an internal runner,
not a command to invoke in this directory directly.

Both kernel entry and exit addresses relocate with the wrapper. Neither the
kernel bytes nor data/stack addresses change. The source-image identity check
also validates the NOP/RTS immediately following the kernel. Internal CPU
hierarchy is used for diagnostics only; no production RTL is modified.
