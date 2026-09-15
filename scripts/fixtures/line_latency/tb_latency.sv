`timescale 1ns/1ps
module tb_latency;
reg clk=0,nreset=0,ce=1;
always #5 clk=~clk;
wire req,wr,instr,wreq,wwe;
wire [1:0] size;
wire [31:0] addr,wdata,waddr,wwdata,cacr;
wire [2:0] fc;
reg ack=0,wack=0,berr=0;
reg [31:0] rdata=0,wrdata=0;
reg snoop=0;
wire fault,halted;
wombat_cpu cpu(.clk(clk),.nreset(nreset),.ce(ce),.ipl(3'b111),.ipl_autovector(1'b1),
 .berr(berr),.stall_hold(1'b0),.dbg_stall_flt(),
 .cache_line_valid(1'b0),.cache_line_tag(28'd0),.cache_line_data(128'd0),.store_buffer_ok(1'b1),
 .bus_req(req),.bus_write(wr),.bus_instr(instr),.bus_size(size),.bus_addr(addr),.bus_wdata(wdata),
 .bus_fc(fc),.bus_ack(ack),.bus_rdata(rdata),.walker_req(wreq),.walker_we(wwe),
 .walker_addr(waddr),.walker_wdat(wwdata),.walker_ack(wack),.walker_data(wrdata),.walker_berr(1'b0),
 .snoop_stb(snoop),.snoop_addr(32'h4000),.nresetout(),.nmi_ack_toggle(),.cacr_out(cacr),.vbr_out(),
 .debug_busy(),.debug_fault(fault),.debug_halted(halted),.debug_status(),.debug_status2());
reg [7:0] mem[0:65535];
integer buswait=0,walkwait=0;
reg injected_error=0;
function automatic [31:0] read_mem(input [31:0] a,input [1:0] sz);
 case(sz)
 0:read_mem={24'd0,mem[a[15:0]]};
 1:read_mem={16'd0,mem[a[15:0]],mem[(a+1)&65535]};
 default:read_mem={mem[a[15:0]],mem[(a+1)&65535],mem[(a+2)&65535],mem[(a+3)&65535]};
 endcase
endfunction
integer i,bytes;
always @(posedge clk) begin
 if(!nreset)begin ack<=0;wack<=0;berr<=0;buswait<=0;walkwait<=0;end
 else begin
  ack<=0;wack<=0;berr<=0;
  if(!req)buswait<=0;
  else if(!ack && !berr)begin
   if(buswait==2)begin
    buswait<=0;
    if(!injected_error && !wr && addr==32'he000 && cpu.core.regfile.dreg[7]==9)begin
     berr<=1;injected_error<=1;
    end else begin
     ack<=1;rdata<=read_mem(addr,size);
     if(wr)begin
      bytes=1<<size;
      for(i=0;i<bytes;i=i+1)mem[(addr+i)&65535]<=wdata>>(8*(bytes-1-i));
      if(addr==32'hf100)begin
       if(wdata[15:0]!=16'h600d)$fatal(1,"guest oracle FAIL phase=%0d",cpu.core.regfile.dreg[7]);
       $display("LATENCY_GUEST_PASS cycles=%0d ce_pause=%b snoop=%b error=%b",edge_count,pause_done,snoop_done,injected_error);
       #2;$finish;
      end
     end
    end
   end else buswait<=buswait+1;
  end
  if(!wreq)walkwait<=0;
  else if(!wack)begin
   if(walkwait==1)begin
    walkwait<=0;wack<=1;wrdata<=read_mem(waddr,2);
    if(wwe)for(i=0;i<4;i=i+1)mem[(waddr+i)&65535]<=wwdata>>(8*(3-i));
   end else walkwait<=walkwait+1;
  end
 end
end
reg pause_done=0,snoop_done=0;
integer pause_left=0;
always @(negedge clk) begin
 snoop<=0;
 if(nreset)begin
  if(!pause_done && cpu.core.regfile.dreg[7]==7 && cpu.mem_req && !cpu.mem_instr && !cpu.mem_write)begin
   ce<=0;pause_left=3;pause_done<=1;
  end else if(pause_left>0)begin
   pause_left=pause_left-1;if(!pause_left)ce<=1;
  end
  if(!snoop_done && cpu.core.regfile.dreg[7]==8 && cpu.g_cache.cache.rd_accept && !cpu.mem_instr)begin
   snoop<=1;snoop_done<=1;
  end
 end
end
string program_path;
initial begin
 if(!$value$plusargs("prog=%s",program_path))$fatal(1,"prog required");
 for(integer j=0;j<65536;j=j+1)mem[j]=0;
 $readmemh(program_path,mem);
 repeat(4)@(negedge clk);nreset=1;
end

// Observational only: simulate data-RAM read metadata for an otherwise idle
// cache. No DUT signal/state is assigned. All completion/latency comes from
// unchanged accepted RTL. Row/word/bank are page-offset indexed; admission
// still requires the real MMU's translated and permission-qualified request.
integer edge_count=0,start_edge=0,mm_edge,accept_edge,look_edge,visible_edge;
integer txns=0,stalls=0,phase,owner;
reg tracked=0,tx_instr,tx_write,tx_hit,tx_pred,tx_miss,tx_pass,tx_walk,tx_fault;
reg tx_early,tx_current;
reg [31:0] tx_addr;
reg [31:0] tx_early_data;
reg shadow_valid=0,tag_valid=0,shadow_current=0;
reg [8:0] shadow_idx;
reg [6:0] tag_idx;
reg [31:0] shadow_data[0:3];
reg [31:0] shadow_la;
integer way;
reg direct_hit,eligible;
reg [31:0] prospective;
always @(posedge clk)begin
 edge_count=edge_count+1;
 if(edge_count>200000)$fatal(1,"timeout pc=%h state=%0d phase=%0d",cpu.core.pc_i,cpu.core.state,cpu.core.regfile.dreg[7]);
 if(tracked)begin
  if(!ce)stalls=stalls+1;
  if(mm_edge<0 && cpu.mm_req)mm_edge=edge_count;
  if(ce && cpu.g_cache.cache.cst==0 && cpu.mm_req && !cpu.g_cache.cache.ack_r && accept_edge<0)begin
   accept_edge=edge_count;
   direct_hit=0;prospective=0;
   for(way=0;way<4;way=way+1)begin
    if(cpu.g_cache.cache.tag_q[88+way] && cpu.g_cache.cache.tag_q[22*way+:22]==cpu.mm_addr[31:10])begin
     direct_hit=1;prospective=shadow_data[(way+cpu.mm_addr[3:2])&3];
    end
   end
   eligible=cpu.g_cache.cache.rd_accept && !cpu.g_cache.cache.ipred_hit &&
    shadow_valid && shadow_idx=={cpu.mm_instr,cpu.mm_addr[9:2]} &&
    tag_valid && tag_idx=={cpu.mm_instr,cpu.mm_addr[9:4]} && direct_hit &&
    !cpu.g_cache.cache.snoop_look_row && !cpu.g_cache.cache.look_snooped &&
    !cpu.g_cache.cache.err_hold;
   tx_early=eligible;tx_current=eligible && shadow_current && shadow_la==tx_addr;
   tx_early_data=cpu.g_cache.cache.lw_extract(prospective,cpu.mem_size,cpu.mem_addr[1:0]);
   if(eligible && !tx_instr && phase>0)$display("SHADOW_EARLY phase=%0d pc=%h logical=%h physical=%h current_request_read=%b",phase,owner,tx_addr,cpu.mm_addr,tx_current);
  end
  if(ce && cpu.g_cache.cache.ipred_hit)tx_pred=1;
  if(ce && cpu.g_cache.cache.idle_hit)begin
   tx_hit=1;
   $display("IDLE_HIT phase=%0d instr=%b pc=%h logical=%h physical=%h",phase,tx_instr,owner,tx_addr,cpu.mm_addr);
  end
  if(ce && cpu.g_cache.cache.cst==1)begin
   if(look_edge<0)look_edge=edge_count;
   if(cpu.g_cache.cache.look_hit && !cpu.g_cache.cache.look_snooped && !cpu.g_cache.cache.snoop_look_row)tx_hit=1;
   else tx_miss=1;
  end
  if(cpu.g_cache.cache.cst==6)tx_pass=1;
  if(wreq)tx_walk=1;
  if(ce && (cpu.mem_ack || cpu.core.mem_err))begin
   tx_fault=cpu.core.mem_err;
   if(tx_early && tx_hit && !tx_fault && cpu.mem_rdata!==tx_early_data)
    $fatal(1,"shadow early-read data mismatch pc=%h expected=%h actual=%h",owner,tx_early_data,cpu.mem_rdata);
   $display("LATENCY_TX id=%0d phase=%0d pc=%h addr=%h instr=%b write=%b tc=%b issue=%0d mm=%0d accept=%0d look=%0d ack_visible=%0d consume=%0d cycles=%0d ce_stalls=%0d hit=%b pred=%b miss=%b pass=%b walk=%b fault=%b early=%b current_read=%b data=%h",
    txns,phase,owner,tx_addr,tx_instr,tx_write,cpu.core.tc[15],start_edge,mm_edge,accept_edge,look_edge,visible_edge,edge_count,edge_count-start_edge,stalls,tx_hit,tx_pred,tx_miss,tx_pass,tx_walk,tx_fault,tx_early,tx_current,cpu.mem_rdata);
   tracked=0;
  end
 end
 // Prior speculative read is judged above; this edge advances shadow RAM
 // metadata with the same priority as the production ipred/accepted reads.
 if(!nreset)begin shadow_valid=0;tag_valid=0;end
 else begin
  if(ce && |cpu.g_cache.cache.cd_we && cpu.g_cache.cache.cd_widx==shadow_idx)shadow_valid=0;
  tag_idx=cpu.g_cache.cache.tag_we?cpu.g_cache.cache.tag_widx:cpu.g_cache.cache.tag_ridx;
  tag_valid=!cpu.g_cache.cache.tag_we && !(cpu.g_cache.cache.inv_wren && cpu.g_cache.cache.inv_idx==tag_idx);
  if(ce && (cpu.g_cache.cache.cd_rd_en || cpu.g_cache.cache.cst==0))begin
   shadow_idx=cpu.g_cache.cache.cd_ridx;
   shadow_valid=!(|cpu.g_cache.cache.cd_we && cpu.g_cache.cache.cd_widx==shadow_idx);
   shadow_current=cpu.mem_req && !cpu.mm_req;
   shadow_la=cpu.mem_addr;
   shadow_data[0]=cpu.g_cache.cache.cdata0[{shadow_idx[8:2],2'd0-shadow_idx[1:0]}];shadow_data[1]=cpu.g_cache.cache.cdata1[{shadow_idx[8:2],2'd1-shadow_idx[1:0]}];
   shadow_data[2]=cpu.g_cache.cache.cdata2[{shadow_idx[8:2],2'd2-shadow_idx[1:0]}];shadow_data[3]=cpu.g_cache.cache.cdata3[{shadow_idx[8:2],2'd3-shadow_idx[1:0]}];
  end
 end
 #1;
 if(tracked && visible_edge<0 && cpu.mem_ack)visible_edge=edge_count;
 if(nreset && !tracked && cpu.mem_req)begin
  txns=txns+1;tracked=1;start_edge=edge_count;tx_addr=cpu.mem_addr;
  tx_instr=cpu.mem_instr;tx_write=cpu.mem_write;owner=cpu.core.pc_i;phase=cpu.core.regfile.dreg[7];
  mm_edge=-1;accept_edge=-1;look_edge=-1;visible_edge=-1;stalls=0;
  tx_hit=0;tx_pred=0;tx_miss=0;tx_pass=0;tx_walk=0;tx_fault=0;tx_early=0;tx_current=0;
 end
 if(halted)$fatal(1,"CPU halted");
end
endmodule
