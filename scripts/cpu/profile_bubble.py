#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,random,subprocess
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description="Profile original Speedometer Bubble sorting loop on a fixed shuffled input; not a hardware score.")
parser.add_argument('resource',type=Path)
parser.add_argument('--out',type=Path,required=True)
parser.add_argument('--compare-module',type=Path,help='optional alternative pipeline module; core and entry policy remain identical')
parser.add_argument('--early-drain',action='store_true',help='enable final-WB pipeline handoff')
parser.add_argument('--compare',action='store_true',help='enable indexed CMP/TST and register TST')
args=parser.parse_args()
d=args.out.resolve();d.mkdir(parents=True,exist_ok=True);rtl=r/'rtl/ap68040/rtl' 
resource=args.resource.read_bytes()
assert hashlib.sha256(resource).hexdigest()=='af67113bceb4eb906e973a9b747a0b1925b9d64c62f0f9a84bc6f0578839ca80'
kernel=resource[82+0x6250f+0x9586:82+0x6250f+0x95d2];(d/'bubble.bin').write_bytes(kernel)
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
 move.w #500,($5fb0).l
 jsr ($9586).l
 move.w #$600d,($f102).l
 stop #$2700
unexpected:
 move.w #$bad0,($f102).l
 stop #$2700
 org $9586
 incbin "'''+str(d/'bubble.bin')+'''"
 rts
 org $c000
 dc.w $a55a
'''+''.join(' dc.w '+','.join('$%04x'%(x&65535) for x in values[i:i+20])+'\n' for i in range(0,500,20))+' dc.w $5aa5\n'
(d/'bubble.s').write_text(asm)
def run(cmd,path):
 with path.open('w') as f:subprocess.run(list(map(str,cmd)),stdout=f,stderr=subprocess.STDOUT,check=True)
run(['/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot','-Fbin','-m68040','-no-opt','-o',d/'program.bin',d/'bubble.s'],d/'asm.log')
assert (d/'program.bin').read_bytes()[0x9586:0x95d2]==kernel
run(['python3',r/'rtl/ap68040/tb/bin2hex.py',d/'program.bin',d/'program.hex'],d/'hex.log')
s=(r/'scratch/towers_probe_20260919/tb_cpu_towers.sv').read_text().replace('tb_cpu_towers','tb_cpu_bubble')
a=s.index("     if(mem['h5fb6");b=s.index('     $display("BUFFER_UPPER_BOUND',a)
s=s[:a]+'''     if(mem['hc000>>1]!==16'ha55a || mem['hc3ea>>1]!==16'h5aa5) $fatal(1,"bubble guards changed");
     for(i=0;i<500;i=i+1) if($signed(mem[('hc002+2*i)>>1]) != i-250) $fatal(1,"bubble result mismatch index=%0d value=%h",i,mem[('hc002+2*i)>>1]);
'''+s[b:]
s=s.replace('TOWERS32 PASS cycles=%0d latency=%0d moves=16383 nodes=18 lists=PASS guards=PASS','BUBBLE500 PASS cycles=%0d latency=%0d sorted_permutation=PASS guards=PASS')
(d/'tb.sv').write_text(s)
units=('ap040_core','ap040_bus_timeout','ap040_regfile','ap040_alu','ap040_muldiv','ap040_mmu','ap040_cache','ap040_fpu','primitives/dpram')
flags=['-DAP040_EXPERIMENTAL_'+x for x in ('XSTORE','LEA','PIPELINE','PIPELINE_LOADS','PIPELINE_STORES','PIPELINE_PEA','PIPELINE_P6')]+['-DAP040_PIPELINE_MEMORY_ENTRY']
if args.compare: flags.append('-DAP040_PIPELINE_COMPARE')
if args.early_drain: flags.append('-DAP040_PIPELINE_EARLY_DRAIN')
for variant in (('current','compare') if args.compare_module else ('current',)):
 out=d/variant;out.mkdir(exist_ok=True)
 module=r/'rtl/ap68040/experimental/ap040_pipeline_integer.sv' if variant=='current' else args.compare_module.resolve()
 sources=[d/'tb.sv',r/'rtl/wombat_cpu.sv',r/'rtl/wombat_store_buffer.sv',*[rtl/(u+'.v') for u in units],module]
 (out/'identity.json').write_text(json.dumps({'sources':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'kernel_sha256':hashlib.sha256(kernel).hexdigest(),'resource_sha256':hashlib.sha256(resource).hexdigest(),'input':values,'early_drain':args.early_drain,'compare':args.compare,'scope':'unchanged 0x9586..0x95d1 sorting loop only; fixed shuffled input; excludes initializer, allocation and five-iteration wrapper'},indent=2))
 run(['/home/alans/verilator5/bin/verilator','--binary','--timing','-Wno-fatal','-Wno-BLKLOOPINIT','-j','8','--top-module','tb_cpu_bubble','--Mdir',out/'obj','-I'+str(rtl),*flags,*sources],out/'compile.log')
 run([out/'obj/Vtb_cpu_bubble','+prog='+str(d/'program.hex'),'+latency=3'],out/'run.log')
 log=(out/'run.log').read_text();assert 'BUBBLE500 PASS' in log,log[-2000:]
 print(variant,'\n'.join(l for l in log.splitlines() if l.startswith(('BUBBLE500','LATENCY'))),flush=True)
