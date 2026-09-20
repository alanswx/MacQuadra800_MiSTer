#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,random,subprocess
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description="Profile original Speedometer integer kernels on CPU/cache/RAM; not a hardware score.")
parser.add_argument('resource',type=Path)
parser.add_argument('--kernel',choices=('quick','sieve'),default='quick',help='original integer kernel; sieve runs one full pass without Mac allocation')
parser.add_argument('--out',type=Path,required=True)
parser.add_argument('--latencies',type=int,nargs='+',default=[3],help='controlled RAM latency values, default 3')
parser.add_argument('--alu',type=Path,help='optional isolated ALU; applies to both compared pipeline modules')
parser.add_argument('--muldiv',type=Path,help='optional isolated multiply/divide unit')
parser.add_argument('--core',type=Path,help='optional isolated candidate CPU core')
parser.add_argument('--compare-module',type=Path,help='optional alternative pipeline module; core and entry policy remain identical')
parser.add_argument('--early-drain',action='store_true',help='enable final-WB pipeline handoff')
parser.add_argument('--compare',action='store_true',help='enable indexed CMP/TST and register TST')
parser.add_argument('--disassemble',action='store_true',help='write kernel.dis using Python capstone')
parser.add_argument('--profile',action='store_true',help='report legacy opcode occupancy and pipeline exits')
args=parser.parse_args()
if any(n<0 for n in args.latencies): parser.error('latencies must be nonnegative')
d=args.out.resolve();d.mkdir(parents=True,exist_ok=True);rtl=r/'rtl/ap68040/rtl' 
resource=args.resource.read_bytes()
assert hashlib.sha256(resource).hexdigest()=='af67113bceb4eb906e973a9b747a0b1925b9d64c62f0f9a84bc6f0578839ca80'
start,end=(0x93ce,0x946e) if args.kernel=='quick' else (0xb6a,0xbae)
kernel=resource[82+0x6250f+start:82+0x6250f+end];(d/(args.kernel+'.bin')).write_bytes(kernel)
if args.disassemble:
 from capstone import Cs,CS_ARCH_M68K,CS_MODE_BIG_ENDIAN,CS_MODE_M68K_040
 instructions=list(Cs(CS_ARCH_M68K,CS_MODE_BIG_ENDIAN|CS_MODE_M68K_040).disasm(kernel,start))
 assert sum(i.size for i in instructions)==len(kernel), 'incomplete disassembly'
 (d/'kernel.dis').write_text(''.join(f'{i.address:04x} {i.bytes.hex():12} {i.mnemonic:10} {i.op_str}\n' for i in instructions))
values=list(range(-250,250));random.Random(20260919).shuffle(values)
asm=''' org 0
 dc.l $e000,start
 rept 254
 dc.l unexpected
 endr
 org $400
start:
 move.w #$2700,sr
 move.l #$80008000,d0
 movec d0,cacr
 lea ($8000).l,a5
 lea ($c000).l,a2
 move.w #500,-(sp)
 move.w #1,-(sp)
 move.l a2,-(sp)
 jsr ($93ce).l
 addq.w #8,sp
 move.w #$600d,($f102).l
 stop #$2700
unexpected:
 move.w #$bad0,($f102).l
 stop #$2700
 org $93ce
 incbin "'''+str(d/(args.kernel+'.bin'))+'''"
 org $c000
 dc.w $a55a
'''+''.join(' dc.w '+','.join('$%04x'%(x&65535) for x in values[i:i+20])+'\n' for i in range(0,500,20))+' dc.w $5aa5\n'
if args.kernel=='sieve':
 # Every flag denotes the odd integer 2*i+3. Trial division is independent
 # of the guest's sieve algorithm and checks all output bytes, not just count.
 def prime(n):
  return n>=2 and all(n%k for k in range(2,__import__('math').isqrt(n)+1))
 expected=[int(prime(2*i+3)) for i in range(8191)]
 (d/'expected.hex').write_text(''.join(f'{v:02x}\n' for v in expected))
 values={'odd_first':3,'odd_last':16383,'count':sum(expected),'flags':8191}
 asm=''' org 0
 dc.l $e000,start
 rept 254
 dc.l unexpected
 endr
 org $400
start:
 move.w #$2700,sr
 move.l #$80008000,d0
 movec d0,cacr
 lea ($8000).l,a5
 lea ($9000).l,a2
 jsr ($0b6a).l
 move.w d7,($f100).l
 move.w #$600d,($f102).l
 stop #$2700
unexpected:
 move.w #$bad0,($f102).l
 stop #$2700
 org $0b6a
 incbin "'''+str(d/(args.kernel+'.bin'))+'''"
 rts
 org $8ffe
 dc.w $a55a
 org $afff
 dc.b $5a,$a5
'''
(d/(args.kernel+'.s')).write_text(asm)
def run(cmd,path):
 with path.open('w') as f:subprocess.run(list(map(str,cmd)),stdout=f,stderr=subprocess.STDOUT,check=True)
run(['/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot','-Fbin','-m68040','-no-opt','-o',d/'program.bin',d/(args.kernel+'.s')],d/'asm.log')
assert (d/'program.bin').read_bytes()[start:end]==kernel
run(['python3',r/'rtl/ap68040/tb/bin2hex.py',d/'program.bin',d/'program.hex'],d/'hex.log')
# Self-contained responder and independent sorted-permutation checks.
s=r'''// Original Speedometer Quick Sort recursive routine through wombat_cpu's real
// MMU/cache/store buffer. The RAM responder is a controlled-latency model,
// NOT quadra800's SDRAM controller; these cycles are not hardware Mix scores.
// Memory is byte-addressed, so word-aligned but non-longword-aligned stack
// transfers use the same unsplit 32-bit transaction contract as the platform.
`timescale 1ns/1ps
module tb_cpu_quick;
 reg clk=0; always #15 clk=~clk;
 reg nreset=0;
 wire req, wr, instr, walker_req, fault, halted;
 wire [1:0] size;
 wire [31:0] addr, wdata;
 reg ack=0;
 reg [31:0] rdata=0;
 reg [15:0] mem[0:32767];
 integer latency=1, waitleft=0, cycles=0, i, j, bytes, done=0;
 integer states[0:255];
 integer lat_count[0:2], lat_total[0:2], lat_start=-1, lat_class;
 integer buffer_hits=0, buffer_saving=0;
 reg shadow_valid=0; reg [27:0] shadow_tag=0;
 reg pending=0;
 reg [31:0] saved_addr, saved_data;
 reg [1:0] saved_size;
 reg saved_wr;
 reg [1023:0] path;
 wombat_cpu dut(.clk(clk),.nreset(nreset),.ce(1'b1),.ipl(3'b111),
 .ipl_autovector(1'b1),.berr(1'b0),.stall_hold(1'b0),.dbg_stall_flt(),
 .cache_line_valid(1'b0),.cache_line_tag(28'd0),.cache_line_data(128'd0),
 .store_buffer_ok(1'b1),.bus_req(req),.bus_write(wr),.bus_instr(instr),
 .bus_size(size),.bus_addr(addr),.bus_wdata(wdata),.bus_fc(),
 .bus_ack(ack),.bus_rdata(rdata),.walker_req(walker_req),.walker_we(),
 .walker_addr(),.walker_wdat(),.walker_ack(1'b0),.walker_data(32'd0),
 .walker_berr(1'b0),.snoop_stb(1'b0),.snoop_addr(32'd0),.nresetout(),
 .nmi_ack_toggle(),.cacr_out(),.vbr_out(),.debug_busy(),
 .debug_fault(fault),.debug_halted(halted),.debug_status(),.debug_status2());
 function [7:0] readbyte(input integer a);
  if(a<0 || a>=65536) $fatal(1,"RAM address out of range %h",a);
  readbyte = a[0] ? mem[a>>1][7:0] : mem[a>>1][15:8];
 endfunction
 task writebyte(input integer a,input [7:0] value);
  if(a<0 || a>=65536) $fatal(1,"RAM write out of range %h",a);
  if(a[0]) mem[a>>1][7:0]=value; else mem[a>>1][15:8]=value;
 endtask
 initial begin
  if(!$value$plusargs("prog=%s",path)) $fatal(1,"missing program");
  if($value$plusargs("latency=%d",latency)) begin end
  for(i=0;i<32768;i=i+1) mem[i]=0;
  for(i=0;i<256;i=i+1) states[i]=0;
  for(i=0;i<3;i=i+1) begin lat_count[i]=0;lat_total[i]=0;end
  $readmemh(path,mem);
  repeat(20) @(negedge clk);
  nreset=1;
 end
 always @(posedge clk) if(nreset) begin
  cycles=cycles+1; states[dut.core.state]=states[dut.core.state]+1;
  if(walker_req || fault || halted) $fatal(1,"unexpected CPU fault/walker/halt pc=%h",dut.core.pc_i);
  if(cycles>100000000) $fatal(1,"timeout pc=%h",dut.core.pc_i);
  if(dut.mem_req && lat_start<0) begin
   lat_start=cycles;lat_class=dut.mem_instr?0:(dut.mem_write?2:1);
  end
  if(dut.mem_ack && lat_start>=0) begin
   if(!dut.mem_instr) begin
    if(dut.mem_write) shadow_valid=0;
    else begin
     if(shadow_valid && shadow_tag==dut.mem_addr[31:4] &&
        ({1'b0,dut.mem_addr[3:0]} + (dut.mem_size==0?1:(dut.mem_size==1?2:4)))<=16) begin
      buffer_hits=buffer_hits+1;buffer_saving=buffer_saving+cycles-lat_start;
     end
     shadow_valid=1;shadow_tag=dut.mem_addr[31:4];
    end
   end
   lat_count[lat_class]=lat_count[lat_class]+1;
   lat_total[lat_class]=lat_total[lat_class]+cycles-lat_start+1;
   lat_start=-1;
  end
  ack<=0;
  if(pending) begin
   if(!req || addr!==saved_addr || (saved_wr && wdata!==saved_data) || wr!==saved_wr || size!==saved_size)
    $fatal(1,"request changed before ack req=%b addr=%h/%h size=%h/%h wr=%b/%b data=%h/%h",req,addr,saved_addr,size,saved_size,wr,saved_wr,wdata,saved_data);
   if(waitleft>0) waitleft<=waitleft-1;
   else begin
    pending<=0;ack<=1;
    bytes=saved_size==0?1:(saved_size==1?2:4);
    rdata=0;
    for(j=0;j<bytes;j=j+1) begin
     if(saved_wr) writebyte(saved_addr+j,saved_data>>(8*(bytes-j-1)));
     else rdata=(rdata<<8)|readbyte(saved_addr+j);
    end
    if(saved_wr && saved_addr==32'hf102) begin
     if(saved_data[15:0]!=16'h600d) $fatal(1,"guest failed id=%h",mem['hf100>>1]);
     if(mem['hc000>>1]!==16'ha55a || mem['hc3ea>>1]!==16'h5aa5) $fatal(1,"quick guards changed");
     for(i=0;i<500;i=i+1) if($signed(mem[('hc002+2*i)>>1]) != i-250) $fatal(1,"quick result mismatch index=%0d value=%h",i,mem[('hc002+2*i)>>1]);
     $display("BUFFER_UPPER_BOUND hits=%0d saved_cycles=%0d",buffer_hits,buffer_saving);
     $display("QUICK500 PASS cycles=%0d latency=%0d sorted_permutation=PASS guards=PASS",cycles,latency);
     for(j=0;j<256;j=j+1) if(states[j]) $display("STATE %0d cycles=%0d",j,states[j]);
     for(j=0;j<3;j=j+1) $display("LATENCY class=%0d count=%0d total=%0d",j,lat_count[j],lat_total[j]);
     $finish;
    end
   end
  end else if(req && !ack) begin
   saved_addr<=addr;saved_data<=wdata;saved_wr<=wr;saved_size<=size;
   pending<=1;waitleft<=latency;
  end
 end
endmodule
'''
if args.kernel=='sieve':
 s=s.replace('reg [15:0] mem[0:32767];','reg [15:0] mem[0:32767]; reg [7:0] expected[0:8190];')
 s=s.replace('  $readmemh(path,mem);', '  $readmemh(path,mem);\n  $readmemh("'+str(d/'expected.hex')+'",expected);')
 begin=s.index('     if(mem[\'hc000>>1]')
 finish=s.index('     for(j=0;j<256;',begin)
 s=s[:begin]+'''     if(readbyte('h8ffe)!==8'ha5 || readbyte('h8fff)!==8'h5a || readbyte('hafff)!==8'h5a || readbyte('hb000)!==8'ha5) $fatal(1,"sieve guards changed");
     if(mem['hf100>>1]!==16'd'''+str(sum(expected))+''') $fatal(1,"sieve count mismatch %0d",mem['hf100>>1]);
     for(i=0;i<8191;i=i+1) if(readbyte('h9000+i)!==expected[i]) $fatal(1,"sieve flag mismatch index=%0d",i);
     $display("BUFFER_UPPER_BOUND hits=%0d saved_cycles=%0d",buffer_hits,buffer_saving);
     $display("SIEVE8191 PASS cycles=%0d latency=%0d prime_flags=PASS guards=PASS",cycles,latency);
'''+s[finish:]
if args.profile:
 s=s.replace('integer states[0:255];', 'integer states[0:255]; integer opcycles[0:65535]; integer exits[0:65535]; integer regs_cycles[0:65535]; integer admission_denied[0:65535]; integer pipe_cycles=0,pipe_issues=0; integer fetch_empty=0,decode_ext_wait=0,pipe_ready_empty=0,data_prefetch_wait=0,data_setup=0,data_ack_wait=0,regs_queue_ready=0,regs_queue_empty=0;')
 s=s.replace('for(i=0;i<256;i=i+1) states[i]=0;', 'for(i=0;i<256;i=i+1) states[i]=0; for(i=0;i<65536;i=i+1) begin opcycles[i]=0;exits[i]=0;regs_cycles[i]=0;admission_denied[i]=0;end')
 s=s.replace('cycles=cycles+1; states[dut.core.state]', """if(dut.core.state==dut.core.S_FETCH && !dut.core.epf_ready_pc) fetch_empty++;
  if(dut.core.pipe_pea_wait) decode_ext_wait++;
  if(dut.core.pipe_rf_owner && dut.core.pipe_ready && !dut.core.epf_ready_pc) pipe_ready_empty++;
  if(dut.core.state==dut.core.S_MRD || dut.core.state==dut.core.S_MWR) begin
   if(!dut.core.m_issued && dut.core.epf_pend) data_prefetch_wait++;
   else if(!dut.core.m_issued) data_setup++;
   else if(!dut.core.d_ack) data_ack_wait++;
  end
  if(dut.core.state==dut.core.S_DECODE && dut.core.pipe_supported && !dut.core.pipe_entry_ok) admission_denied[dut.core.ir]++;
  if(dut.core.state==dut.core.S_PIPE_REGS) begin
   regs_cycles[dut.core.ir]++;
   if(dut.core.epf_ready_pc) regs_queue_ready++;else regs_queue_empty++;
  end
  if(dut.core.pipe_rf_owner) pipe_cycles++; else opcycles[dut.core.ir]++;
  if(dut.core.pipe_input && dut.core.pipe_ready) pipe_issues++;
  if(dut.core.pipe_owner && dut.core.pipe_exit_ready && !dut.core.pipe_input && dut.core.epf_ready_pc) exits[dut.core.epf_data[dut.core.epf_head]]++;
  cycles=cycles+1; states[dut.core.state]""")
 s=s.replace('$display("BUFFER_UPPER_BOUND', 'for(j=0;j<65536;j=j+1) begin if(regs_cycles[j]) $display("REGS_IR opcode=%04h cycles=%0d",j[15:0],regs_cycles[j]); if(admission_denied[j]) $display("ENTRY_DENIED opcode=%04h cycles=%0d",j[15:0],admission_denied[j]); if(opcycles[j]) $display("ACTIVE_IR opcode=%04h cycles=%0d",j[15:0],opcycles[j]); if(exits[j]) $display("PIPE_EXIT opcode=%04h count=%0d",j[15:0],exits[j]); end $display("PIPELINE cycles=%0d issues=%0d",pipe_cycles,pipe_issues); $display("FETCH_PROFILE empty=%0d decode_extension_wait=%0d pipe_ready_empty=%0d data_prefetch_wait=%0d data_setup=%0d data_ack_wait=%0d regs_queue_ready=%0d regs_queue_empty=%0d",fetch_empty,decode_ext_wait,pipe_ready_empty,data_prefetch_wait,data_setup,data_ack_wait,regs_queue_ready,regs_queue_empty); $display("BUFFER_UPPER_BOUND')
(d/'tb.sv').write_text(s)
units=('ap040_core','ap040_bus_timeout','ap040_regfile','ap040_alu','ap040_muldiv','ap040_mmu','ap040_cache','ap040_fpu','primitives/dpram')
flags=['-DAP040_EXPERIMENTAL_'+x for x in ('XSTORE','LEA','PIPELINE','PIPELINE_LOADS','PIPELINE_STORES','PIPELINE_PEA','PIPELINE_P6')]+['-DAP040_PIPELINE_MEMORY_ENTRY']
if args.compare: flags.append('-DAP040_PIPELINE_COMPARE')
if args.early_drain: flags.append('-DAP040_PIPELINE_EARLY_DRAIN')
for variant in (('current','compare') if args.compare_module else ('current',)):
 out=d/variant;out.mkdir(exist_ok=True)
 module=r/'rtl/ap68040/experimental/ap040_pipeline_integer.sv' if variant=='current' else args.compare_module.resolve()
 sources=[d/'tb.sv',r/'rtl/wombat_cpu.sv',r/'rtl/wombat_store_buffer.sv',*[rtl/(u+'.v') for u in units],module]
 sources=[args.core.resolve() if args.core and p==rtl/'ap040_core.v' else p for p in sources]
 sources=[args.alu.resolve() if args.alu and p==rtl/'ap040_alu.v' else p for p in sources]
 sources=[args.muldiv.resolve() if args.muldiv and p==rtl/'ap040_muldiv.v' else p for p in sources]
 (out/'identity.json').write_text(json.dumps({'sources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'kernel_sha256':hashlib.sha256(kernel).hexdigest(),'resource_sha256':hashlib.sha256(resource).hexdigest(),'input':values,'latencies':args.latencies,'early_drain':args.early_drain,'compare':args.compare,'scope':('unchanged 0x93ce..0x946d recursive sort; fixed shuffled input; excludes initializer, allocation and original wrapper' if args.kernel=='quick' else 'unchanged 0xb6a..0xbad Sieve inner pass including initialization; original addresses; excludes allocation, disposal, outer 100-pass repetition and timing/UI'), 'kernel':args.kernel, 'program_sha256':hashlib.sha256((d/'program.bin').read_bytes()).hexdigest(), 'oracle_sha256':hashlib.sha256((d/'expected.hex').read_bytes()).hexdigest() if args.kernel=='sieve' else None},indent=2))
 run(['/home/alans/verilator5/bin/verilator','--binary','--timing','-Wno-fatal','-Wno-BLKLOOPINIT','-j','8','--top-module','tb_cpu_quick','--Mdir',out/'obj','-I'+str(rtl),*flags,*sources],out/'compile.log')
 for latency in args.latencies:
  logfile=out/f'run_latency{latency}.log'
  run([out/'obj/Vtb_cpu_quick','+prog='+str(d/'program.hex'),f'+latency={latency}'],logfile)
  log=logfile.read_text();assert ('QUICK500 PASS' if args.kernel=='quick' else 'SIEVE8191 PASS') in log,log[-2000:]
  print(variant,'\n'.join(l for l in log.splitlines() if l.startswith(('QUICK500','SIEVE8191','LATENCY','PIPELINE','PIPE_EXIT','FETCH_PROFILE'))),flush=True)
