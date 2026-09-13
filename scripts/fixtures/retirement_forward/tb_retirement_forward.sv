`timescale 1ns/1ps
`include "ap040_defs.svh"
// Simulation-only controlled boundary tests. Seed a decoded ADD.L D0,D0
// producer and an actual instruction response, then check architectural
// execution and the queue. No test forcing is included in production RTL.
module tb_retirement_forward;
reg clk=0,nreset=0,ce=0,ack=0,fault=0;
reg [31:0] response=0;
always #5 clk=~clk;
ap040_core #(.AP040_HAS_MMU(0),.AP040_HAS_FPU(0)) dut(
 .clk(clk),.nreset(nreset),.ce(ce),.mem_ack(ack),.mem_rdata(response),
 .mem_flt(fault),.berr(1'b0),.ipl(3'b111),.ipl_autovector(1'b1),
 .pt_done(1'b0),.pt_mmusr(32'd0),.pf_done(1'b0),.cinv_done(1'b0));
integer checks=0,case_id=0,j;
reg candidate=0;
reg [31:0] nextpc;
reg [2:0] head;
reg [15:0] fw;
reg lw;
initial candidate=$test$plusargs("candidate");

task verify(input condition,input [255:0] what);
 begin
  checks=checks+1;
  if(condition!==1'b1) $fatal(1,"FORWARD_FAIL case=%0d check=%0s state=%0d pc=%h ir=%h count=%0d head=%0d",case_id,what,dut.state,dut.pc,dut.ir,dut.epf_count,dut.epf_head);
 end
endtask

task setup(input integer id,input longword,input [31:0] npc,input [2:0] qhead,input [15:0] opcode);
 begin
  @(negedge clk);nreset=0;ce=1;ack=0;fault=0;
  repeat(3) @(posedge clk);
  @(negedge clk);nreset=1;ce=0;
  case_id=id;nextpc=npc;head=qhead;fw=opcode;lw=longword;
  dut.state=dut.S_PIPE_REGS;dut.exec_kind=dut.EK_ALU;
  dut.p_src=dut.SK_REG;dut.p_dst=dut.DK_REG;
  dut.p_sreg=0;dut.p_dreg=0;dut.rr_a=0;dut.rr_b=0;
  dut.p_flags=1;dut.p_wbsup=0;dut.p_sextw=0;
  dut.op_size=`AP040_SZ_L;dut.p_ssize=`AP040_SZ_L;dut.p_dsize=`AP040_SZ_L;
  dut.alu_op=`AP040_ALU_ADD;dut.ir=16'hd080;
  dut.pc=npc;dut.pc_i=npc-2;dut.sr=16'h2704;
  dut.regfile.dreg[0]=32'hffffffff;dut.regfile.dreg[1]=1;
  dut.regfile.isp=32'h7800;
  dut.epf_armed=1;dut.epf_pend=1;dut.epf_pend_lw=longword;
  dut.epf_super=1;dut.epf_kill=0;dut.epf_err=0;dut.epf_brf=0;
  dut.epf_count=0;dut.epf_head=qhead;dut.epf_fill=qhead;
  dut.epf_next=npc;dut.epf_ftail=npc;
  for(j=0;j<8;j=j+1) dut.epf_data[j]=16'hffff;
  dut.brf_valid=0;dut.brf_tag=npc[31:5];dut.brf_super=1;
  dut.mem_req=1;dut.mem_instr=1;dut.mem_write=0;dut.mem_addr=npc;
  dut.mem_size=longword ? `AP040_SZ_L : `AP040_SZ_W;
  dut.fc_r=`AP040_FC_SUPER_PROG;
  response=longword ? {opcode,16'h4e71} : {16'hdead,opcode};
  ack=1;
  #1;verify(dut.epf_fwd_pc,"setup forward channel");
 end
endtask

task tick;
 begin ce=1;@(posedge clk);#1;end
endtask

task successful(input integer id,input longword,input [31:0] npc,input [2:0] qhead,input pending_rf);
 begin
  setup(id,longword,npc,qhead,16'hd181); // ADDX.L D1,D0
  if(pending_rf) begin
   dut.regfile.dreg[0]=32'h12345678;
   dut.rf_we=1;dut.rf_waddr=0;dut.rf_wdata=32'hffffffff;
  end
  tick;
  verify(dut.rf_we && dut.rf_waddr==0 && dut.rf_wdata==32'hfffffffe,"producer result pending");
  verify(dut.sr[4:0]==5'b11001,"producer CCR visible");
  verify(!dut.epf_pend && !dut.mem_req,"ack ownership released");
  verify(dut.epf_fill==((qhead+(longword?2:1))&7),"response append/wrap");
  if(candidate) begin
   verify(dut.state==dut.S_PIPE_REGS && dut.ir==16'hd181,"actual opcode bypass");
   verify(dut.pc==npc+2 && dut.pc_i==npc,"single PC advancement");
   verify(dut.epf_count==(longword?1:0) && dut.epf_head==((qhead+1)&7),"append minus one pop");
   verify(dut.rr_a==1 && dut.rr_b==0 && dut.alu_op==`AP040_ALU_ADDX,"actual descriptor ports");
  end else begin
   verify(dut.state==dut.S_FETCH && dut.pc==npc,"baseline fetch boundary");
   verify(dut.epf_count==(longword?2:1) && dut.epf_head==qhead,"baseline append without pop");
  end
  if(longword) verify(dut.epf_data[(qhead+1)&7]==16'h4e71,"longword tail preserved");
  @(negedge clk);ack=0;
  repeat(7) begin @(posedge clk);#1;end
  verify(dut.regfile.dreg[0]==0,"ADDX consumes predecessor RAW/X");
  verify(dut.sr[4:0]==5'b10001,"ADDX carry and sticky zero");
  $display("FORWARD_CASE_PASS case=%0d architectural_chain lw=%b pending_rf=%b",id,longword,pending_rf);
 end
endtask

initial begin
 successful(1,1,32'h1000,0,0);
 successful(2,1,32'h101c,6,1);
 successful(3,0,32'h0ffe,7,0);
 // Auxiliary stack write retains the old fetch boundary.
 setup(4,1,32'h1000,0,16'hd181);
 dut.aux_we=1;dut.aux_sel=1;dut.aux_wdata=32'h7800;
 tick;
 verify(dut.state==dut.S_FETCH && dut.epf_count==2,"aux fallback");
 verify(dut.regfile.isp==32'h7800,"aux write retained");
 // Stale storage is valid ADDX; actual response is a non-descriptor NOP.
 setup(5,1,32'h1000,0,16'h4e71);dut.epf_data[0]=16'hd181;
 tick;
 verify(dut.state==dut.S_FETCH && dut.epf_count==2 && dut.epf_head==0,"nonregister response fallback");
 verify(dut.epf_data[0]==16'h4e71,"actual NOP queued");
 // Other fetch_next callers do not gain the bypass.
 setup(6,1,32'h1000,0,16'hd181);dut.state=dut.S_NEXT;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_count==2,"other producer fallback");
 // Killed, mismatched and faulting instruction responses cannot dispatch.
 setup(7,1,32'h1000,0,16'hd181);dut.epf_kill=1;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_count==0,"killed response discarded");
 setup(8,1,32'h1000,0,16'hd181);dut.epf_super=0;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_count==0,"context mismatch fallback");
 setup(9,1,32'h1000,0,16'hd181);dut.epf_next=32'h1002;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_count==0,"PC mismatch fallback");
 setup(10,1,32'h1000,0,16'hd181);fault=1;ack=0;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_err && dut.epf_count==0,"deferred speculative fault");
 setup(11,1,32'h1000,0,16'hd181);fault=1;
 tick;verify(dut.state==dut.S_FETCH && !dut.rd_queue_pop,"ack plus error no bypass");
 // Exception boundary wins while preserving the completed producer write.
 setup(12,1,32'h1000,0,16'hd181);dut.tr_t1=1;
 tick;
 verify(dut.state==dut.S_POST_EXC_F2 && dut.epf_count==0,"T1 boundary priority");
 verify(dut.rf_we && dut.rf_wdata==32'hfffffffe,"T1 producer commit barrier");
 setup(13,1,32'h1000,0,16'hd181);dut.irq_hold_lvl=3;
 tick;
 verify(dut.state==dut.S_POST_EXC && dut.epf_count==0,"IRQ boundary priority");
 verify(dut.rf_we && dut.rf_wdata==32'hfffffffe,"IRQ producer commit barrier");
 // Simulation-only force models a same-cycle earlier flush carrier.
 setup(14,1,32'h1000,0,16'hd181);force dut.epf_flushed=1;
 tick;verify(dut.state==dut.S_FETCH && dut.epf_count==0,"flush wins over response");
 @(negedge clk);release dut.epf_flushed;
 // A held response during CE gaps cannot pop, append or retire twice.
 setup(15,1,32'h1000,0,16'hd181);
 repeat(3) begin
  @(posedge clk);#1;
  verify(dut.state==dut.S_PIPE_REGS && dut.epf_count==0 && dut.pc==32'h1000 && !dut.rf_we,"CE gap stable");
 end
 @(negedge clk);tick;
 verify(dut.epf_count==(candidate?1:2),"single consume after CE gap");
 // Applicable T0 and combined IRQ/trace exercise the same retained barriers.
 setup(16,1,32'h1000,0,16'hd181);dut.tr_t0=1;dut.t0_force=1;
 tick;
 verify(dut.state==dut.S_POST_EXC_F2 && dut.epf_count==0,"applicable T0 priority");
 verify(dut.rf_we && dut.rf_wdata==32'hfffffffe,"T0 producer commit barrier");
 setup(17,1,32'h1000,0,16'hd181);dut.tr_t1=1;dut.irq_hold_lvl=3;
 tick;
 verify(dut.state==dut.S_POST_EXC && dut.exc_is_irq && dut.epf_count==0,"IRQ before simultaneous trace");
 verify(dut.texc_pend && dut.texc_pc==32'h0ffe,"trace retained behind IRQ");
 verify(dut.rf_we && dut.rf_wdata==32'hfffffffe,"IRQ trace producer barrier");
 $display("FORWARD_ALL_PASS candidate=%b checks=%0d cases=17",candidate,checks);
 $finish;
end
initial begin #100000;$fatal(1,"FORWARD_TIMEOUT");end
endmodule
