# Working full-feature build evidence: 15a1449 write-queue MLAB

This bundle identifies the routed, hardware-tested working artifact from source commit `15a14497817ad8479bad91bf47d97e2163124d63` (short `15a1449`). It is the successful pre-age-shift build; later age-shift fit attempts are not represented here.

The source file `rtl/sdram_beat32.sv` has SHA-256 `6b49355a45b6e3d81d603d0542139a45854223c71c295ac8515c26cf5f9937ba`; `rtl/sdram.sv` has SHA-256 `f4994aeb153e69c9fd5893acf75c0d5744424f7f23683f89b917f6d921a2e7e0`. `tracked_build_inputs.sha256` is an exact copy of the full Quartus HDL/QIP/QSF/SDC/TCL input manifest. The archived pre- and post-build manifest checks passed.

The associated RBF is `MacQuadra800_interim_mac_wqmlab_15a1449.rbf`, SHA-256 `4687167a16beb4077b970bf1cb46f0ba08a2fac724d2367f5d91e1390045da6c`. The archived RBF and current `output_files/MacQuadra800.rbf` were independently hashed and matched. The hardware report records that same RBF copied to MiSTer with matching remote checksum and five valid Speedometer 4.02 runs (median Mix 1.828); it also records Ethernet, data CD-ROM, audio-control and normal-shutdown evidence plus explicit unresolved checks. See `../../../INTERIM_WQMLAB_HARDWARE_20260925.md`.

Quartus Prime 17.0.2 fitted Cyclone V `5CSEBA6U23I7`: fitter status Successful, estimated ALMs needed 40,651/41,910, 28,588 registers, and 509/553 RAM blocks. Full flow elapsed 37m37s. The fitter itself routed successfully, while the wrapper timing gate failed (`build.exit=1`): CPU setup −2.406 ns, SDRAM −0.697 ns, HDMI −0.426 ns; minimum hold +0.200 ns. Thus this artifact was hardware exercised under the project's explicit exploratory authorization but is not timing-clean.

Files here are compact copies of the map, fit, and STA summaries; the exact input hash manifest; normalized RBF hash; small cross-domain setup-path tables; and the queue setup/hold summary with endpoint coverage limits. Full logs/reports remain archived under `scratch/interim_mac_wqmlab_fit_20260924/` and `scratch/timequest_wq_interim_mac_wqmlab/`.
