`timescale 1ps/1ps
// RAM-only instruction-level integration fixture. No ROM or OS emulation.
// Production CPU/store buffer/bus32/SDRAM bridge, with the current quadra800
// registered RAM service subset. MMU translation is explicitly disabled.
module tb_wombat_sieve;
localparam integer TR=5050, TS=3*TR;
reg clk_ram=0, clk_sys=0, nreset=0, init=1;
always #TR clk_ram=~clk_ram;
always #TS clk_sys=~clk_sys;
wire bus_req,bus_write,bus_instr,bus_ack,walker_req,walker_we;
wire [1:0] bus_size;
wire [31:0] bus_addr,bus_wdata,bus_rdata,walker_addr,walker_wdat,cacr;
wire [2:0] bus_fc;
wire fault,halted,stall_fault;
wire line_valid,line_pending;
wire [26:4] line_tag,line_pending_tag;
wire [127:0] line_data;

wombat_cpu cpu(
 .clk(clk_sys),.nreset(nreset),.ce(1'b1),.ipl(3'b111),.ipl_autovector(1'b1),
 .berr(1'b0),.stall_hold(1'b0),.dbg_stall_flt(stall_fault),
 .cache_line_valid(line_valid),.cache_line_tag({5'd0,line_tag}),
 .cache_line_data(line_data),.store_buffer_ok(1'b1),
 .bus_req(bus_req),.bus_write(bus_write),.bus_instr(bus_instr),
 .bus_size(bus_size),.bus_addr(bus_addr),.bus_wdata(bus_wdata),.bus_fc(bus_fc),
 .bus_ack(bus_ack),.bus_rdata(bus_rdata),
 .walker_req(walker_req),.walker_we(walker_we),.walker_addr(walker_addr),
 .walker_wdat(walker_wdat),.walker_ack(1'b0),.walker_data(32'd0),.walker_berr(1'b0),
 .snoop_stb(1'b0),.snoop_addr(32'd0),.nresetout(),.nmi_ack_toggle(),
 .cacr_out(cacr),.vbr_out(),.debug_busy(),.debug_fault(fault),
 .debug_halted(halted),.debug_status(),.debug_status2());

wire adapter_ack,adapter_active;
wire [31:0] adapter_rdata;
wire b_req,b_write;
wire [31:2] b_addr;
wire [3:0] b_be;
wire [31:0] b_wdata;
reg b_ack=0;
reg [31:0] b_rdata=0;
reg svc_mem=0,svc_bus_direct=0;
reg bus_line_ack=0,bus_miss_ack=0;
reg [31:0] bus_line_rdata=0,bus_miss_rdata=0;
reg mem_req=0,mem_write=0;
reg [26:2] mem_addr=0;
reg [3:0] mem_be=0;
reg [31:0] mem_wdata=0;
wire mem_ack,mem_busy;
wire [31:0] mem_rdata;

// Same eligibility and ACK registration as quadra800's low-RAM path.
// No overlay/device/walker arbitration here: an attempted walker is fatal.
wire bus_ram_eligible=!svc_mem && !walker_req && !bus_miss_ack &&
 !adapter_active && !adapter_ack && bus_req && !bus_write &&
 bus_size==2 && bus_addr[1:0]==0 && bus_addr[31:16]==0;
wire bus_line_match=bus_ram_eligible && line_valid && bus_addr[26:4]==line_tag;
wire bus_line_wait=bus_ram_eligible && line_pending && bus_addr[26:4]==line_pending_tag;
wire bus_first_miss=bus_ram_eligible && !bus_line_match && !bus_line_wait;
function automatic [31:0] line_word(input [1:0] word_index);
 case(word_index)
  0: line_word=line_data[127:96]; 1: line_word=line_data[95:64];
  2: line_word=line_data[63:32]; default: line_word=line_data[31:0];
 endcase
endfunction
wire line_cpu_match=!svc_mem && b_req && !b_write && line_valid && b_addr[26:4]==line_tag;
wire line_cpu_wait=!svc_mem && b_req && !b_write && line_pending && b_addr[26:4]==line_pending_tag;
assign bus_ack=bus_line_ack || bus_miss_ack || adapter_ack;
assign bus_rdata=bus_line_ack ? bus_line_rdata : bus_miss_ack ? bus_miss_rdata : adapter_rdata;
wombat_bus32 bus32(
 .clk(clk_sys),.nreset(nreset),.ce(1'b1),
 .t_req(bus_req && !bus_line_match && !bus_line_wait && !bus_first_miss && !svc_bus_direct && !bus_miss_ack),
 .t_write(bus_write),.t_size(bus_size),.t_addr(bus_addr),.t_wdata(bus_wdata),
 .t_berr(1'b0),.t_ack(adapter_ack),.t_rdata(adapter_rdata),.t_active(adapter_active),
 .b_req(b_req),.b_write(b_write),.b_addr(b_addr),.b_be(b_be),.b_wdata(b_wdata),
 .b_ack(b_ack),.b_rdata(b_rdata));

always @(posedge clk_sys) begin
 if(!nreset) begin
  bus_line_ack<=0;bus_line_rdata<=0;bus_miss_ack<=0;bus_miss_rdata<=0;
  b_ack<=0;b_rdata<=0;svc_mem<=0;svc_bus_direct<=0;mem_req<=0;
 end else begin
  bus_line_ack<=0;bus_miss_ack<=0;b_ack<=0;
  if(!bus_line_ack && bus_line_match) begin
   bus_line_ack<=1;bus_line_rdata<=line_word(bus_addr[3:2]);
  end
  if(!svc_mem) begin
   if(bus_first_miss || (b_req && !b_ack && !line_cpu_wait)) begin
    if(bus_first_miss) begin
     svc_mem<=1;svc_bus_direct<=1;mem_req<=1;mem_write<=0;
     mem_addr<=bus_addr[26:2];mem_be<=4'b1111;mem_wdata<=0;
    end else if(line_cpu_match) begin
     b_ack<=1;b_rdata<=line_word(b_addr[3:2]);
    end else begin
     svc_mem<=1;svc_bus_direct<=0;mem_req<=1;mem_write<=b_write;
     mem_addr<=b_addr[26:2];mem_be<=b_be;mem_wdata<=b_wdata;
    end
   end
  end else if(mem_ack) begin
   mem_req<=0;svc_mem<=0;svc_bus_direct<=0;
   if(svc_bus_direct) begin bus_miss_ack<=1;bus_miss_rdata<=mem_rdata;end
   else begin b_ack<=1;b_rdata<=mem_rdata;end
  end
 end
end

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire SDRAM_DQML,SDRAM_DQMH;
wire [1:0] SDRAM_BA;
wire SDRAM_nCS,SDRAM_nWE,SDRAM_nRAS,SDRAM_nCAS,SDRAM_CKE,SDRAM_CLK;
sdram_beat32 sdr(
 .init(init),.clk_sys(clk_sys),.clk_ram(clk_ram),.req(mem_req),.we(mem_write),
 .addr(mem_addr),.be(mem_be),.wdata(mem_wdata),.ack(mem_ack),.rdata(mem_rdata),.busy(mem_busy),
 .line_valid_o(line_valid),.line_tag_o(line_tag),.line_data_o(line_data),
 .line_pending_o(line_pending),.line_pending_tag_o(line_pending_tag),
 .SDRAM_DQ(SDRAM_DQ),.SDRAM_A(SDRAM_A),.SDRAM_DQML(SDRAM_DQML),.SDRAM_DQMH(SDRAM_DQMH),
 .SDRAM_BA(SDRAM_BA),.SDRAM_nCS(SDRAM_nCS),.SDRAM_nWE(SDRAM_nWE),.SDRAM_nRAS(SDRAM_nRAS),
 .SDRAM_nCAS(SDRAM_nCAS),.SDRAM_CKE(SDRAM_CKE),.SDRAM_CLK(SDRAM_CLK));
sdram_model chip(
 .clk(SDRAM_CLK),.cke(SDRAM_CKE),.nCS(SDRAM_nCS),.nRAS(SDRAM_nRAS),.nCAS(SDRAM_nCAS),
 .nWE(SDRAM_nWE),.ba(SDRAM_BA),.a(SDRAM_A),.dqmh(SDRAM_DQMH),.dqml(SDRAM_DQML),.dq(SDRAM_DQ));

reg [15:0] image[0:32767];
reg expected[0:8190];
integer expected_count=0;
integer kernel_pc='h2000,maxcycles=4000000;
integer i,n,divisor,a,wanted,got;
reg prime;
reg [31:0] byte_addr;
string program_path;
initial begin
 if(!$value$plusargs("prog=%s",program_path)) $fatal(1,"+prog required");
 if($value$plusargs("kernelpc=%h",kernel_pc)) begin end
 if($value$plusargs("maxcycles=%d",maxcycles)) begin end
 for(i=0;i<32768;i=i+1) image[i]='hffff;
 $readmemh(program_path,image);
 // Exact inverse of sdram_model.peek/controller address decode.
 for(i=0;i<32768;i=i+1) begin
  byte_addr=i*2;
  chip.mem[chip.key(byte_addr[24:23],byte_addr[22:10],{byte_addr[25],byte_addr[9:1]})]=image[i];
 end
 for(i=0;i<8191;i=i+1) begin
  n=2*i+3;prime=1;
  for(divisor=3;divisor*divisor<=n;divisor=divisor+2)
   if(n%divisor==0) prime=0;
  expected[i]=prime;if(prime) expected_count=expected_count+1;
 end
 repeat(4) @(negedge clk_sys);
 init=0;
 repeat(13000) @(negedge clk_ram);
 @(negedge clk_sys);nreset=1;
 $display("INTEGRATION_CONFIG kernelpc=%04x clk_sys_half_ps=%0d clk_ram_half_ps=%0d ce=1 cache=1 store_buffer=1 sideband=1 registered_ram_ack=1 overlay=0 irq=none mmu_fixture=disabled",kernel_pc,TS,TR);
end

function automatic integer memory_byte(input [31:0] address);
 reg [15:0] word_value;
 begin
  word_value=chip.peek(address[26:2],address[1]);
  memory_byte=address[0] ? word_value[7:0] : word_value[15:8];
 end
endfunction

integer total_cycles=0,elapsed=0,dispatches=0,requests=0,killed=0;
integer ihit=0,imiss=0,ipred=0,dhit=0,dmiss=0,mem_reads=0,mem_writes=0;
integer bus_line_hits=0,first_misses=0,store_pushes=0,store_pops=0;
integer states[0:255],cache_states[0:15],sb_count[0:2],op_count[0:40];
integer pre_state,slot;
integer srd_calls=0,srd_fast=0,srd_slow=0,srd_other=0;
integer srd_guard[0:7],srd_cache[0:15];
integer srd_pending_ack=0,srd_ack_instr=0,mrd_setup=0,mrd_wait_prefetch=0;
integer guard_mask;
wire srd_address_ok=(cpu.core.ea_addr[31:28]==0) &&
 ((cpu.core.p_ssize==0) || (cpu.core.p_ssize==1 && !cpu.core.ea_addr[0]) ||
 (cpu.core.p_ssize==2 && cpu.core.ea_addr[1:0]==0));
reg active=0,pre_pend,dispatch_seen=0;
wire [31:0] effective_d6=(cpu.core.rf_we && cpu.core.rf_waddr==6) ? cpu.core.rf_wdata : cpu.core.regfile.dreg[6];
initial begin
 for(i=0;i<256;i=i+1) states[i]=0;
 for(i=0;i<16;i=i+1) cache_states[i]=0;
 for(i=0;i<3;i=i+1) sb_count[i]=0;
 for(i=0;i<41;i=i+1) op_count[i]=0;
 for(i=0;i<8;i=i+1) srd_guard[i]=0;
 for(i=0;i<16;i=i+1) srd_cache[i]=0;
end
always @(posedge clk_sys) begin
 if(nreset) begin
  total_cycles=total_cycles+1;
  if(total_cycles>maxcycles) $fatal(1,"INTEGRATION_TIMEOUT pc=%h state=%d",cpu.core.pc_i,cpu.core.state);
  if(walker_req || cpu.w_tc!=0 || fault || halted || stall_fault)
   $fatal(1,"INTEGRATION_FAULT walker=%b tc=%h fault=%b halted=%b stall=%b pc=%h",walker_req,cpu.w_tc,fault,halted,stall_fault,cpu.core.pc_i);
  if(bus_req && bus_addr[31:16]!=0) $fatal(1,"INTEGRATION_ADDRESS %h",bus_addr);
  pre_state=cpu.core.state;pre_pend=cpu.core.epf_pend;
  if(active) begin
   elapsed=elapsed+1;states[pre_state]=states[pre_state]+1;
   cache_states[cpu.g_cache.cache.cst]=cache_states[cpu.g_cache.cache.cst]+1;
   sb_count[cpu.store_buffer.count]=sb_count[cpu.store_buffer.count]+1;
   if(pre_state==22) begin
    srd_calls=srd_calls+1;
    guard_mask={cpu.core.epf_pend,cpu.mem_req,cpu.mem_ack};
    srd_guard[guard_mask]=srd_guard[guard_mask]+1;
    srd_cache[cpu.g_cache.cache.cst]=srd_cache[cpu.g_cache.cache.cst]+1;
    if(!srd_address_ok) srd_other=srd_other+1;
    if(cpu.core.epf_pend && cpu.mem_ack) srd_pending_ack=srd_pending_ack+1;
    if(cpu.mem_ack && cpu.mem_instr) srd_ack_instr=srd_ack_instr+1;
   end
   if(pre_state==9 && !cpu.core.m_issued) begin
    if(cpu.core.epf_pend) mrd_wait_prefetch=mrd_wait_prefetch+1;
    else mrd_setup=mrd_setup+1;
   end
   // Bounded pre-edge timeline for only the first TST indexed source.
   if(cpu.core.pc_i==kernel_pc+28 && cpu.core.regfile.dreg[3]==0 &&
      (pre_state==8 || pre_state==14 || pre_state==15 ||
       pre_state==22 || pre_state==9 || pre_state==23))
    $display("MRD_TIMELINE edge=%0d state=%0d pend=%b req=%b ack=%b instr=%b issued=%b iaddr=%h cache=%0d ipred=%b",
     total_cycles,pre_state,cpu.core.epf_pend,cpu.mem_req,cpu.mem_ack,
     cpu.mem_instr,cpu.core.m_issued,cpu.mem_addr,cpu.g_cache.cache.cst,cpu.g_cache.cache.ipred_hit);
   if(cpu.g_cache.cache.ipred_hit) ipred=ipred+1;
   if(cpu.g_cache.cache.cst==1) begin
    if(cpu.g_cache.cache.r_bank) begin
     if(cpu.g_cache.cache.look_hit) ihit=ihit+1;else imiss=imiss+1;
    end else begin
     if(cpu.g_cache.cache.look_hit) dhit=dhit+1;else dmiss=dmiss+1;
    end
   end
   if(cpu.core.epf_pend && cpu.core.i_ack && cpu.core.epf_kill) killed=killed+1;
   if(mem_ack) begin if(mem_write) mem_writes=mem_writes+1;else mem_reads=mem_reads+1;end
   if(bus_line_ack) bus_line_hits=bus_line_hits+1;
   if(bus_first_miss) first_misses=first_misses+1;
   if(cpu.store_buffer.push) store_pushes=store_pushes+1;
   if(cpu.store_buffer.pop) store_pops=store_pops+1;
  end
  #1;
  if(!active && cpu.core.state==4 && cpu.core.pc_i==kernel_pc) begin
   active=1;dispatch_seen=cpu.core.perf_dispatch_toggle;
   $display("INTEGRATION_BEGIN cacr=%08x tc=%08x",cacr,cpu.w_tc);
  end else if(active) begin
   if(pre_state==22) begin
    if(cpu.core.state!=9) $fatal(1,"MRD_GUARD unexpected return state");
    if(cpu.core.m_issued) srd_fast=srd_fast+1;else srd_slow=srd_slow+1;
   end
   if(!pre_pend && cpu.core.epf_pend) requests=requests+1;
   if(dispatch_seen!=cpu.core.perf_dispatch_toggle) begin
    dispatch_seen=cpu.core.perf_dispatch_toggle;dispatches=dispatches+1;
    slot=(cpu.core.pc_i>=kernel_pc && cpu.core.pc_i<kernel_pc+80) ? (cpu.core.pc_i-kernel_pc)/2 : 40;
    op_count[slot]=op_count[slot]+1;
   end
   if(cpu.core.state==4 && cpu.core.pc_i==kernel_pc+74 && effective_d6==1) begin
    // The long final scan leaves no stores outstanding. Require that invariant
    // explicitly before reading backing RAM; never mistake queued data for loss.
    if(cpu.buffered_store_pending || cpu.store_buffer.drain_active || (svc_mem && mem_write))
     $fatal(1,"INTEGRATION_UNDRAINED_STORES");
    if(cpu.core.regfile.dreg[7]!==expected_count || cpu.core.regfile.areg[2]!==32'h4000)
     $fatal(1,"INTEGRATION_ORACLE registers D7=%d A2=%h",cpu.core.regfile.dreg[7],cpu.core.regfile.areg[2]);
    for(a='h3fe0;a<'h6020;a=a+1) begin
     got=memory_byte(a);
     if(a>='h4000 && a<='h5ffe) wanted=expected[a-'h4000] ? 1 : 0;
     else wanted=a[0] ? 'h5a : 'ha5;
     if(got!==wanted) $fatal(1,"INTEGRATION_ORACLE addr=%h got=%h wanted=%h",a,got,wanted);
    end
    if(chip.errors!=0) $fatal(1,"INTEGRATION_SDRAM_PROTOCOL errors=%d",chip.errors);
    $display("INTEGRATION_COMPLETE kind=partial_first_outer_pass kernelpc=%04x cycles=%0d enabled_cycles=%0d D6=%0d D7=%0d array=PASS guards=PASS drained=PASS cacr=%08x tc=%08x dispatches=%0d requests=%0d ihit=%0d ipred=%0d imiss=%0d dhit=%0d dmiss=%0d killed=%0d mem_reads=%0d mem_writes=%0d line_acks=%0d first_misses=%0d store_pushes=%0d store_pops=%0d",kernel_pc,elapsed,elapsed,effective_d6,cpu.core.regfile.dreg[7],cacr,cpu.w_tc,dispatches,requests,ihit,ipred,imiss,dhit,dmiss,killed,mem_reads,mem_writes,bus_line_hits,first_misses,store_pushes,store_pops);
    for(a=0;a<256;a=a+1) if(states[a]) $display("INTEGRATION_STATE state=%0d cycles=%0d",a,states[a]);
    for(a=0;a<16;a=a+1) if(cache_states[a]) $display("INTEGRATION_CACHE state=%0d cycles=%0d",a,cache_states[a]);
    for(a=0;a<3;a=a+1) $display("INTEGRATION_SB count=%0d cycles=%0d",a,sb_count[a]);
    for(a=0;a<41;a=a+1) if(op_count[a]) $display("INTEGRATION_DISPATCH pc=%04x count=%0d",kernel_pc+2*a,op_count[a]);
    $display("MRD_GUARD calls=%0d early_issue=%0d deferred=%0d address_or_size_fail=%0d pending_with_ack=%0d instruction_ack=%0d mrd_setup=%0d mrd_wait_prefetch=%0d",
     srd_calls,srd_fast,srd_slow,srd_other,srd_pending_ack,srd_ack_instr,mrd_setup,mrd_wait_prefetch);
    for(a=0;a<8;a=a+1) if(srd_guard[a])
     $display("MRD_GUARD_MASK pend_req_ack=%03b count=%0d",a[2:0],srd_guard[a]);
    for(a=0;a<16;a=a+1) if(srd_cache[a])
     $display("MRD_GUARD_CACHE state=%0d count=%0d",a,srd_cache[a]);
    chip.report_timing();$finish;
   end
  end
 end else dispatch_seen=cpu.core.perf_dispatch_toggle;
end
endmodule
