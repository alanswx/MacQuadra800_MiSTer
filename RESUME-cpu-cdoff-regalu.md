# CPU tuning with a temporary CD-ROM-off build

## Hardware-tested checkpoint (2026-09-09)

Ordinary EK_ALU register destinations retire in S_PIPE_REGS, using settled
asynchronous register-file operands. This removes the following S_EXEC boundary
without changing in-order retirement or the registered memory completion path.

- AP base: 250813f; branch: cpu-regalu-capture-retire-20260909.
- Hardware-tested diff is preserved in the AP stash named
  "validated reg-ALU capture retirement, CD-off hw 0.4235".
- All eleven AP regression suites passed.
- Focused cached loop: 135,190 -> 122,788 cycles (-9.17%).
- Identical first-100 corpus: 35,714,377 -> 35,370,929 cycles (-0.96%).
- Hardware Speedometer 4.02 CPU Mix: 0.423 and 0.424 versus accepted 0.405;
  two-run average 0.4235 (+4.57%). One iteration of all ten CPU tests;
  no screenshots or remote input during either timed interval.
- RBF: /media/fat/_Unstable/MacQuadra800_CPU_regalu_CDoff_seed22_20260909.rbf
- RBF SHA-256: d36819550cedfd8584381fc5d52685d7171a027a66efab1b7335d8771bb24804
- RBF MD5: e229bd4b5b588568dfe9455fc1958fcc.
- Seed 22: 38,026 ALMs, 4,110 LABs (81 free), 24,293 registers,
  462 RAM blocks, 41 DSPs; CPU/SDRAM/HDMI setup +0.980/+0.746/+0.353 ns;
  worst hold +0.205 ns; zero setup/hold TNS.
- Results: scratch/perf_regalu_cdoff_seed22/speedo_result_actual_run1.png
  and speedo_result_actual_run2.png.

CDROM_OFF=1 was enabled only in an isolated build QSF, not the active project.
It preserves both hard disks and removes SCSI target 3/CD command/audio logic.
Matched synthesis estimates save 2,252 ALMs, 1,019 registers, 86,016 RAM bits,
and 23 DSPs. Feature removal is development headroom, not a CPU optimization.

After testing, MiSTer was returned to MENU and the disposable image restored:
 /media/fat/games/MacQuadra800/Speedometer402-upstream-test.hda
MD5 16790b0577e13b45782214433d34954b. Main was not replaced and still matched
dfb5937ba47720c3ae20abc8f381c462.

## Continuation (2026-09-12)

The dirty AP file now also selects register operands directly during decode
for common MOVE, arithmetic, compare, logic, unary, Scc, and MUL/DIV setup forms.
All eleven regressions pass. The first-100 corpus falls to 34,941,315 cycles
(-1.21% versus the hardware-tested checkpoint), with 1,900 matching architectural
field groups and zero real differences. The focused loop remains 122,788.

A four-site immediate-register bypass also passed every regression but saved
zero corpus cycles. It is removed from the current candidate and recoverable
in the AP stash named "passing regdispatch plus zero-gain immediate prototype 20260912".

Current isolated seed-22/CD-off synthesis tree:
 /tmp/MacQuadra800_regdispatch_20260912.ptmO3k
Current ap040_core.v SHA-256:
 a433214d9b776f8d4da9c824a39b638226e067c158de81b202ca1c3514a206f2
Require clean full-machine compilation and zero-TNS Quartus timing before
deploying a uniquely named RBF. This broader layer is not hardware-validated.
No changes in this continuation have been committed or pushed.
