# CPU recovery patches

Latest hardware-tested checkpoint: `cpu-sharedcompact-accepted-20260912.patch`,
CPU and integer-test delta from clean AP base
`250813f4bcec4467807a754279124b042feeeb89`. Parent reconstructed it and verified
core SHA `5ab7603019ab43ffb10bcdc5ef80086d2b0a5b515abd7fdd64d9adfaf0d0f3ff`.
See [the accepted compact checkpoint](../CPU_SHARED_DECODE_CHECKPOINT_20260912.md)
for its three 0.447 runs, timing-clean seed-23 RBF and exact source identities.

Experimental patch baselines and exact source identities are documented in
[the validation update](../CPU_VALIDATION_UPDATE_20260912.md#recoverable-source-snapshots).

`cpu-regdispatch-20260912.patch` preserves the exact hardware-tested CD-off
CPU source scoring Speedometer 4.02 CPU Mix 0.434 and 0.435.

Apply from a **clean AP68040 checkout**, not the parent project root, based on
`250813f4bcec4467807a754279124b042feeeb89`. Do not apply over the active dirty
experimental source. Reconstruction in a temporary checkout was verified to
produce `rtl/ap040_core.v` SHA-256:

`a433214d9b776f8d4da9c824a39b638226e067c158de81b202ca1c3514a206f2`

The patch is CPU RTL only. The measured FPGA used an isolated QSF with seed 22
and CDROM_OFF=1; the active full-feature QSF was not changed. Its preserved RBF:

`/media/fat/_Unstable/MacQuadra800_CPU_regdispatch_CDoff_seed22_20260912.rbf`

RBF SHA-256:
`1243ad4df9bb1331409caf557fb045ad2cf4ccf4bef3a71260a204862ecab6e7`

See `../CPU_OPTIMIZATION_LOG_20260912.md` for tests, timing, and screenshots.
These files have not yet been committed or pushed.
