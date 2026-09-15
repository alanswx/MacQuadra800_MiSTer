# Optional CPU-development feature switches

The full-feature default remains unchanged. To opt into the trimmed build,
uncomment `source configs/cpu_development.tcl` in `MacQuadra800.qsf`.
Comment out individual assignments in that profile to restore features, or
leave the profile disabled and enable individual macro lines in the QSF.
Macro presence enables the removal: do not set a macro to `0` to restore it.

| Macro | Compile-time effect |
| --- | --- |
| `CDROM_OFF` | Existing CD-ROM target/audio removal; keep SCSI hard disks. |
| `MISTER_DISABLE_YC` | Existing composite/S-video encoder removal. HDMI/VGA remain. |
| `MISTER_DISABLE_MT32PI` | Remove MT32-pi user-port interface, synth return and LCD/info display support. Host UART/SCC remains. |
| `MISTER_DISABLE_SHADOWMASK` | Bypass CRT shadowmask processing; retain HDMI blanking, timing and OSD. |
| `MISTER_BYPASS_AUDIO_FILTER` | Remove output IIR filtering, retaining Mac EASC, sample conversion, DC blocking, mixer/volume and audio serializers. |

These switches buy implementation headroom, not CPU speed. Menu settings do
not remove instantiated hardware. The MT32 menu is unavailable in trimmed
builds; corresponding status-bit allocations must remain unchanged.
Audio filtering and analog composite output are intentionally different;
do not use the trimmed configuration to accept sound/video fidelity changes.

ALSA and adaptive scaler filtering were already disabled in the existing QSF.
Mac Ethernet/SONIC and floppy/SWIM have no substantial implemented controller
to remove. Host networking, CPU/MMU/FPU/caches, SCSI disks, SCC, EASC, ADB,
timers, main Mac display generation and HDMI OSD are not removed by this batch.

## Validation and measurement

Check both default and trimmed compilation, independent-switch combinations,
audio sample/reset behavior and coherent video/control tie-offs. Compare
matched synthesis reports using the accepted source-overlap CPU `0c3a81bd...`
and the same CD-ROM-off, seed-24 baseline before crediting savings to this
batch. Do not compare against a different CPU or count CD-ROM savings again.
Default-path preprocessing should remain equivalent when new switches are off.
Matched synthesis passed; full fitting and timing validation are pending.

Focused validation passed independently with actual exit 0:
`/tmp/peripheral-toggles.izwhdjly`. The three modified RTL files have identical
default preprocessed tokens to immutable baseline
`50ca69b4bbcc7f1ae4a407f6607ecc9e20d0ebbf`. All 32 combinations of the three
new macros, HDMI-off and framebuffer pass preprocessing checks (not full
platform elaboration of all combinations). Exact extracted integration
blocks pass 5,000 port/video checks; actual audio_out passes 49,972 sample
events across 48/96 kHz including reset, startup, sign, input stability,
DC arithmetic and mix/volume. Serializers are checked for activity, not
decoded end-to-end audio fidelity. See
`scripts/fixtures/peripheral_toggles/README.md` for reproduction and limits.

Initial trimmed synthesis caught a Verilog/SystemVerilog compatibility issue
in the new shadowmask loop. Its index now has a Verilog-compatible declaration;
no timing or behavioral change. Final tests include an explicit portable-loop
check and a negative control, because simulator language flags alone accepted
the construct Quartus rejected. Final sys_top SHA begins `c2e848e7`.

Matched synthesis trees are
`/tmp/MacQuadra800_features_seed24.UNORIQ/{baseline,trim}`. Both retain CPU
SHA `0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614`.
The baseline enables only the pre-existing CD-ROM-off development option;
trim adds the four selected feature removals using this profile. No timing
constraints, CPU pipeline, storage or guest device semantics are changed.

### Matched synthesis results (2026-09-13)

Both map runs completed successfully with exit 0. Baseline log:
`baseline/output_files/build_20260913_130935.log`; corrected trim log:
`trim/output_files/build_20260913_132100.log`, relative to the tree above.

| Resource | CD-off baseline | Trim | Saved |
| --- | ---: | ---: | ---: |
| Estimated ALMs | 37,604 | 36,243 | 1,361 |
| Combinational logic ALUTs | 58,430 | 56,209 | 2,221 |
| Dedicated logic registers | 24,316 | 22,996 | 1,320 |
| Total registers | 24,322 | 23,002 | 1,320 |
| Block memory bits | 3,446,620 | 3,435,654 | 10,966 |
| DSP blocks | 41 | 31 | 10 |

ALMs are synthesis estimates, not fitted utilization or proof of routability.
Full trim fitting is the next gate; no new hardware benchmark is claimed.
The baseline retains the original loop declaration inside its disabled branch;
the trim uses the corrected Verilog-compatible declaration. Default token
equivalence was verified, so this does not change the baseline logic.

CPU experiments remain separate. The combined-overlap CPU `21d408fa...` has
passed simulation but not FPGA fitting; do not silently adopt it with these
feature switches. No hardware deployment is implied by enabling the profile.
