#!/usr/bin/env python3
"""Focused compile-toggle checks; builds only small Verilator simulations."""
import argparse
import hashlib
import itertools
from pathlib import Path
import re
import subprocess
import tempfile

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--verilator', default='/home/alans/verilator5/bin/verilator')
p.add_argument('--baseline', default='50ca69b4bbcc7f1ae4a407f6607ecc9e20d0ebbf',
               help='immutable revision before the toggle edits')
a = p.parse_args()
repo = a.repo.resolve()
fixture = Path(__file__).resolve().parent
out = Path(tempfile.mkdtemp(prefix='peripheral-toggles.'))
print(f'REPO={repo}\nOUT={out}', flush=True)

def run(cmd, **kw):
    return subprocess.run([str(x) for x in cmd], check=True, **kw)

def preprocess(path, macros=()):
    return run([a.verilator, '-E', '-P', '-I'+str(repo), '-I'+str(repo/'sys'),
                *['+define+'+x for x in macros], path], capture_output=True, text=True).stdout

def tokens(s):
    # Preserve quoted strings (including whitespace), ignore only comments
    # and token-separating whitespace outside strings.
    pat = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/|\s+|[A-Za-z_$][\w$]*|\d+|[^\s]'
    return [x for x in re.findall(pat, s) if not x.isspace() and not x.startswith(('//', '/*'))]

for name in ('MacQuadra800.sv', 'sys/sys_top.v', 'sys/audio_out.sv'):
    current = repo/name
    old = out/('old_'+current.name)
    old.write_bytes(run(['git', '-C', repo, 'show', a.baseline+':'+name], capture_output=True).stdout)
    assert tokens(preprocess(old)) == tokens(preprocess(current)), 'default tokens changed: '+name
    print('DEFAULT TOKENS IDENTICAL', name, hashlib.sha256(current.read_bytes()).hexdigest(), flush=True)

# Every macro combination is preprocessed, including HDMI-off and framebuffer.
names = ('MISTER_DISABLE_MT32PI', 'MISTER_DISABLE_SHADOWMASK', 'MISTER_BYPASS_AUDIO_FILTER',
         'MISTER_DEBUG_NOHDMI', 'MISTER_FB')
for bits in itertools.product((False, True), repeat=len(names)):
    macros = tuple(n for n, b in zip(names, bits) if b)
    core = preprocess(repo/'MacQuadra800.sv', macros)
    top = preprocess(repo/'sys/sys_top.v', macros)
    audio = preprocess(repo/'sys/audio_out.sv', macros)
    assert ('mt32pi mt32pi' in core) == (not bits[0])
    assert ('P1,MT32-pi;' in core) == (not bits[0])
    assert ('shadowmask HDMI_shadowmask' in top) == (not bits[1] and not bits[3])
    assert ('mask_bypass[0:4]' in top) == (bits[1] and not bits[3])
    assert ('IIR_filter #(' in audio) == (not bits[2])
    if bits[1]:
        assert not re.search(r'\bshadowmask_(wr|data)\b', top)
print('PASS 32 preprocessor configurations', flush=True)

# Compile exact extracted integration blocks, not handwritten bypass models.
core = preprocess(repo/'MacQuadra800.sv', ('MISTER_DISABLE_MT32PI',))
serial = core[core.index('wire serialOut, serialRTS;'):core.index('assign LED_USER =')]
top = preprocess(repo/'sys/sys_top.v', ('MISTER_DISABLE_SHADOWMASK',))
shadow = top[top.index('wire [23:0] hdmi_data_mask;'):top.index('wire [23:0] hdmi_data_osd;')]
wrapper = '''module trim_ports(
input UART_RXD, UART_DSR, tx, rts, input [7:0] mode,
input [7:0] r,g,b, input signed [15:0] ml,mr,cl,cr,
output UART_TXD,UART_RTS,UART_DTR, output [6:0] USER_OUT,
output [7:0] VGA_R,VGA_G,VGA_B, output [15:0] AUDIO_L,AUDIO_R,
output rx, info_req, output [3:0] info_disp);
'''+serial+'''
assign serialOut=tx; assign serialRTS=rts; assign uart_mode=mode;
assign mac_vga_r=r; assign mac_vga_g=g; assign mac_vga_b=b;
assign mac_audio_l=ml; assign mac_audio_r=mr; assign cd_snd_l=cl; assign cd_snd_r=cr;
assign rx=serialIn; assign info_req=mt32_info_req; assign info_disp=mt32_info_disp;
endmodule
module trim_shadow(input clk_hdmi, dis_output, input [23:0] hdmi_data,
input hdmi_vs,hdmi_hs,hdmi_de,output [26:0] result);
'''+shadow+'''
assign result={hdmi_data_mask,hdmi_vs_mask,hdmi_hs_mask,hdmi_de_mask};
endmodule
'''
(out/'integration.sv').write_text(wrapper)

# sys_top.v is compiled as Verilog by Quartus. Explicitly check the actual
# extracted bypass in Verilog-2001 mode, independently of the SV testbench.
shadow_v = out/'shadow_verilog2001.v'
shadow_v.write_text(wrapper[wrapper.index('module trim_shadow'):])
with (out/'shadow_verilog2001.lint.log').open('w') as log:
    run([a.verilator, '--lint-only', '--language', '1364-2001', '-Wno-fatal',
         '--top-module', 'trim_shadow', shadow_v], stdout=log, stderr=subprocess.STDOUT)
print('PASS extracted shadowmask bypass Verilog-2001 lint', flush=True)
negative_v = out/'shadow_verilog2001_negative.v'
negative_v.write_text(shadow_v.read_text().replace(
    'for (mask_bypass_idx = 1;', 'for (integer mask_bypass_idx = 1;'))
negative = subprocess.run([a.verilator, '--lint-only', '--language', '1364-2001',
    '-Wno-fatal', '--top-module', 'trim_shadow', str(negative_v)], capture_output=True, text=True)
(out/'shadow_verilog2001.negative.log').write_text(negative.stdout+negative.stderr)
# Verilator 5.050 and Icarus accept this extension even in 1364-2001 mode;
# Quartus correctly rejects it for sys_top.v. Enforce the specific portable
# syntax rule explicitly and prove the rule rejects the original regression.
def portable_loop_declarations(source):
    assert not re.search(r'\bfor\s*\(\s*(integer|int|reg|logic)\b', source), \
        'loop-local declaration requires SystemVerilog; declare the index outside for'
portable_loop_declarations(shadow_v.read_text())
try:
    portable_loop_declarations(negative_v.read_text())
except AssertionError:
    pass
else:
    raise AssertionError('portable loop check failed its negative control')
print('PASS strict loop-declaration rule and negative control '
      f'(simulator negative-control exit {negative.returncode}; permissive extensions are not trusted)', flush=True)

def build_test(name, sources, flags=()):
    obj = out/('obj_'+name)
    cmd = [a.verilator, '--binary', '--timing', '--assert', '-j', '4', '-Wno-fatal',
           '--top-module', name, '--Mdir', obj, '-o', 'test', *flags, *sources]
    with (out/(name+'.build.log')).open('w') as log:
        run(cmd, stdout=log, stderr=subprocess.STDOUT)
    with (out/(name+'.run.log')).open('w') as log:
        run([obj/'test'], stdout=log, stderr=subprocess.STDOUT)
    print((out/(name+'.run.log')).read_text(), flush=True)

build_test('tb_peripheral_ports', [out/'integration.sv', repo/'sys/shadowmask.sv', fixture/'tb_peripheral_ports.sv'])
build_test('tb_audio_bypass', [repo/'sys/audio_out.sv', repo/'sys/iir_filter.v',
           repo/'sys/i2s.v', repo/'sys/spdif.v', repo/'sys/sigma_delta_dac.v', fixture/'tb_audio_bypass.sv'],
           ['+define+MISTER_BYPASS_AUDIO_FILTER'])
print('PASS peripheral toggles; evidence '+str(out), flush=True)
