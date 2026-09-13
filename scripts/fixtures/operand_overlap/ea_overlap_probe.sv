// Read-only cycle assertions; this module is never part of production RTL.
module ea_overlap_probe;
`define C tb_ap040_program.dut.core
integer entries=0, sources=0, destinations=0, stalled=0;
integer resident=0, forwarded=0, waiting=0;
reg [7:0] mode_coverage=0;
reg candidate=0,sourceonly=0,destinationonly=0,accelerated=0;
reg eligible;
reg [2:0] mode,rn;
reg [1:0] size;
reg [7:0] ret,immret,oldstate;
reg [31:0] oldpc,oldimm,oldx;
reg [511:0] before_ce;
initial begin
 candidate=$test$plusargs("overlap_expect");
 sourceonly=$test$plusargs("overlap_source");
 destinationonly=$test$plusargs("overlap_destination");
end
always @(posedge tb_ap040_program.clk) if(tb_ap040_program.nreset) begin
 if(!`C.ce) begin
  before_ce={`C.state,`C.pc,`C.imm,`C.imm_n,`C.r_imm_ret,
             `C.ea_pcb,`C.ea_pcmode,`C.rr_a,`C.rr_b,`C.x_ext};
  #1;
  if(before_ce !== {`C.state,`C.pc,`C.imm,`C.imm_n,`C.r_imm_ret,
             `C.ea_pcb,`C.ea_pcmode,`C.rr_a,`C.rr_b,`C.x_ext})
   $fatal(1,"EA_OVERLAP_CE_FAIL");
  stalled=stalled+1;
 end else begin
  if(`C.state==`C.S_IMMF) begin
   if(`C.epf_ready_pc) resident=resident+1;
   else if(`C.epf_fwd_pc) forwarded=forwarded+1;
   else waiting=waiting+1;
  end
  eligible=0;
  oldstate=`C.state;
  if(`C.state==`C.S_PIPE_START && `C.p_src==`C.SK_MEM) begin
   mode=`C.src_mode_r;rn=`C.src_rn_r;size=`C.p_ssize;ret=`C.S_PIPE_SRD;
   eligible=1;
  end else if(`C.state==`C.S_PIPE_DST && `C.p_dst==`C.DK_MEM) begin
   mode=`C.dst_mode_r;rn=`C.dst_rn_r;size=`C.p_dsize;ret=`C.S_PIPE_DEA;
   eligible=1;
  end
  eligible=eligible && (mode==5 || mode==6 || (mode==7 && rn<=3));
  if(eligible) begin
   oldpc=`C.pc;oldimm=`C.imm;oldx=`C.x_ext;
   if(oldstate==`C.S_PIPE_START && `C.exec_kind!=`C.EK_MD_L) oldx=oldimm;
   immret=(mode==5 || (mode==7 && rn==2)) ? `C.S_EA_D16 :
          (mode==6 || (mode==7 && rn==3)) ? `C.S_EA_EXTW : `C.S_EA_ABS;
   entries=entries+1;
   if(oldstate==`C.S_PIPE_START) sources=sources+1;
   else destinations=destinations+1;
   mode_coverage[mode==5 ? 0 : mode==6 ? 1 : 2+rn]=1;
   #1;
   if(`C.pc!==oldpc || `C.ea_pcb!==oldpc || `C.rr_a!=={1'b1,rn} ||
      `C.ea_mode!==mode || `C.ea_rn!==rn || `C.ea_size!==size ||
      `C.r_ea_ret!==ret || `C.x_ext!==oldx)
    $fatal(1,"EA_OVERLAP_SETUP_FAIL pc=%h",oldpc);
   accelerated=candidate || (sourceonly && oldstate==`C.S_PIPE_START) ||
               (destinationonly && oldstate==`C.S_PIPE_DST);
   if(accelerated) begin
    if(`C.state!==`C.S_IMMF || `C.imm!==0 || `C.r_imm_ret!==immret ||
       `C.imm_n!==(mode==7 && rn==1 ? 2'd2 : 2'd1) ||
       `C.ea_pcmode!==(mode==7 && (rn==2 || rn==3)))
     $fatal(1,"EA_OVERLAP_REQUEST_FAIL pc=%h",oldpc);
    if(mode==7 && rn<=1 && `C.ea_absl!==rn[0])
     $fatal(1,"EA_OVERLAP_ABS_FAIL pc=%h",oldpc);
   end else if(`C.state!==`C.S_EA_DISP || `C.imm!==oldimm)
    $fatal(1,"EA_OVERLAP_BASELINE_FAIL pc=%h",oldpc);
  end
 end
end
final begin
 $display("EA_OVERLAP_COVERAGE candidate=%0d entries=%0d source=%0d destination=%0d modes=%h ce_stall=%0d resident=%0d forwarded=%0d waiting=%0d",
 candidate,entries,sources,destinations,mode_coverage,stalled,resident,forwarded,waiting);
 if(entries==0 || sources==0 || destinations==0)
  $error("EA_OVERLAP_MISSING");
end
`undef C
endmodule
