# Latest: P89 directed invalidation and corpus pass

P89 four-copy remapping/flush/TC-disable fixture passes3phases. Monitor requires
four simultaneous data copies, reports4765fullcycles/3populatedflushes/84clears.
Final negative_flush_data mutation leavesdata2/3 onPFLUSH, fails stalecopy2
after987fullcycles/1populatedflush. See guide for earlier rejectedcontrols.
First10060860exit0,1900groups0diffs /tmp/cpu-corpus100-gate.J5cwrR.
Fullintegration98466 LIVE, candidate/full.log, isolatedtree/scripts/cpu/pipeline_handoff.py
--out scratch/p89full --extended --memory-entry --p6 --loads --stores --pea
--xstore --lea --early-drain --compare. Candidate=scratch/p89_mmu_copies_20260920.
Matching remapped Sievebaseline73131 LIVE, scratch/sieve83_remap8_20260920.
P83fit verifiedactive MainPID2890999; production frozen untilfullarchive/STA.

# P89 MMU gate completed

Session62648exit0: t_mmu,t_bitfield_mmu,t_atcprobe,t_moves_fc,t_exceptions
allPASS with candidateMMU and productionP83pipeline. No live MMUtest session.
Further qualification required: targeted multi-copy invalidation coverage,
full integration/corpus, then area/timing fit afterP83 archive. Do not promote yet.

# Latest: P89 translation-copy candidate has substantial simulation gain

P89 isolated MMU scratch/p89_mmu_copies_20260920/ap040_mmu.v, unapplied
scripts/cpu/mmu_translation_copies.patch. Four direct-mapped copies per space,
existing invalidation/permission rules. Matrix8K3638968→2870854 (-21.11%),
Matrix4K3771795→3126068 (-17.12%), Quick8K178573 unchanged. All oracles pass.
RemappedSieve8K286818 flags/poisonedpage guardsPASS; matching baseline pending.
New --mmu-module harness override and overlapping PIPE_READ_BLOCKERS counters.
MMUgate session62648 LIVE: scripts/cpu/mmu_candidate_gate.py --mmu-module
scratch/p89_mmu_copies_20260920/ap040_mmu.v --out
scratch/p89_mmu_copies_20260920/mmu_gate. Icarus real-core t_mmu,
t_bitfield_mmu,t_atcprobe,t_moves_fc,t_exceptions across default3phases.
Collect terminal status; do not claim qualified before regression/fullgates.
P83fit stillverifiedactive MainPID2890999, production frozen, operator monitors.
No hardware approval answer; no transfers. Besthardware still1.133P70.

# Latest screen: P88 rejected; P83 fit remains active

P88 fast indexed multiply retirement: Matrix3638968 unchanged versusP83,
despite retire_gap64000→0. Independent full32product/CCR oracle128cases×3
phases PASS with384 launches/retires. No full qualification needed: reject
zero-gain combinational retirement path. Sources/logs scratch/p88_fast_multiply_20260920
and scratch/matrix88_fastmul_20260920. No live simulation sessions.
P83 unit verifiedactive MainPID2890999; cheaperoperator still monitors.
Production remains frozen. Next broader lead is load/address scheduling;
load_req already includes combinational load_issue and hint_p2 already uses
that address, so merely exposing load_issue earlier cannot improve it.

# Current running work

P83 fit launched from66f0d5f, userunitq800-p83devmemadd-fit-20260920.service,
MainPID2890999 verifiedactive. Cheaperoperator monitors entire archive and
CPU STA. Freeze RTL/QSF/QIP/SDC until all finish. No active benchmark sessions.
P87 scratch prefetch thresholds2/4/6: Matrix3702936/3638968/3638968, alloracles
PASS; reject (regression/no gain). No production changes from this screen.

# Latest: P82 archived; P83 promoted for next fit

P82 wrapper and detailed STA terminal; root checked artifact hash, reports,
source/cross/STA exits0 and RAM inference (ctag M10K44032, bankE MLAB512).
Artifact SHA111b8cc379fa3adf5d831ee0137e8ffbc8d8789580f3ef6e6532f339b7e0adea.
39458ALMs94%,25355regs,483RAM,42DSP. CPU-.322/TNS-2.936,HDMI+.016,
SDRAM+.823,holdmin+.244; sys/RAM+2.408/+0.847. Experimental timing failure.
P83 qualified source promoted unchanged, core remainsP78. Wrapper prepared at
scratch/p83devmemadd_fit_20260920/run.sh; launch follows this commit.

New profiler validated session59789exit0; Matrix P82/P83 cycles unchanged,
all results pass. Multiply reads spend64000 setup and64198 prefetch-wait cycles,
versus almost none for other pipeline reads. See microbenchmark guide table.
Hardware transfer approval remains pending; no deployment performed.

# Latest: P83 qualified; P84–P86 screens rejected

P83 fullintegration51751exit0 and finalPASS; all planned simulation gates complete.
PreparedUNLAUNCHED scratch/p83devmemadd_fit_20260920/run.sh. P82stilllivefit,
wrapper2848075/fitter2857951; A&S42DSPs (oneextra),25377regs,3675406RAMbits.
ProductioncoreP78e2493f18/pipelineP82d57480d0 staysfrozen.

P84CMPIbyte/wordrelativeP83: Matrix3643769 vsP83 3638968, regression4801;
Bubble3394944unchanged. P85d16CMPmodulealone Bubble/Quickunchanged but no
newpipelineissues: lookaheadbypassesitsadmission. P86scratchcorepairsP85module
withmatchinglookahead/lateextensionadmission, Bubble3522604 vsP83 3394944,
+3.76%regression despiteissues748500→873749. BothoraclesPASS, nofullgates.
P86oldP82modulecontrol3397855 includesextraadmissioncost; NOTtruebaseline.
Allthree rejected/notpromoted. Scratch directories p84_immediate_compare_20260920,
p85_displacement_compare_20260920,p86_displacement_compare_entry_20260920.
No pendinglocalbenchmark sessions. P82fitonlylivework pluscheapoperator.
HardwareexactP75transferapprovalstillpending; noMiSTerchanges, best1.133P70.

# Latest: P82 fit live; P83 ADD partial qualification passes

P82 launched userunitq800-p82devindexmul-fit-20260920, wrapper2848075 verifiedactive,
commit68ae0da. ProductioncoreP78e2493f18/pipelineP82d57480d0 frozen until whole
wrapperarchive/STA ends. Cheaperoperator monitors; no hardwareapprovalyet.

P83pipeline152c494eabea6e8fe121de543b0af11fcde5174b8337dcee7ebfed1940cae360
scratch/p83_indirect_add_20260920/ap040_pipeline_integer.sv, patchrelativeP82
scripts/cpu/indirect_add_pipeline.patch unapplied. Matrix3638968lat3 vsP82
3702562(-1.72%); Quick178573/Bubble3394944unchanged. AlloraclesPASS.
Semantic28143exit0:27998retirements/7536reads in8modes,65536opcodemap incl192ADDs.
TargetedADDbyte/word/longbusfaultsPASS3phaseseach withforcedtestadmission;
initialcoldfixturecoverage0 discarded. IRQ/replayall3sizesPASS3injections/
3cancelseach, savedPC60a/SR2011, result6 andyounger32incrementscorrect.
Corpus56303exit0,1900groups0diffs /tmp/cpu-corpus100-gate.rcNF3h.
Fullintegration51751stilllive, logcandidate/full.log, outscratch/p83full.
Firstcommandinthat sessionwas successfulIRQtests; thenfullintegrationstarted.
Collectterminalexit andreviewbeforequalification. No P83promotionyet.

# Latest: P78 archived; qualified P82 promoted for fit

P78artifact scratch/p78devdispread_fit_20260920/MacQuadra800_p78devdispread_7fffdf4.rbf,
4510196bytes, SHA2dff8e0c80318f3658fc62ddcf707890a0efcdb93854176b228c8015d5d43cfd.
Root reviewed source/cross/detailedSTAexit0, buildexit1timingonly, healthy
cachetagM10K44032/regfileMLAB512. Fit39488ALMs94%,25407regs,483RAM,41DSP.
CPU-.661/TNS-11.391,HDMI+.229,SDRAM+.605,holdmin+.246;
crosssys→RAM+2.564/RAM→sys+.918. WorstATCvalid114→epf_data[7][7].
NoQuartusprocessesremain beforepromotion. P82pipeline d57480d0... nowproduction,
pairedunchangedP78coree2493f18..., baseline925bbeadivider. Preparedwrapper
scratch/p82devindexmul_fit_20260920/run.sh nextlaunch(notyetatthiscommit).

P83isolatedscratch/p83_indirect_add_20260920/ap040_pipeline_integer.sv adds
ADD (An),Dn byte/word/long to orderedload + existingALU, no entrypolicychange.
MatrixMMU8Klat3 3638968 vsP82 3702562 (-1.72%), alloraclesPASS.
Semanticoracle28143running, fullqualificationnotstarted. DoNOTpromoteP83yet.
P75exacthardwaretransferapprovalstillpending, no hardwareactions.

# Latest: P82 simulation-qualified for fit; P78 still building

P82corepairedP78 e2493f18..., pipelined57480d0...; no production changes.
Fullintegration55662exit0, candidate/full.log endsPASS preciseIRQ/replay.
Corpus28578exit0:1900groups0diffs /tmp/cpu-corpus100-gate.7ftTeS.
Semanticoracle29358exit0:26638retirements/6384reads in8modes,65536opcode map,
all128multiply full/missing-extension rejection checks. Newopcode semantic
traces cover allbase/destregs and forwarding; decoderchecks independentset.
New multiplyIRQscript passesMULS/MULU3phases/injections/cancellations each,
correctstackedPC60c/SR/fullproduct andyounger replay. Initialcoldfixture killed0
so prefilledwith4NOPs, then demanded>=3kills (no relaxedassertion).
Negativeunsigned-only mutation failsactualguest arithmetic inall3phases.
Quick178573/Bubble3394944 unchanged; Matrix3702562 vsP78 4021727 (-7.94%).
PreparedUNLAUNCHED scratch/p82devindexmul_fit_20260920/run.sh guardsP78core
andP82pipeline. Canconsiderpromotion ONLYafterP78wholewrapper/archiveends.
P78fitter2818748 verifiedlive9m44elapsed; userunitq800-p78devdispread-fit-20260920.
No newhardwarepermission; P75 exacttransferapprovalstillpending. Operatoronly
monitorsfit. Besthardware remains1.133P70. Nextbroadpotential: pipelineindirect
ADD.W afterMatrixmultiply is now64000next-exits(opcoded452); reuseorderedload
plus existingALU ifscreened, notyetimplemented.

# Latest: P82 indexed multiply screen saves7.94% Matrix; partial gates only

P78 fit live q800-p78devdispread-fit-20260920, wrapper2808540, commit7fffdf4.
Productioncoree2493f18..., baselinepipelinee53cadf2..., frozen througharchive.
Broader P76→P78 Bubble3456611→3394944(-1.78%), Queens65181unchanged,
Permute1380669→1380668. AlloraclesPASS, MMUoff for these fixtures.
P81earlyregisterstores noBubble/Quickgain; notpromoted.

P82 scratch/p82_indexed_multiply_20260920/ap040_pipeline_integer.sv SHA
 d57480d06c7b982eb67a6ca4e024ebcb9b5c5af6e222abd4628c60e6e4f6cb45,
pairedP78core. Unappliedscripts/cpu/indexed_multiply_pipeline.patch adds
brief-indexedMULS.W/MULU.W orderedload + registeredWB, explicitly nofastretire.
MatrixMMU8Klat3baseline4021727→candidate3702562, alloraclesPASS,7.94%saving.
Source/results scratch/matrix82_mmu8_20260920/current andcompare.
Independent128full32bitproducts+CCR cases PASS3phases,384pipeline launches/
retirementsrequired; alignedfixture oracle_aligned (initialunalignedcoveragefailed).
DirectedpipelineMULS/MULUbusfaultsPASS3phaseseach,precise state unchanged.

Next: complete decoder-map/oracle integration and interrupt/replay qualification,
negative control, broader kernel screens, first100corpus withmodifiedpipeline.
DoNOTpromote basedonMatrixlow16resultsalone; neworaclefull32covers arithmetic
but is notfullqualification. CorelateextensionwaitingdoesnotrecognizeMULyet;
unaligned/coldfallbackremainscorrectbutmaylimitcoverage/performance. No need
change it merely to inflatecoverage: alignedoraclealreadyforcesall128cases.
P75exactartifacttransferapprovalstillpending; hardwareoperator soleowner,
currentlyonlymonitoringP78. Besthardware1.133P70 unchanged.

# Latest: P76 archived; qualified P78 promoted for next fit

P76 terminal: fit39448ALMs94%,25375regs,483RAM,41DSP. CPU-.621ns/TNS-6.649,
HDMI+.412,SDRAM+.786,holdmin+.098. Crosssys→RAM+1.517/RAM→sys+.574.
Buildexit1timingonly; source/cross/detailedSTAexit0. HealthycachetagM10K44032,
regfilebankE MLAB512. Artifact scratch/p76devimmstore_fit_20260920/
MacQuadra800_p76devimmstore_c0e4c5d.rbf SHA
5fab620aeb38196c968f44eac74093bad15f1aa3e77abbc63dca4faddd474022,
4522928bytes; detailedworstATCvalid[8]→epf_data[6][14]. Rootreviewed.
No deployment; P75exacttransferapproval stillpending; operator hardwareidle.

NoQuartusprocessesremain. P78productionpromoted coree2493f18... after complete
qualification. Nextlaunchpreparedscratch/p78devdispread_fit_20260920/run.sh,
userunitq800-p78devdispread-fit-20260920. NOTyetlaunchedatthiscommit.
Baseline divider,64byteprefetch,seed22,CD/Ethernetoff,unchangedstorebuffer.
P79MOVEA.Wadmission no gain, rejected. P80fullqueue turnover tiny gain,
notpromoted; patchandmicrobenchmarkmoduleoverride retained forfuturetests.

# Latest: P78 fully simulation-qualified; P79 MOVEA.W admission screen

P78 fullintegration session71144 collectedexit0; final log allIRQ/load/store/PEA
replayPASS. Corpus45496alreadyexit0/1900groups0diffs. DirectedAn/PC-relative
faultsPASS. P78 ready to consider for nextfit after P76wholewrappercomplete;
preparedscratch/p78devdispread_fit_20260920/run.sh stillunlaunched.

P79 isolatedscratch/p79_moveaw_entry_20260920/ap040_core.v changes ONLY admission
relativeP78: registerMOVEA.W ((ir&f1f0)==3040) withsupported successor may
enter existingpipeline. ExistingwordMOVEAsemantics unchanged. Matrixsession72261
and Quick/Sieve48357screensrunning. No correctness/fullqualification yet.
P76stillsoleliveQuartusfit, productionfrozen. P75transferapprovalstillpending.

# Latest: P78 corpus passed; P75 exact transfer approval pending

P78corpus45496exit0: first100,1900fieldgroupsmatch,0diffs;
/tmp/cpu-corpus100-gate.xR0fZ4. Fullintegration71144stillliveatloops_irq.
Prepared UNLAUNCHED wrapper scratch/p78devdispread_fit_20260920/run.sh;
no promotion beforefullgateandP76wrapper/archivecompletion.

Operator finally confirmed P75 copy rejectedTWICE, nevercopied/launched;
MiSTer safelyhalted. Async approval question now pending for exactP75artifact
MacQuadra800_p75devclear_d90c597.rbf to verifiedmister.local10.3.89.233 and
disposable-disk tests. No hardware retry until answer. Operator instructed
monitorP76only whileapprovalpending. Localworkmaycontinue. P76active at
11:49:52,wrapper2759726/fitter2769012. Production stillfrozenP76.

# Latest: P78 displacement-read screen and directed faults pass

Isolated P78 core SHAe2493f18064f04bae36e458d3ebf02af05bf148f1decca5a41f170596464c0d8,
scratch/p78_displacement_read_20260920/ap040_core.v. PatchrelativeP77 at
scripts/cpu/displacement_read_early.patch, unapplied. MatrixMMU8Klat0/3/8
3989767/4021727/4095793 (3.08%fewerlat3cyclesvsP76); Quick178573(-0.24%);
Sieve289371unchanged. AlloraclesPASS. DirectedAn/PC-relativeMULS/MULU/DIVS/DIVU
busfaultsPASS3phaseseach, with extension-offer delay to force actual shortcut.
Initialfaultfixture architecturalchecksPASSbutcoverage0; superseded by
precise_delayed_extension andprecise_pc_relative results.

Full integration session71144 currentlylive, candidate/full.log, outscratch/p78full.
Note first command in session wasinitialcoverage-failingfixture; fullgate then
launched separately on nextshellline. Terminal sessionexit reflects fullgate.
Corpus session45496live, candidate/corpus.log. Collectbothbeforequalification.
P77fullyqualified, preparedfitwrapperunlaunched; P76stillsoleliveQuartusflow,
fitter2769012verified10minelapsed. ProductionP76frozen throughfullarchive.
HardwareoperatorstillownsMiSTer, lastreviewedP75transferstatusunresolved;
no newhardwaremeasurements. BesthardwareP70median1.133.

# Latest: P77 full qualification complete; P78 screened next

P77 full integration34258 collectedexit0, full.log endsPASS including all
precise faults/IRQ/replay. First100corpus already1900groups0diffs; directed
indexed sequencer MULS/MULU/DIVS/DIVU faults alsoPASS. P77 can be considered
for fit once P76 full wrapper and archive/cross/STA finish. Prepared UNLAUNCHED
wrapper scratch/p77devindexread_fit_20260920/run.sh with corehashba7e8325...
P76 still sole live fit; production remains P76 and frozen.

P78 scratch/p78_displacement_read_20260920 adds early d16-source read/hint
on top of P77, not production. Matrix screen session2320 running.
Operator interrupted/reassigned to report pending hardware command/handle
because repeated status requests went unanswered. No root hardware inputs;
operator retains sole ownership; do not repeat any unverified pending action.

P77 corpus terminal update: session48930 exit0, all1900field groups match,
0real diffs in first100only (/tmp/cpu-corpus100-gate.b3fISZ).
Full integration34258 still live, current loops_irq test at last check.

# Latest: P77 indexed source-read screen improves Matrix; gates running

P77 isolated core scratch/p77_indexed_read_20260920/ap040_core.v SHA
ba7e8325100d09a8d9badc585386008b3d2a57cd4a79c5d6f5033658aacb9e84.
Patch scripts/cpu/indexed_read_early.patch relative to P76, unapplied.
Early brief-index source mrd plus hint for register destinations; Matrix
MMU8Klat0/3/8 4053766/4085726/4159792, saves1.54% atlat3 versusP76.
Quick179011/Sieve289371 unchanged; all output oracles pass.
Directed MULS/MULU/DIVS/DIVU busfaults passed three phases each with direct
shortcut coverage and precise exception state checks.

Active full integration session34258, log scratch/p77_indexed_read_20260920/full.log,
out scratch/p77full. Active corpus session48930, log candidate/corpus.log,
ARTIFACT_DIR=/tmp/cpu-corpus100-gate.b3fISZ. Collect terminal exits and examine
logs before qualification/promotion. First corpus launch only failed missing
experimental module; supplied unchanged module and restarted gate, not CPU failure.
P76 fit still live userunit q800-p76devimmstore-fit-20260920; fitter2769012.
Root production inputs remain frozen. Operator remains sole MiSTer input owner;
awaiting reviewed P75 transfer status, no new hardware result yet.

# Latest: P76 fit live; original Matrix microbenchmark validated

P76 fit launched userunit q800-p76devimmstore-fit-20260920.service,
buildcommit c0e4c5d, wrapper PID2759726 verified active. Build inputs frozen.
Cheaper operator investigating reviewed P75 transfer retry after verifying
mister.local identity; no root hardware inputs. No P75 scores recorded yet.

New profile_matrix.py/shared profile_quick.py runs original CODE3 5dda..5e2d
40-term dot product1600times, deterministic signed inputs, independent full
B*A word-result oracle and input/guard checks. P75/P76 MMU8Klat0/3/8:
4117756/4149716/4223782 versus4117755/4149715/4223781, negligible improvement.
All PASS; no-accumulation negative control fails at index0 as intended.
Quick/Sieve regression179011/289371 unchanged. Evidence scratch/matrix{75,76}_mmu8_20260920.
Profile priorities and limits documented in docs/SPEEDOMETER_MICROBENCHMARKS.md.
Memory-read state34.51%, pipeline register/start23.63%, MDwait6.17%; do not
interpret as independent stall fractions. Indexed MULS causes64000pipeline
exits. Next candidate should target repeated operand/entry overhead, rather
than assume immediate stores improve Matrix. Best hardware still1.133P70.

# Latest: P76 promoted for fit; P75 hardware pending

P75 fit completed; no Quartus processes remained before P76 promotion.
Archived artifact: scratch/p75devclear_fit_20260920/MacQuadra800_p75devclear_d90c597.rbf,
SHA256 16780ee2cd5d041fda4166349e5dfc63bb775c7227c1a57b19a830e1774a5c33,
4,501,268 bytes. Source/cross/detailed-STA checks exit0. Fit39,328 ALMs (94%),
CPU setup -.963ns, HDMI -.050ns, sys→RAM +.896ns, RAM→sys +1.184ns,
minimum hold +.242ns. Experimental only; not release timing. Hardware copy
was rejected by automatic approval review for unverified destination/payload.
Operator subsequently verified mister.local resolves to10.3.89.233, hostname
MiSTer, and slot points to the authorized disposable pipeline-test HDA.
No P75 deployment or scores yet. Best reviewed hardware remains P70 median1.133.

P76 production core now a3e649df27fb47da3685a09e937931c9418dd091352ded665962d06caa6cd7ce:
P75 plus immediate MOVE in early destination store and matching hint.
Full integration log ends PASS at scratch/p76_immediate_store_20260920/full.log;
corpus and directed fault checks also passed as recorded below.
Prepared wrapper scratch/p76devimmstore_fit_20260920/run.sh is next to launch
as user unit q800-p76devimmstore-fit-20260920. Baseline divider,64-byte refill,
seed22, CDROM_OFF and ETHERNET_OFF; development only.
Freeze production build inputs from launch through full wrapper completion.

# Latest: P76 full simulation qualification complete

Fullintegration13131collectedexit0,allfault/IRQ/replayPASS. P76canbeconsidered
fornextfitafterP75completes, notbefore. Preparedwrapper
scratch/p76devimmstore_fit_20260920/run.sh (unlaunched); corehasha3e649df...
P75stillsoleliveflow, fitterPID2725520 atlastcheck, userunit
q800-p75devclear-fit-20260920, frozenproduction. Hardwarebestmedian1.133P70.

# Latest: P76 immediate-store candidate screened; full gate pending

P76=P75+early immediateMOVE store andmatchinghint, scratch/p76_immediate_store_20260920.
Corea3e649df27fb47da3685a09e937931c9418dd091352ded665962d06caa6cd7ce.
SieveMMU8K283361/289371/378634lat0/3/8, alloraclesPASS; -2.75%vsP75lat3,
-7.40%vsP64. QuickMMU8K179011unchanged; Bubble3456611(onecyclesaved).
Corpus18427exit0,1900groups0diffs /tmp/cpu-corpus100-gate.zHbI2u.
Fullintegration13131live, scratch/p76full/full logcandidate/full.log; collectexit.
Directedimmediatefaultsnegative/zero/positive,baselinecontrols,andCLRallPASS.
Patchscripts/cpu/immediate_store.patchrelativeP75. NOTpromoted.
P75 remainsproduction/liveQuartusflow q800-p75devclear-fit-20260920; frozen.

# Latest: CPU/RAM microbenchmarks now support real MMU translation

profile_quick.py/sharedSieve supports--mmu off/4k/8k and Sieve-only
--mmu-remap-buffer. WalkerandCPUshareoneRAMresponder; actualdescriptorU/M
updates exercised. Nonidentity4Kand8KmappingsPASS; disablingTCmutation fails
primeflagoracle. P75SieveMMU8K291552/297561/378635lat0/3/8; P64baseline
306551/312515/380103. AlloutputoraclesPASS,15walkreads/7writes each.
Detailedscope/evidencein docs/SPEEDOMETER_MICROBENCHMARKS.md.
QuickMMU8Klat3 session89505exit0:179011cycles,sorted/guardsPASS,12walkreads/6writes.
P75FPGA fit remainsactive, rootproductioninputs frozen. Operator monitors.

# Latest: P73 failed; P75 promoted for next fit

P73wrapperTERMINALexit3/sourcecheck0, routingfailure,39912ALMs95%, nofreshRBF
orSTA. Archivescratch/p73devshared_fit_20260920. NoQuartusprocessesafterexit.
Sharedselectorreducedareabutdidnotroute. DoNOTdeploystaleoutputbitstream.
P75 nowpromoted core8e80f0136462d2619f8f6adb8fd6c8c15c412aeecc495b197dced29c03f9c7f0,
P64base64byte+CLRdirectstore/matchinghint; baseline925bbeadivider.
Simulationqualification documentedbelow. CD/Ethernetoffseed22unchanged.
Nextwrapper scratch/p75devclear_fit_20260920/run.sh, userunit
q800-p75devclear-fit-20260920. Committhenlaunch; freezeinputswhenlive.
FullguestP67simulation exited0afterquit; workloadprofilepreserved.

# Latest: P75 simulation-qualified; genuine full Mix profile captured

P75core8e80f0136462d2619f8f6adb8fd6c8c15c412aeecc495b197dced29c03f9c7f0
P64+earlyCLRstoreANDmatchinghint. Sieve-4.83%lat3, Quick/Bubbleunchanged.
Fullintegration82305exit0; corpus29782exit0/1900groups0diffs; focusedCLRfaults
candidateandbaselinePASS. Patchscripts/cpu/clear_store_hint.patch. NOproduction
promotion/fit yet; currentP73stillfitting, freezeproductioninputs.

FullguestP67 genuinealltenMix completed: rootreviewedf6222, simulated1.187.
Profileworkload.tsv andreport.md under scratch/p67_fullguest_20260920;
965772857clocks, MMU/cacheenabledalltime. MRD26.17%/MWR12.17%,MDwait1.17%.
MemoryidlewhileMRD common; investigate translation/handshake, extend small
CPU/RAMharnesswithMMUcoverage. CurrentmicrobenchMMUofflimitsrepresentativeness.
Monitorfailed timeoutwaitingstop; simulatorlaterprocessedqueuedstop, profile
validwithextraUIoverhead (~2guestsecafterobservedcompletion). capture.json
rootrecovered. Quitqueuedtoflushsim; verifyexit. No hardwareacceptance claim.

# Latest: P70 hardware complete; P74 microbenchmark screen rejected

P70 fivepairs and final_halt root-reviewed, deployment_record.md reviewed;
median1.133/mean1.1322, noinvalidtimers/exclusions,33MHz32MBdisposable.
Complete table nowdocs/PERFORMANCE_MEASUREMENTS.md. Goalstillunmet.
P74 isolated P64+CLRstoreearly screen savesonly0.08%Sieve; memorywaitabsorbs
nearlyall removedexecutioncycles. Notpromoted orfullqualified; scratch/p74_clear_store_20260920.
Sieveprofiling now lets us reject this in seconds before fitting.
P73 fit remains soleactivebuild lastcheck; no sourcechanges.
Fullguestprofile monitor lastf5827; stillactive, pendingcompletion.

# Latest: user-requested CPU/RAM microbenchmarks extended with Sieve

New scripts/cpu/profile_sieve.py shares profile_quick.py responder; docs in
SPEEDOMETER_MICROBENCHMARKS.md. Original CODE3 b6a..bad bytes unchanged,
one full Sieve pass, excludes allocation/disposal/outer100passes/timingUI.
Independent trial division verifies8191flags,1899primes,buffer guards.
P64/P73 both303820/309734/377576 at RAMlat0/3/8. Largerrefill noSievegain.
Negative clear→NOP mutation rejected count8191. Quick regression178422lat3.
Final harness artifacts scratch/sieve73_final_20260920; baseline
scratch/sieve64_20260920, P64core extracted7952a01hash609b1687.
Automatic --disassemble produceskernel.dis; manifest includes program/oraclehash.

P70 allfive screenshotpairs now root-reviewed:1.129/1.133/1.133/1.133/1.133,
no invalidtimers visible; median1.133,mean1.1322. Operator still owns hardware,
saving record/shuttingdown; finaldeployment/config/shutdown review pending.
P73 fit remainedlive lastcheck, no terminalresult. Fullguest profile running,
f5037 showedWhet/Dhry/Towers/Quickdone andBubbleactive. Preservebothprocesses.

# Latest: genuine full Mix simulator profile started

Local P67 simulator PID2547288 remains live under
q800-p67-fullguest-profile-20260920.service. Root reviewed screenshots:
f3676 actual Speedometer4.02 splash; f3807 registration reminder;
Escape dismissed it, f3916 Hardware Information reports68040/32MB;
CmdB opened f4037 Run Set with all ten checked, each iteration1.
Root queued profile start + Return; run.log confirms start at
simulator halfcycle3427598337. This is full Mix including original math,
not an isolated Whetstone profile. No completed profile/result yet.

Bounded local-only monitor q800-p67-fullguest-monitor-20260920.service
runs scratch/p67_fullguest_20260920/monitor.py. It appends 33Mclock wait/shot,
OCRs completion, stops profile and writes capture.json; leaves simulator
running for visual review. Logs monitor.log. No MiSTer input. Actual image
path tree/verilator/screenshot_f*.png, profile workload.tsv. Monitor starts
at current log EOF (125MB log), incremental reads. Root must inspect final
screenshot and profiler counters; opcode histogram is NOT trustworthy for
pipeline attribution (samples legacy ir). Timer observer coversQueens/Sieve
only. UI launch and completion polling are included in bracket.

P73 fit still active (quartus_fit PID2630402); production inputs frozen.
Cheap operator still owns P70 hardware. Root reviewed run1_start.png and
found startup splash rather than Run Set; told operator to replace with
actual all-ten/iteration-one setup evidence. No accepted P70 result yet.
README profiling caveats committed/pushed bcc0248.

# Latest: P73 shared refill selector promoted for fitting

P70 complete and root-reviewed: archivedRBF9a76b04 SHA
94ed1c2e58b636d458cb848cb130fbaaeb9cb498dce1f451a83f0ad32b06021e,
4520576bytes,fit39433ALMs94%,CPU+.158,HDMI+.022,SDRAM-.054,holdmin+.248.
The actual failure is sys→RAM r_addr[23]→a_ram[23] -.054ns; RAM→sys+1.225.
Source/cross/detailedSTAcommands0; healthy44032bitM10Kcachetag/512bitMLABbankE.
Timing-failed experimentalhardware trial explicitly root-authorized, cheaper
operator owns MiSTer: fivefreshall10iteration1runs,33MHz32MBdisposable,normal
shutdown, exclusion/reporting of invalidtimers. No hardware result yet.

P73 now promoted: core a4875880f4ddc1d66e55187763019a0f3d64cf23b6bbd45430b69bcd050ac3e2,
baseline divider925bbea473dfbd8c65cf0271416632c947f64563199eb6d6070b54286161fb0c.
P64MOVE +128byte refill/sharedadjacentline seedselection; NOshortdivider.
Allsimulationgatespassed (see below). Separate experiment, compare withP64
forrefill gain; P70hasdifferentdivider. CD/Ethernetoff,seed22unchanged.
Launchaftercommit wrapper scratch/p73devshared_fit_20260920/run.sh as userunit
q800-p73devshared-fit-20260920.service. NoQuartusbeforepromotion; confirm live.
P67old128refillfailedrouting98%; P73area/timingbenefit stillunmeasured.

FullguestP67 simulator remains live independently, PID2547288. Finder disk
windowf2619reviewed; typed'appli'+CmdO withwait33Mandshot INFLIGHT toopen
Applications. Inspectnextshotbeforefurtherinput. No benchmarkprofileyet.

# Latest: P70 qualified and promoted for the next fit

P70 = P64 64-byte MOVE core plus P59 shortdivider. Fullintegration77746exit0,
first1001900groups0diffs /tmp/cpu-corpus100-gate.WgStgM, Quick163503/175283/198660
lat0/3/8 sorted/guardsPASS. Noother CPU change. NoQuartus beforepromotion.
Build wrapper scratch/p70devdivide_fit_20260920/run.sh, planned userunit
q800-p70devdivide-fit-20260920.service. Commit then launch; verifylive.
P67failed routing, no freshRBF. MiSTer safehalt onP64median1.131. Cheapoperator
must monitorP70 and awaitroot artifactreview beforedeploy. FullguestP67sim
PID2547288 stillbootinglocaldisk; screenshotf847MacOSStartingup reviewed.
P73scratch128-byte buffer/shared two-line selection retains8seedports; alloffset
independent17,536-caseoraclePASS. Quick74121/Bubble2725pending. No P73fit yet.
P72sixseedwordsscreenQuick166812/178583/201953, Bubble3454620; gainlost likeP71,
sessions30498/56969exit0, not promoted. P73 uses P67 core/baseline divider.

# Current status: P67 fit failed routing; P70/P72 isolated tests active

P67 is no longer an active FPGA build. No fresh bitstream. See final entry.
MiSTer safehalt after five valid P64 runs, median1.131. Local fullguest sim live.

# Latest transition: P67 promoted for development fit

P64 complete: artifact `scratch/p64devmove_fit_20260920/MacQuadra800_p64devmove_7952a01.rbf`,
SHA f2e82be0096b553150ef3bace8888f6a5454947a6d75f6ae954be6c69cec60cc,
4512768 bytes. Root-reviewed fit39302ALMs94%, CPU-.068ns (TNS-.068), HDMI+.288,
SDRAM+.278, holdminimum+.245; sys→RAM+1.892/RAM→sys+.421; healthy inferred
cache tag and register RAM. source/cross/detailedSTA all0; wrapper terminal,
no Quartus process before next source mutation. Cheap operator assigned P64
experimental hardware trial, same33MHz32MB disposable, five fresh pairs.

P67 full integration79688 collected exit0; all gates now passed. Promoted core
SHA e2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec:
P64 MOVE plus128-byte refill, P63ALU/pipeline, baseline divider, noP66change.
CD/Ethernet remain omitted, seed22 unchanged. Next sole flow wrapper
`scratch/p67devrefill_fit_20260920/run.sh`, unit
`q800-p67devrefill-fit-20260920.service`. Launch after this commit; verify live.
No P67 FPGA or hardware performance result yet. Freeze inputs while active.
P66 remains unapplied alternative timing patch. P63/full and P63dev records
now reviewed including configuration and clean shutdown; medians1.129/1.122.

# CPU performance continuation — 2026-09-20

This is the current continuation index. The long historical log is
`RESUME-pipeline-goal-20260919.md`; experiment details and commands are in
`docs/cpu-pipeline-compare-20260919.md`. Inspect live processes before relying
on these observations. The 1.8 hardware goal remains unachieved and active.

## Current production and build

**LATEST ACTIVE BUILD:** user unit q800-p64devmove-fit-20260920.service,
wrapper2490271,quartus_sh2490301,quartus_map2490413 atlaunch. Commit
7952a01e6b5667a2c1e9bef133f74faa63b2a677; archive scratch/p64devmove_fit_20260920.
P64 MOVE optimization, P63 ALU, baseline divider, seed22, CD/Ethernet omitted.
Preflight passed and synthesis active. Freeze RTL/QSF/QIP/SDC. Cheap operator
monitors it while testing archived P63devnocdnet on hardware; never mix artifacts.
All earlier ACTIVE statements below are historical and superseded by this one.


**Current (supersedes older state below):** the sole ACTIVE flow is user unit
`q800-p63devnocdnet-fit-20260920.service`, wrapper2438580, quartus_sh2438602,
quartus_map2438691 at launch. Commit29190feddc3cded8f88956d6332188e53e22fb78,
archive scratch/p63devnocdnet_fit_20260920. Exact P63 CPU, CDROM_OFF and
ETHERNET_OFF enabled, seed22; development-only. Preflight passed and synthesis
is live. Freeze RTL/QSF/QIP/SDC until the entire wrapper ends.
Full-feature P63 completed; GPT-5.6-luna operator owns five-run hardware
qualification of its archived 6fbe313 RBF, and monitors the new build during
waits. Do not deploy mutable output_files or the new development artifact
without root review. Root verified full-feature P63 timing miss and authorized
experimental testing under the persistent user/BUILD.md policy.


**Latest authoritative state:** P57 is terminal routing FAILED. Production now
contains qualified **P63** (P57 core + pipeline ALU subset), source commit
`6fbe31353f03b19ad9ee2440c28847238fb9c852`. The sole ACTIVE user unit is
`q800-p63subset-fit-20260920.service`, wrapper PID2388489, quartus_sh2388510,
quartus_map2388607 at launch. Archive `scratch/p63subset_fit_20260920`.
Preflight hashes passed and synthesis is live. Freeze RTL/QSF/QIP/SDC until
this complete wrapper terminates; inspect the same unit before any action.
The paragraphs below retain the P57 baseline and history.


Prior build RTL was **P57**, core SHA256
`660821496a34151ef80502437ebd59b8c35f66b0aa858ac11f0b6b6446ea5063`.
Quartus seed22 build source commit `e5066a280169c7c93dfe171fd1e5674b72a96052`.
Later commits contain tests, documentation, and unapplied patches only.

The now-terminal P57 flow was the **user** systemd unit
`q800-p57movestore-fit-20260920.service`, wrapper PID2292054,
quartus_sh PID2292088, fitter PID2301048. Query with `systemctl --user`;
a system-scope query misleadingly reports an inactive unit. Terminal FAILED routing congestion, build.exit3, source_check.exit0. No new RBF.
Archive: `scratch/p57movestore_fit_20260920`.

Keep RTL/QSF/QIP/SDC frozen until the wrapper finishes, including cross-domain
STA and archiving. Never run two Quartus flows or use a git worktree. Source
manifest rechecks pass. Fresh synthesis RAM Summary confirms cache tags44,032
bits in M10K and extra register bank E512bits in MLAB.

P52 seed21 is terminal FAILED: placement passed at41,356ALMs99%, routing failed
from congestion. `scratch/p52refill64_fit_20260920/build.exit=3`, source check0.
P47 previously failed placement from excess LAB demand. Neither produced a
new RBF. `output_files/MacQuadra800.rbf` remains the old P39 artifact until a
fresh result is independently verified; never label it P52 or P57 by filename.

## Qualified next candidates (unapplied)

Prefer **P62** as the next MOVE candidate after P57 ends. P62 includes P61;
their patches are alternatives, not cumulative patches to apply together.
P62 core SHA256:
`609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980`.
Exact source: `scratch/p62_move_dispext_20260920/ap040_core.v`.
Reproducible diff: `scripts/cpu/move_displacement_extension.patch` against P57.
It starts a d16 MOVE destination and requests its extension after source-read
success, retaining the existing S_IMMF settling/fault edge. Baseline divider
and pipeline module remain unchanged.

P62 full integration, targeted fault/IRQ/trace/alias/guard/value tests, and
first100 silicon corpus pass (1900field-groups, zero differences;
`/tmp/cpu-corpus100-gate.OaHEoG`). Wrong-base mutation fails actual guest
checks; baseline fails the required direct-entry coverage assertion.

| Original kernel, controlled latency3 | P57 cycles | P62 cycles |
|---|---:|---:|
| Quick Sort | 182,275 | 178,786 |
| Towers | 23,887,160 | 23,444,567 |
| Permute | 1,380,669 | 1,380,669 |
| Bubble | 3,456,612 | 3,456,612 |
| Queens | 65,720 | 65,720 |

All output oracles pass. These are simulation cycles, not hardware Mix scores.
Prepared, **not launched**, wrapper:
`scratch/p62dispext_fit_20260920/run.sh`. It requires the exact P62 core,
unchanged pipeline module, and original divider before starting. After P57's
complete wrapper is terminal, inspect its result, then promote/commit/push P62
and run the wrapper as the sole new user service. If P57 fails again, assess
its actual failure before assuming another near-full layout will route.

Separate qualified divider experiments: P59 skips zero upper dividend bits;
P60 seeds the upper remainder when it is below the divisor. Both pass full
integration, first100, and24,567 independent arithmetic cases with CE stalls
and deliberate wrong-result mutations. Their alternative unapplied diffs are
`scripts/cpu/divider_short.patch` and `scripts/cpu/divider_seeded.patch`.
They are not included in P57, P61, or P62. P59/P60 reduce Quick Sort cycles
about1.9% beyond P57 but have no fit/hardware evidence; broader P60 workload
benefit over P59 is unmeasured. Avoid silently combining candidates before
qualification and measurement.

## Hardware status and next gate

Best experimental hardware P39: five valid Mix runs, median1.105, CPU setup
-3.701ns (not release timing). Best timing-clean P33: median1.083. Details:
`docs/PERFORMANCE_MEASUREMENTS.md`,
`scratch/hardware_p39refill64_20260919/p39refill64_results.md`.

Last root-reviewed MiSTer frame was a safe shutdown screen on P39, at
`scratch/hardware_readiness_20260920/current.png`. Recheck before deployment.
Target only `mister.local` (10.3.89.233), root key `/home/alans/.ssh/id_rsa`,
remote input8182. Existing authorized hardware agent `/root/mister_operator`
is idle. The original `QuadSquad8.hda` must remain untouched; slot0 uses
`QuadSquad8-pipeline-test-20260919.hda`. User authorizes recovery/reloads on
that disposable image. Normal shutdown is preferred; do not restart Main or
remote input under a live guest. Read BUILD.md before hardware work.

For any fresh RBF, inspect exact source/hash, fit/resource/timing reports,
RAM inference and both cross-domain reports before assigning hardware work.
A marginal fit is permitted for experimentation with explicit timing status.
Keep authentic33MHz/32MB configuration, five independently started valid Mix
runs; exclude and report timer anomalies. Capture each fresh Run Set and
completion pair, and root-review screenshots. Dismiss the old completion
modal before Command-B; otherwise stale results can masquerade as a new run.

User deferred A/UX to Dani because the image is unavailable. CD audio still
needs the applicable final release check, including audible confirmation.
Commit/push progress to origin/add-ethernet is authorized; do not force-push.
Leave unrelated untracked worst_detail.txt and worst_paths.txt alone.

## Profiling cautions

Upstream ap040-pipelined evaluation is complete and did not justify import;
see UPSTREAM_PIPELINE_BENCHMARKS_20260920.md in docs. It is a separate CPU
rewrite, not the CPU being built here.

Quick Sort profiling distinguishes actual fetch starvation from productive
S_PIPE_REGS retirement; about7.6% of P57 latency3 cycles are S_FETCH without
an opcode. This is not a global Mac bottleneck measurement.
`docs/SPEEDOMETER_MIX_ANALYSIS_20260920.md` traces the aggregate calculation.
Hardware table integer-kernel numbers are elapsed seconds, not ratings.
Whetstone contributes about27% of the current rating sum; its original SANE
and external math calls must be preserved in any future profiling.


## P63 isolated area experiment (new, unapplied)

P57 fitter PID2301048 last verified live at37m44s, CPU64m06s; same user unit
active. Source manifest PASS. No fresh artifact yet. Prior goal work was a
verified wait; this turn adds independent candidate qualification.

P63 specializes only the duplicate pipeline ALU to its sixteen decoded
operations; legacy ALU defaults unchanged. Scratch:
`scratch/p63_subset_alu_20260920`; unapplied patch
`scripts/cpu/pipeline_subset_alu.patch`. See latest section in
`docs/cpu-pipeline-compare-20260919.md` for qualification and reproduction.
Subset393216 and full2528416 comparisons PASS, six-mode independent P6 and
compare oracles PASS, Quick cycles unchanged at all three latencies. Carry
mutation fails. Area benefit is unmeasured; do not promote based on simulation.
Full integration completed PASS (session47180 exit0), output in
`scratch/p63_subset_alu_20260920/full_gate.log`, fixtures scratch/p63full.
Tracked compare-runner verification session71977 completed exit0, all six modes PASS.
Do not confuse P63 with P62: it is a separate P57-based area experiment.

P63 first100 silicon reference completed PASS, 1900 field-groups/zero differences,
`/tmp/cpu-corpus100-gate.WhYoWi`; session49483 exit0, log in P63 scratch/corpus.log.
Prepared NOT launched P63 wrapper `scratch/p63subset_fit_20260920/run.sh` with
exact ALU/pipeline/core/divider preflight hashes. P57 synthesis pipeline ALU
uses2182 combinational ALUTs; actual P63 savings unmeasured. P57 fitter still
live at41m24s with CPU70m09s. Next action remains inspect terminal P57 result;
P62 is the qualified cycle-reduction option, P63 the qualified area experiment.


## P57 terminal; P63 promoted next

P57 seed22 FAILED routing congestion (16618/188026/170143), placement passed:
41,260ALMs98%,26,039registers,491RAMblocks,43DSP. Source check exit0, no fresh
RBF. Wrapper MainPID0, unit failed, no Quartus processes before promotion.
Output RBF remains stale P39 and must never be deployed as P57.

P63 ALU subset promoted from the exact qualified patch, core unchanged P57,
baseline divider unchanged, seed22 retained to isolate area change.
Build wrapper: scratch/p63subset_fit_20260920/run.sh. Launch as sole user
unit q800-p63subset-fit-20260920.service after commit. Freeze build sources
until that wrapper completes. P62 stays unapplied pending routing evidence.


## Latest: P63 synthesis measured; P64 ready, unapplied

P63 synthesis PASS08:29:39. Pipeline ALU2182→1637 combinational ALUTs (-25%);
pipeline total3764→3183. Actual fitted ALMs/routing/timing still pending.
Same active user unit, fitter PID2397271 replaces synthesis PID2388607.
Source manifest PASS. Synthesis reports copied to P63 archive/synthesis.map.*.

P64 combines exact P62 core with P63 ALU/pipeline, baseline divider; no other
changes. Full integration and first100 PASS (1900groups0diffs,
/tmp/cpu-corpus100-gate.PKVtFj), directed MOVE faults/boundaries/values PASS,
Quick167015/178786/202156 at latencies0/3/8. All sessions terminal exit0.
Artifacts scratch/p64_move_subset_20260920, scratch/p64full, scratch/qk64.
Unapplied delta remains scripts/cpu/move_displacement_extension.patch.
New identity-checked wrapper scratch/p64movesubset_fit_20260920/run.sh is
prepared NOT launched. Old P62 wrapper expects pre-P63 pipeline and must not
be used for this combination. Inspect complete P63 result before next build.


## Monitoring / hardware delegation

User explicitly requested a cheaper model for completion monitoring and MiSTer
tests. GPT-5.6-luna agent `/root/fit_and_hardware_operator` now owns P63 user-unit
monitoring and subsequent hardware operation. It must report the terminal
wrapper/artifact/timing/source checks to root before deployment; root reviews
artifact evidence and every fresh benchmark start/completion screenshot.
Older `/root/mister_operator` is idle and handing over script paths; do not
allow concurrent hardware input. Root reviewed fresh readiness screenshot
`scratch/hardware_readiness_p63_20260920/current.png`: safe shutdown, still P39,
33MHz/32MB, disposable disk selected. Agent must recheck before deployment.
No P63 hardware artifact or score exists yet. Ask the monitoring agent for
terminal evidence rather than duplicating its polling loop.


## Latest user steering: temporary CD and Ethernet omission

User proposed disabling Mac features temporarily and specifically Ethernet.
Next planned development build keeps P63 CPU unchanged and sets CDROM_OFF=1
and ETHERNET_OFF=1. Do not interrupt or modify current full-feature P63 fit.
Prepared UNAPPLIED scripts/cpu/development_no_cd_ethernet.patch; NOT launched
scratch/p63devnocdnet_fit_20260920/run.sh (exact P63 preflight and both feature
flags required, DEVELOPMENT ONLY labeling). See
`docs/CPU_DEVELOPMENT_FEATURES_20260920.md`. Both features must be restored
and full hardware validation repeated before final acceptance. P64 stays a
subsequent one-at-a-time CPU experiment. Cheap operator has been notified.


## P63 terminal, hardware assigned; development profile promoted

Full-feature P63 fit SUCCESS, build.exit1 solely timing gate, source0/cross0.
Artifact4555188bytes, SHA5dafc05bb5a47a3c6cbb31ef5e0e7f826d8aa32a9ed110d1c3af27532b1cf587,
archive scratch/p63subset_fit_20260920/MacQuadra800_p63subset_6fbe313.rbf.
41,174ALMs98%; CPU-1.709ns,HDMI-.213,SDRAM+.478,holdmin+.242,
crosssysram+2.325/ramsys+.827. Root verified and assigned cheap operator
/root/fit_and_hardware_operator five-run experimental hardware gate on this
exact archived RBF; timing miss does NOT bar user-authorized experimentation.
Operator owns hardware access. No score yet. Original disk remains untouched.

Both development feature macros now applied in QSF, exact P63 CPU unchanged.
Next sole build wrapper scratch/p63devnocdnet_fit_20260920/run.sh; commit/push
before launching q800-p63devnocdnet-fit-20260920.service. P64 still unapplied.
Current QSF is development-only and must restore CD/Ethernet before release.


Detailed timing follow-up: archived P63 .sta.rpt has summaries, not individual
failing CPU paths. Do not infer its path from P39 or from the partial current
database. After p63devnocdnet's COMPLETE wrapper ends, and before any next flow,
run quartus_sta -t scripts/cpu/timequest_worst_paths.tcl
scratch/p63devnocdnet_fit_20260920/cpu_timing. The script now accepts an output
directory (default scratch/cpu_timing) and leaves unrelated root worst_paths.txt
and worst_detail.txt untouched. Cheap operator notified to capture this then.


P63 hardware update: root reviewed ALL five fresh all10/iteration1 start and
completion pairs under scratch/hardware_p63subset_20260920. Mix1.126,1.129,
1.130,1.129,1.130 =>median1.129,mean1.1288; no apparent timer anomalies.
Table now in docs/PERFORMANCE_MEASUREMENTS.md, marked closure pending until
operator supplies remote-copy/config/disposable identity and clean shutdown
for root review. Do not call release-qualified: CPU/HDMI timing still fail.
Do not attribute gain solely to ALU subset (P52/P57 changes also present).
Devnocdnet remains a separate active build; no hardware score yet.


P65 larger-refill experiment prepared in scratch while cheap operator owns
hardware/build monitoring. Exact128-byte P52→P47 delta on P63/P57core; noP64
MOVE change, baseline divider, P63ALU/pipeline. Core SHA213efb3eaed8990a24c3315cc3bc2816b7b2725f8c588fb4d1db2ee7040921d7.
Unapplied scripts/cpu/refill128_subset.patch; scratch/p65_refill128_subset_20260920.
Bubble latency3 3456612→3270270 (-5.39%cycles); Quick170140/181911/205281 at
latency0/3/8 (-364 each vsP63), output/guards PASS. Prefix42770patterns PASS,
upper/crossing SMC PASS. Fullintegration session39775 and first100 session12640
RUNNING; inspect full.log/corpus.log. NoP65fit/hardware; production frozenP63dev.


Latest transition: P63 full-feature five pairs and shutdown_attempt.png root
reviewed, median1.129; remote hash/disposable confirmed by operator. Cheap
operator now assigned P63devnocdnet hardware trial, archive29190fe RBF
SHAf877992fd51c01324393ccf36ead3d6c678e24b7e1c2f771a859106301a405ed.
That flow COMPLETE,source/cross/detailedSTA0;fit39411ALMs94%,CPU-.862,
HDMI-.268,SDRAM+.796,holdmin+.172,cross+1.229/+1.259. No development score yet.

P64 MOVE patch now promoted (previous fullintegration/corpus/targeted gates
passed); current core SHA609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980.
CD/Ethernet remain omitted. Launch after commit as sole user unit
q800-p64devmove-fit-20260920.service via scratch/p64devmove_fit_20260920/run.sh.
P65 remains separate scratch; first100 PASS1900groups0diffs
/tmp/cpu-corpus100-gate.n4wqdQ, fullintegration39775 still running atlastcheck.

P65 final qualification: integration39775 and first10012640 collected exit0;
full.log ends PASS real-core pipeline ownership integration. First1001900groups
0diffs /tmp/cpu-corpus100-gate.n4wqdQ. P65 remains P63-based, not P64-based;
noP65FPGA or hardware result. Development fit-time comparison: P63full24m54
versus P63dev21m56 (~3min/12% faster this pair), not a general guarantee.


## P66: isolate queue branch targets from the decode-state selector

Unapplied candidate `scripts/cpu/queue_branch_target.patch`, based on P64
core SHA `609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980`.
Candidate core SHA `3935c0c9df415a560c9a50c3deacad0f85538414b9feb0934a02e5da3530c5ed`;
P63 pipeline/ALU and baseline divider remain unchanged. No P65 refill change.

The P63 development fit's worst CPU path starts at state[2] and passes through
opcode selection and branch-target arithmetic into epf_data, missing by 0.862 ns.
P66 derives lookahead branch opcode/target directly from the instruction queue.
The shared early-target selector already handles S_DECODE separately, and bd_ok
excludes S_DECODE. All bd_* consumers were inspected for this qualification.
This removes an unnecessary state dependency; actual area/timing benefit is
unmeasured until a separate Quartus fit. It does not claim a cycle-count gain.

Validation on the isolated candidate:
- Full integration PASS (`scratch/p66full`), including branch_early, exceptions,
  MMU/cache, restart, pipeline faults, interrupts, and replay; no saved-log
  early-target consistency diagnostics. Prototype oracle: 14,720 snapshots.
- Original QuickSort kernel PASS sorted permutation and guards, exact P64
  cycle counts 167015/178786/202156 at memory latency 0/3/8.
- Immutable first-100 corpus PASS: 100 rows, 1900 field-groups, zero differences;
  `/tmp/cpu-corpus100-gate.Vo0SmS`. This is not the full CPU corpus.

P64 development build remains active and its RTL is frozen. P66 is a saved,
simulation-qualified patch only; no P66 FPGA or hardware result exists.


Latest scratch work: P67 combines current P64 MOVE with the existing P65
128-byte refill patch, applied with zero fuzz (three expected line offsets).
No P66 timing change. `scratch/p67_move_refill128_20260920` contains core and
logs; production remains frozen P64. Quick session71688, full integration79688,
Bubble then coherence42693, first10078472. Quick log already reports all three
PASS with counts166651/178422/201792 (364 cycles below P64 at each latency);
collect process exit before final qualification. Other results pending.
P63dev five benchmark start/completion pairs root-reviewed, median1.122;
shutdown and persisted identity report pending with cheaper hardware operator.
P66 commit2b4f4e6 pushed; all its simulation processes collected exit0.


P67 interim qualification update: Quick71688, corpus78472, Bubble/coherence42693
collected exit0. Core SHAe2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec.
Quick166651/178422/201792; Bubble3270270lat3, sorted/guardsPASS. Upper/crossing
self-modifying-code cases PASS3patcheseach. First100PASS1900groups0diffs,
/tmp/cpu-corpus100-gate.2VUHij. Independent diff against P65 contains only the
P64 d16 MOVE change. Integration79688 still active, through branch_earlyPASS;
collect final result before considering promotion. Prefix log at
scratch/p67_move_refill128_20260920/prefix.log. P64 build still fitting, source
manifest unchanged; no candidate promotion or new Quartus flow launched.
Prefix86843 collected exit0: 42,770 patterns across 64 words PASS.


P67 sole fit launched successfully: unitq800-p67devrefill-fit-20260920.service,
wrapperPID2526067,quartus_sh2526089,map2526182. Build commitc95dced. Confirmed
live synthesis after launch; freeze production inputs until complete wrapper.
Cheap operator running P64hardware; saved boot/desktop/Speedometer screenshots
exist under scratch/hardware_p64devmove_20260920, not yet root-reviewed.
Profiler-only change now gives register/admission counts; see comparison doc.
P66 timing candidate not applied: P64's worst path shifted to MMU→epf_data,
so its former state→branch-target path is not established as the current limit.


## P68 screen: admit register MOVEA with a supported successor

Scratch-only `scratch/p68_movea_entry_20260920/ap040_core.v`, based on P67.
The memory-entry policy additionally permits `(ir & 16'hf1f0)==16'h2040`
when pipe_next_supported. No datapath or instruction semantics change.
Quick latency0/3/8 PASS166502/178273/201656cycles versus P67
166651/178422/201792: only149/149/136cycles saved (0.084% atlat3).
Bubblelat3 unchanged3270270, sorted/guardsPASS. Quick pipeline issues rise
7285→13079 but increased entry/drain work absorbs almost all retirement savings.
Atlat3 register-state occupancy falls33047→27253 while pipeline ownership grows;
this illustrates why occupancy alone cannot predict performance gain.

No promotion or FPGA build: gain is too small to prioritize over the current
larger-refill fit. These kernel checks are a performance screen, not full CPU
qualification. No full integration/corpus/hardware claim for P68.


Full-guest profiling setup started: immutable `git archive c95dced` under
`scratch/p67_fullguest_20260920/tree` (not a worktree), current P67 core hash
verified; build session57503 active, logbuild.log. MatchingAP040/CACHE/CD/ETHERNET
flags captured inidentity.json; vendored untracked sim/mac copied. Disposable
87MBlocal MacQuadra800-Speedometer402-profile.hda copied torun.hda, never edit
fixture. Buildscript and runscript beside it; runscript NOT YET STARTED. Collect
buildsession before starting simulator. It uses fastbootROM solely skipping RAM
test; simulation is profiling evidence, never a hardware Speedometer score.
Control regularfilecontrol.txt accepts appended PS/2 scan-code down/up, wait,
shot, profile start/stop, quit. Runscript sets --cpu-profile workload.tsv and
--speedometer-observe speedometer.jsonl; screenshotframes500/1500/3000/5000/7000,
maxcycles12G. Boot guest, launch original Speedometer, select genuine Whetstone
workload including SANE/mathcalls, bracket it; never substitute math stubs.
P64hardware root reviewed first3pairs1.127/1.131/1.132; remaining2/shutdown with
cheap operator. P67FPGA remains live fitting. No new FPGA source changes.


P64 hardware complete/root reviewed: all5pairs1.127/1.131/1.132/1.131/1.131,
median1.131mean1.1304, noexcludedtimers,33MHz32MBdisposable,remotehashverified,
shutdown.pngsafehalt. Measurements table committed. Cheap operator now monitors
P67through wholewrapper and then detailedSTA, must waitrootreviewbeforedeploy.
Fullguest sim build57503collectedexit0; simulator nowlive asuserunit
q800-p67-fullguest-profile-20260920.service PID2547288. Bootlog progressed190M
halfcycles atlastcheck, screenshots scheduled. Original profilingdisk preserved.
P69scratch applies existingP59shortdivider atop P67(nootherchange):
scratch/p69_refill_divshort_20260920. Quick33749counts163139/174919/198296PASS
atlat0/3/8; fullintegration19078 and first10090842 running. Collectexit/results.
NoP69FPGA source promotion or hardware result; productionstillfrozenP67.


## P69: shorter divider on the MOVE/refill candidate

Scratch-only `scratch/p69_refill_divshort_20260920`, current P67 core plus
previously qualified P59 divider (existing `scripts/cpu/divider_short.patch`).
Divider SHA `1f1df9410c86354d50dd46318d84395d67fc932ac9c1672cb40a9c5014a37a17`;
core remains `e2c0baba83bb7eb8ac1e9de1bab14ef2dbc49a4a9fe1dbd400c82498dab0a0ec`.
It skips eight restoring rounds when the absolute dividend's upper32bits are
zero and divisor nonzero; it retains the baseline path otherwise.

Quick original kernel PASS163139/174919/198296cycles atlatency0/3/8, versus
P67's166651/178422/201792 (about1.96% fewer atlat3); sorted permutation and
byte guards PASS. First100 PASS100rows1900groups0differences,
`/tmp/cpu-corpus100-gate.8nLP7c`. Quick33749/corpus90842collectedexit0.
Full integration19078stillactive, through FPUPASS atlastcheck; complete it
before promotion. Existing standalone24,567-case divider oracle qualification
is unchanged; this run checks composition with the larger refill/MOVE core.
No P69 FPGA fit or hardware result. P67production remains frozen during fit.

Fullguest simulator verifiedlive PID2547288, +ram default0 maps32MB. Bootshot
scratch/p67_fullguest_20260920/tree/verilator/screenshot_f333.png shows gray
startup framebuffer, not desktop; ~300Mhalfcycles after~5minwall. Do not call
this a boot gate or Whetstone profile yet. Simulatorcontrol appendshot works.


P69 final simulation qualification: integration19078collectedexit0, full.log
endsPASSreal-corepipelineownershipincludinginterrupt/replay. Together with
Quick/corpusresultsabove and unchangedP59divideroracle, candidate ready for
separate fit when P67wholewrapperanddetailedSTAterminal. Prepared but NOT
LAUNCHED scratch/p69devdivide_fit_20260920/run.sh; requires P67core plus
P59dividerhash1f1df9410c86354d50dd46318d84395d67fc932ac9c1672cb40a9c5014a37a17.
No productionmutation yet; P67stillactive. Fullguest simulator has advanced
pastgrayROMscreen intoSCSIdiskactivity, notyetdesktop/profiledworkload.


## P67 fit failed routing; follow-up screens

P67 wrapper terminalexit3/sourcecheck0, nofreshRBF/STA/crossreports. Placement
completed, routing terminated due congestion (16618/188026/170143),41,185ALMs98%,
25,347registers,483RAMblocks,41DSP. No Quartus process remains. Do not use the
old output_files RBF or timing reports as P67 evidence. P69's simulation-qualified
128-byte combination inherits this area concern and is not queued unchanged.

P70 uses P64's fitting64-byte core SHA609b1687e27b5da1096d6b1c990027b46d27f00272ce1d96b45ef6ed97a2f980
plusP59shortdivider. Scratch p70_move_divshort_20260920; Quick89458exit0:
163503/175283/198660lat0/3/8,sorted/guardsPASS. First10070943exit0:1900groups0diffs,
/tmp/cpu-corpus100-gate.WgStgM. Fullintegration77746stillrunning. Prepared
scratch/p70devdivide_fit_20260920/run.sh, NOT LAUNCHED or promoted.

P71 scratch128-byte buffer with seed count capped4 and only4queue seed ports:
Quick167139/178910/202280 andBubble3454620lat3PASS. Almost all P67's Bubble gain
lost (P67=3270270;P64=3456612), with Quick slower than P64. Not promoted or
fully qualified; no area claim without synthesis. Sessions26303/74803exit0.
P72 scratch variant caps seed6/6ports, sameP67base/no shortdivider. Screening
Quick30498 andBubble56969active; logs underp72_refill128_seed6_20260920. No fit.
FullguestP67simulation remainslive independently of failedFPGAfit; snapshot
sources immutable, useful for profiling only. Latestshotf847 notyetreviewed.


## P73: share adjacent-line selection, retain all eight refill words

Unapplied `scripts/cpu/refill_shared_seed.patch` is relative to P67's128-byte
core, NOT currentP70's64-bytecore. P73coreSHA
`a4875880f4ddc1d66e55187763019a0f3d64cf23b6bbd45430b69bcd050ac3e2`.
It selects two adjacent16-byte lines into256bits, aligns at the target word,
and writes the same eight queue positions under the unchanged valid-count mask.
The wrapped line at the128-byte boundary is not consumed beyond that mask.
Baseline divider925bbea... remains paired; Quick/Bubbleidentity files checked
beforeproductionchangedtoP70shortdivider. This is an area/routing experiment;
no savings claim exists without Quartus evidence.

Quick lat0/3/8 exactly166651/178422/201792 andBubblelat3exactly3270270: identical
toP67 and preserving its5.4%Bubble gain. Sorted/guardsPASS; sessions74121/2725exit0.
New reusable `refill_seed_alignment.py` extracts the candidate seed block and
compares with independently indexed16-bit words across64offsets,alllegalcounts
0..8,32random buffers, and unchanged masked queue positions:17,536casesPASS.
OriginalP67alsoPASS; intentionally reversed shift fails atoffset1,n1,word0.
Upper/crossing instruction-coherence3patcheseachPASS. First10029767exit0:
1900groups0diffs `/tmp/cpu-corpus100-gate.EOuMAA`. Fullintegration4418active;
finish beforepromotion. Sources/logs under scratch/p73_refill_shared_seed_20260920.

P70launched userunitq800-p70devdivide-fit-20260920.service,wrapper2576384,
buildcommit9a76b04,verifiedactive. FreezeproductionRTLthroughwholewrapper.
Cheapoperatorassignedmonitoring. P67fullguestlocal simprogressed1.09Ghalfcycles;
MacOSstartupscreenreviewed, notyetdesktop. Existing timerobserverQueens/Sieve
only. Profiler totaldispatch toggle/state/cachecounts usable; opcodehistogram
reads legacyir even duringpipeline dispatch and must NOT be treated as exact
pipeline opcode attribution. No workload profile has been collected yet.


P73 final qualification: integration4418collectedexit0, full.log endsPASS
real-corepipelineownershipincludingfault/interrupt/replay. All planned simulation
gates complete with baseline divider. Prepared NOTLAUNCHED wrapper
scratch/p73devshared_fit_20260920/run.sh with exactcorehasha4875880...and
baseline925bbea...divider. Area/timingunmeasured; waitP70completebeforepromotion.
P67fullguest screenshotf1520reviewed: Finder menu bar visible, desktop icons
stillloading; no profileyet. Existing sim_speedometer README warns historic
keyboardsequence previously openedPrinceofPersia and wasrejected. Use live
screenshots/manualnavigation, notprefixreplay. Appendedwait33Mthen shot tolocal
controlfile; simulatorremainslive, P70Quartusremainslive.

Simulatornavigation update: screenshotf1685MacAtrium ready, PrinceofPersia
selected. CmdQ thenEscape with10mssimulatedpress didnotexit or showpersistent
menu; don'tassumeinputsuccessfromcontrol-log alone. MappingPS2LeftAlt11=Command,
Q15,Escape76checked; inputps2clockinitial1 andportconnected. Latest appended
Escapeheld3.3Mclocks(100ms),release,wait16.5M,shot; inspectlatestimage before
nextinput. No benchmarkprofile started. P70fitter live; P73fullyqualified.


Simulator navigation verified: f2030 showed MacAtrium Quick-Launch Menu;
f2125 confirmed focus on Exit to Finder after two Tab presses. Return sent,
f2219 shows transitional launcher redraw, not confirmed Finder yet. Latest
control appends wait66M rising edges then shot; inspect that new screenshot
before further input. Current simulator unit/PID unchanged. No Whetstone
bracket started. P70 fitter verified live2585604; cheaper operator reassigned
to monitor through terminal rather than stop after a status-only report.


Fullguest navigation milestone: after Exit to Finder plus66M-edge settling,
latest screenshot (~2.065Ghalfcycles) visibly shows Finder desktop, selected
Mac-7-5-5 disk, Trash, and Finder menus. MacAtrium successfully exited.
Sent Command-O (11/44,100ms holds), thenwait33M andshot toopen selected disk.
This command is IN FLIGHT; inspect new screenshot after its final wait before
sending more keys. No Whetstone profile started. Do not replay old prefix.
P70fit remains active; no artifactreview/deployment yet. P73qualifiedwaiting.


P73 fit launched fromcommit2fa84af, userunitq800-p73devshared-fit-20260920.service,
wrapperPID2621015. Verifiedlive synthesis, allsourcehashpreflightpassed.
Freeze buildinputs through wholewrapper. Cheaperoperator running root-reviewed
P70hardware trial and monitoringP73. P70sys→RAM-.054explicitlyexperimental.
Simulator folder navigation: f2866 confirmed Applications with Speedometer4.02
Folder visible. Sent typed'speedometer 4'+CmdO,wait33M,shot; sequenceINFLIGHT.
Use its new screenshotbefore furtherinput. Target is4.02, notvisible3.23app.
No actualworkloadprofile yet. Currentlocal simulatorstillP67snapshot/baseline
 divider, independently of physicalP70/P73experiments.
