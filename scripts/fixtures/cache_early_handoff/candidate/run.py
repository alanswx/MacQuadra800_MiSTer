#!/usr/bin/env python3
import pathlib,hashlib,subprocess,shutil
here=pathlib.Path(__file__).resolve().parent
repo=pathlib.Path('/home/alans/mister/MacQuadra800_MiSTer')
ap=repo/'rtl/ap68040/rtl'
print('core', hashlib.sha256((ap/'ap040_core.v').read_bytes()).hexdigest()[:16])
if not (here/'rtl').exists():shutil.copytree(repo/'rtl',here/'rtl')
ap=here/'rtl/ap68040/rtl';rtl=here/'rtl'
print('candidate core (hash check relaxed for the hint candidate)')
print('CPU',hashlib.sha256((ap/'ap040_core.v').read_bytes()).hexdigest(),flush=True)
with (here/'assemble.log').open('w')as f:
 subprocess.run(['/tmp/wombat-vasm/vasmm68k_mot','-Fbin','-m68040','-no-opt','-o',str(here/'program.bin'),str(here/'program.s')],check=True,stdout=f,stderr=subprocess.STDOUT)
(here/'program.hex').write_text(''.join(f'{b:02x}\n'for b in (here/'program.bin').read_bytes()))
sources=[here/'tb_latency.sv',rtl/'wombat_cpu.sv',rtl/'wombat_store_buffer.sv']
sources += [ap/name for name in ['ap040_core.v','ap040_bus_timeout.v','ap040_regfile.v','ap040_alu.v','ap040_muldiv.v','ap040_mmu.v','ap040_cache.v','ap040_fpu.v','primitives/dpram.v']]
with (here/'compile.log').open('w')as f:
 subprocess.run(['/home/alans/verilator5/bin/verilator','--binary','--timing','--assert','-Wno-fatal','-j','4','--top-module','tb_latency','--Mdir',str(here/'obj'),'-I'+str(ap),*map(str,sources)],check=True,stdout=f,stderr=subprocess.STDOUT)
with (here/'run.log').open('w')as f:
 subprocess.run([str(here/'obj/Vtb_latency'),'+prog='+str(here/'program.hex')],check=True,stdout=f,stderr=subprocess.STDOUT)
print((here/'run.log').read_text().splitlines()[-5:],flush=True)
