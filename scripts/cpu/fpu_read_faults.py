#!/usr/bin/env python3
"""Check precise bus faults during FPU extended operand and FMOVEM reads.

Uses the existing CPU testbench's one-shot F140 bus fault in all bus phases.
This is a fault-ordering gate, not a platform memory-performance benchmark.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

R = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--core', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args(); d = a.out.resolve(); d.mkdir(parents=True, exist_ok=True)
rtl = R/'rtl/ap68040/rtl'
units = ['ap040_tg68k_compat', 'ap040_bus16_adapter', 'ap040_bus_timeout',
         'ap040_regfile', 'ap040_alu', 'ap040_muldiv', 'ap040_mmu',
         'ap040_cache', 'ap040_fpu', 'ap040_walker_cdc', 'primitives/dpram']
sources = [R/'rtl/ap68040/tb/tb_ap040_program.v', a.core.resolve(),
           R/'rtl/ap68040/experimental/ap040_pipeline_integer.sv',
           *(rtl/(u+'.v') for u in units)]
flags = ['-DAP040_EXPERIMENTAL_'+x for x in ('XSTORE','LEA','PIPELINE','PIPELINE_LOADS','PIPELINE_STORES','PIPELINE_PEA','PIPELINE_P6')]
flags += ['-DAP040_PIPELINE_COMPARE','-DAP040_PIPELINE_MEMORY_ENTRY','-DAP040_PIPELINE_EARLY_DRAIN']
(d/'identity.json').write_text(json.dumps({'scope': __doc__, 'flags': flags,
    'sources': {str(x): hashlib.sha256(x.read_bytes()).hexdigest() for x in sources}}, indent=2)+'\n')

def run(cmd, log):
    with (d/log).open('w') as f:
        proc = subprocess.run(list(map(str, cmd)), stdout=f, stderr=subprocess.STDOUT)
    content = (d/log).read_text()
    if proc.returncode: raise RuntimeError(content[-3000:])
    return content

run(['iverilog','-g2012','-I',rtl,'-s','tb_ap040_program',*flags,'-o',d/'bench.vvp',*sources], 'compile.log')
for mode in ('postinc', 'predec', 'movem'):
    for word in range(3):
        base = 0xf140-4*word
        initial = base+12 if mode=='predec' else base
        op = 'fmovem.x (a0)+,fp0' if mode=='movem' else 'fmove.x '+('-(a0)' if mode=='predec' else '(a0)+')+',fp0'
        name = f'{mode}_word{word}'
        asm = f''' org 0
 dc.l $7000,start,handler
 rept 253
 dc.l fail
 endr
 org $400
start:
 move.w #$2700,sr
 moveq #0,d0
 movec d0,cacr
 fmove.l #99,fp0
 movea.l #${initial:x},a0
 moveq #$55,d2
faulting:
 {op}
 moveq #7,d2
 bra fail
handler:
 cmp.w #$2700,(sp)
 bne fail
 cmp.l #faulting,2(sp)
 bne fail
 cmp.l #$f140,20(sp)
 bne fail
 cmpa.l #${initial:x},a0
 bne fail
 cmp.l #$55,d2
 bne fail
 move.w 6(sp),d0
 and.w #$f000,d0
 cmp.w #$7000,d0
 bne fail
 fmove.l fp0,d1
 cmp.l #99,d1
 bne fail
 move.w #$600d,($f102).l
 stop #$2700
fail:
 move.w #$bad0,($f102).l
 stop #$2700
'''
        (d/(name+'.s')).write_text(asm)
        run(['/home/alans/mister/MacQuadra800_fixtures/wombat-vasm/vasmm68k_mot','-Fbin','-m68040','-no-opt','-o',d/(name+'.bin'),d/(name+'.s')],name+'_asm.log')
        run(['python3',R/'rtl/ap68040/tb/bin2hex.py',d/(name+'.bin'),d/(name+'.hex')],name+'_hex.log')
        result = run(['vvp',d/'bench.vvp','+prog='+str(d/(name+'.hex'))],name+'.log')
        if 'ALL TESTS PASSED' not in result: raise RuntimeError(name+': '+result[-3000:])
        print(name, 'PASS (all bus phases)', flush=True)
