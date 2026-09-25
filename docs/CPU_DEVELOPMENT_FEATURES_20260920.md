# CPU development builds with CD and Ethernet omitted

The user proposed temporarily removing Mac features to ease fitting during
CPU development, including Ethernet. The next development recipe sets both
`CDROM_OFF=1` and `ETHERNET_OFF=1`. The first such build keeps the qualified
P63 CPU unchanged; P64's MOVE change remains a subsequent experiment.

The existing top-level switches propagate CDROM=0 through quadra800/iosb to
ncr53c96 and SONIC=0 into quadra800. CDROM=0 removes SCSI ID3 and its audio
engine while preserving both hard-disk targets. SONIC=0 removes the Ethernet
front-end and DMA master. The CD OSD mount line may remain visible, but it
has no working target. No guest software, disk image, timer, CPU frequency,
RAM size, CPU cache configuration, or video feature is changed by this patch.

An earlier CD-disabled build saved approximately3036ALMs; this is historical
context, not a measurement or fit-time promise for the current design.
Ethernet savings and the combined current-build savings remain unmeasured.

Prepared, not applied:
- `scripts/cpu/development_no_cd_ethernet.patch`: only the two QSF switches.
- `scratch/p63devnocdnet_fit_20260920/run.sh`: exact P63 CPU/ALU/pipeline/divider
  preflight, requires both switches, writes DEVELOPMENT ONLY to FEATURES.txt,
  and uses p63devnocdnet in archive/artifact names.

Do not modify the QSF until the current full-feature P63 wrapper is terminal,
including cross-domain timing and archiving. Inspect that result first, then
apply the patch, commit/push, and launch exactly one Quartus flow. The patch
passes git apply --check and the prepared wrapper passes bash -n. Neither
check substitutes for synthesis, fitting, boot, or benchmark validation.

Keep development results labeled with both feature omissions. Compare five
fresh valid Benchmark Mix runs at33MHz/32MB, recording timer anomalies,
bitstream/source hashes, fitted resources, timing, and clean boot/shutdown.
There is no CD/Ethernet regression claim for a build omitting those features.

Before final acceptance, restore both feature switches, fit and meet release
timing, repeat the hardware speed/boot/shutdown checks, and run the required
restored-feature regressions. A reduced-feature score is a development
milestone, not completion of the full-feature objective. A/UX remains deferred
to Dani by the user's instruction.
