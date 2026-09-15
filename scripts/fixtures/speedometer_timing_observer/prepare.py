#!/usr/bin/env python3
"""Prepare a NEW simulator-only tree; never edits the supplied source tree."""
import argparse, hashlib, pathlib, shutil, subprocess, difflib
p=argparse.ArgumentParser()
p.add_argument('--source',type=pathlib.Path,required=True)
p.add_argument('--dest',type=pathlib.Path,required=True)
a=p.parse_args(); here=pathlib.Path(__file__).resolve().parent
source=a.source.resolve();dest=a.dest.resolve()
assert not dest.exists(), 'destination must be new'
core=source/'rtl/ap68040/rtl/ap040_core.v'
assert hashlib.sha256(core.read_bytes()).hexdigest()=='0c3a81bd0fb46958e73138b580abfa994638756f79df71716683a1c1772c2614'
original=(source/'verilator/sim_main.cpp').read_text()
assert hashlib.sha256(original.encode()).hexdigest()=='ec6f463202781fd6a62a5ae0184575ff9ff734e47781894e06121f17162651be'
assert ".ce(1'b1)" in (source/'verilator/sim.v').read_text()
dest.mkdir()
shutil.copytree(source/'rtl',dest/'rtl')
shutil.copytree(source/'verilator',dest/'verilator')
(dest/'releases').mkdir()
shutil.copy2(source/'releases/quadra800.rom',dest/'releases/quadra800.rom')
def replace_once(s,old,new):
    assert s.count(old)==1, ('adapter anchor mismatch',old)
    return s.replace(old,new)
s=replace_once(original,'static void prof_start_signal(int)',
    '#include "speedometer_adapter.inc"\n\nstatic void prof_start_signal(int)')
s=replace_once(s,'\t\t\ttop->eval();',
    '\t\t\tif (clk_sys.clk) speedometer_before_eval();\n\t\t\ttop->eval();')
s=replace_once(s,'\t\t\t\tprof_step(cpu_dispatch);',
    '\t\t\t\tspeedometer_after_eval(cpu_dispatch);\n\t\t\t\tprof_step(cpu_dispatch);')
s=replace_once(s,'} else if (!strcmp(argv[i], "--control")) {',
''' } else if (!strcmp(argv[i], "--speedometer-observe")) {
            if(i+1>=argc) { fprintf(stderr,"--speedometer-observe requires FILE\\n");return 1; }
            speedometer_path=argv[++i];
        } else if (!strcmp(argv[i], "--speedometer-limit")) {
            if(i+1>=argc) return 1;
            speedometer_limit=strtoull(argv[++i],nullptr,0);
            if(!speedometer_limit || speedometer_limit>4096) return 1;
        } else if (!strcmp(argv[i], "--control")) {''')
s=replace_once(s,'\n#ifndef _WIN32\n', '''
    if(!speedometer_path.empty()) {
        speedometer_file.open(speedometer_path);
        if(!speedometer_file) { fprintf(stderr,"cannot open observer output\\n");return 1; }
        speedometer_observer.reset(new speedometer::Observer(speedometer_file,speedometer_limit));
    }
#ifndef _WIN32
''')
s=replace_once(s,'\tif (prof_gate.active()) { prof_dump(); prof_gate.stop(); }',
    '\tif (speedometer_observer) speedometer_observer->summary();\n\tif (prof_gate.active()) { prof_dump(); prof_gate.stop(); }')
(dest/'verilator/sim_main.cpp').write_text(s)
shutil.copy2(here/'speedometer_observer.h',dest/'verilator/speedometer_observer.h')
shutil.copy2(here/'adapter.inc',dest/'verilator/speedometer_adapter.inc')
(dest/'simulator-observer.patch').write_text(''.join(difflib.unified_diff(
    original.splitlines(True),s.splitlines(True),fromfile='a/verilator/sim_main.cpp',tofile='b/verilator/sim_main.cpp')))
print('PREPARED',dest)
print('CPU',hashlib.sha256(core.read_bytes()).hexdigest())
print('sim_main.cpp',hashlib.sha256(s.encode()).hexdigest())
