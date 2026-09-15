#!/usr/bin/env python3
"""Generate a combinational decode record (n_*) from the S_DECODE body of ap040_core.v.

Usage: gen_decoder.py CORE.v  -> writes the modified core in place (adds the
decoder block and, under `ifdef DECODE_CHECK, an equivalence check against
the registered results of S_DECODE).
"""
import re, sys

RECORD = {  # field: (width, default at decode entry or None for "unchanged")
    'p_src': (None, 'SK_NONE'), 'p_dst': (None, 'DK_NONE'),
    'p_rmw': (1, "1'b0"), 'p_wbsup': (1, "1'b0"), 'p_flags': (1, "1'b1"),
    'p_sextw': (1, "1'b0"), 'p_dst_mem_bit': (1, "1'b0"), 'exec_kind': (None, 'EK_ALU'),
    'op_size': (None, None), 'alu_op': (None, None), 'p_dreg': (None, None),
    'p_dsize': (None, None), 'p_ssize': (None, None), 'p_sreg': (None, None),
    'dst_rn_r': (None, None), 'dst_mode_r': (None, None), 'src_rn_r': (None, None),
    'src_mode_r': (None, None), 'rr_a': (None, None), 'rr_b': (None, None),
    'src_val': (None, None), 'sh_rox': (1, None), 'md_isdiv': (1, None),
    'md_sign': (1, None), 'lk_cyc': (1, None),
}
REBIND = {
    'ir_hi': 'rd_ir_hi', 'd_reg9': 'rdd_reg9', 'd_op8_6': 'rdd_op8_6', 'd_mode': 'rdd_mode',
    'd_rn': 'rdd_rn', 'move_size': 'rdd_move_size', 'std_size': 'rdd_std_size',
    'ea_is_imm': 'rdd_ea_is_imm', 'dst_not_alt': 'rdd_dst_not_alt', 'src_not_data': 'rdd_src_not_data',
}
INPLACE_CALLS = ['ea_start(', 'exc(', 'go_illegal', 'go_priv', 'mrd(', 'mwr(', 'go_pc(', 'finish_bcc(',
                 'fetch_next', 'aerr_start', 'decode_dbcc_brf(', 'dispatch_reg_decode', 'epf_flush']

src_path = sys.argv[1]
core = open(src_path).read()

# widths from declarations
def width_of(name):
    m = re.search(r'^reg\s+(\[[0-9:]+\]\s+)?[^;\n]*\b' + re.escape(name) + r'\b', core, re.M)
    if not m: sys.exit(f'no declaration for {name}')
    return (m.group(1) or '').strip()

# 1. cut the S_DECODE body
m = re.search(r'\n\t\t\tS_DECODE: begin\n', core)
start = m.start() + 1
m2 = re.search(r'\n\t\t\tS_[A-Z0-9_]+: begin\n', core[m.end():])
end = m.end() + m2.start() + 1
body = core[start:end]
# strip the outer "S_DECODE: begin" ... "end"
lines = body.split('\n')
assert lines[0].strip() == 'S_DECODE: begin'
# find the matching final 'end' (last non-empty line at 3 tabs)
j = len(lines) - 1
while lines[j].strip() == '' or lines[j].strip().startswith('//'): j -= 1
assert lines[j] == '\t\t\tend', repr(lines[j])
inner = '\n'.join(lines[1:j])

# 2. rebind opcode wires and ir
inner = re.sub(r'\bir\[', 'rd_ir[', inner)
for a, b in REBIND.items():
    inner = re.sub(r'\b' + a + r'\b', b, inner)

# 3. statements
def repl_assign(mo):
    name, sel, expr = mo.group(1), mo.group(2) or '', mo.group(3)
    if name in RECORD:
        if sel: sys.exit(f'bit-select assignment to record field {name}')
        # a value taken from the condition codes or the status register is
        # stale at a producer's retire (its flag write lands on that edge):
        # such instructions decode in place
        if re.search(r'\bsr\b', expr) or re.search(r'\bsr\[', expr):
            return 'n_inplace = 1;'
        return f'begin n_{name} = {expr}; n_{name}_v = 1; end'
    return 'n_inplace = 1;'
INPLACE_REGS = ['sr', 'md_isdiv', 'md_sign', 'mm_size', 'mm_predec', 'mm_postinc', 'mm_dir', 'm16_form',
                'br_base', 'br_long', 'br_tgt', 'srop_sr', 'srop_kind', 'rst_cnt', 'pf_mode', 'mvc_dir',
                'mp_dir', 'mp_cnt', 'in_exc', 'cinv_req', 'cinv_ic', 'cinv_dc', 'ret_kind', 'state']
ASSIGN_NAMES = '|'.join(sorted(list(RECORD) + INPLACE_REGS, key=len, reverse=True))
inner = re.sub(r'\b(' + ASSIGN_NAMES + r')(\[[^\]]*\])?\s*<=\s*([^;]+);', repl_assign, inner)
leftover_cmp = re.findall(r'\b([a-z_0-9]+)\s*<=', inner)
print('remaining "<=" uses (comparisons):', sorted(set(leftover_cmp)))

ARG = r"((?:\{[^}]*\}|\([^()]*\)|[^,(){}])+)"
inner = re.sub(r'\bpipe_go_regpair\(' + ARG + r',\s*' + ARG + r'\);', r'begin n_rr_a = \1; n_rr_a_v = 1; n_rr_b = \2; n_rr_b_v = 1; n_next = NX_PREGS; end', inner)
inner = re.sub(r'\bpipe_go_regdst\(' + ARG + r'\);', r'begin n_rr_b = \1; n_rr_b_v = 1; n_next = NX_PREGS; end', inner)
inner = re.sub(r'\bpipe_go;', 'n_next = NX_PSTART;', inner)
inner = re.sub(r"\bimmf\(" + ARG + r",\s*S_PIPE_START\);", r'begin n_immn = \1; n_next = NX_IMMF_PSTART; end', inner)
inner = re.sub(r"\bimmf\([^;]*\);", 'n_inplace = 1;', inner)
inner = re.sub(r"\bimmf_reg\(" + ARG + r",\s*" + ARG + r"\);", r'begin n_immn = \1; n_rr_b = \2; n_rr_b_v = 1; n_next = NX_IMMREG; end', inner)
# every task of the core except the ones rewritten above marks the record in-place
TASKS = set(re.findall(r'^task\s+([a-z_0-9]+)\s*;', core, re.M)) - {'pipe_go', 'pipe_go_regdst', 'pipe_go_regpair', 'immf', 'immf_reg'}
for c in sorted(TASKS, key=len, reverse=True):
    inner = re.sub(r'\b' + re.escape(c) + r'\b(\([^;]*\))?\s*;', 'n_inplace = 1;', inner)
for c in INPLACE_CALLS:
    inner = re.sub(re.escape(c) + r'[^;]*;', 'n_inplace = 1;', inner)
calls_left = sorted(set(re.findall(r'\b([a-z_0-9]+)\(', inner)) - {'sxw', 'sxb', 't0_special', 'cond_true', 'cond_true_fl', 'an_adj', 'merge_sz', 'brf_refill_hit'})
print('remaining calls in the record block:', calls_left)
# reads of registers the body also writes: use the record's value
for name in ('p_src', 'exec_kind', 'dst_mode_r', 'p_dst'):
    inner = re.sub(r'\b' + name + r'\b(?!_v)(?!\s*=)', 'n_' + name, inner)
# the rebinding above turned "n_p_src" assignments into "n_n_p_src": undo
inner = inner.replace('n_n_', 'n_')
leftover = [w for w in re.findall(r'\b([a-z_0-9]+)\s*<=', inner) if w in RECORD or w in INPLACE_REGS]
if leftover: sys.exit(f'unhandled nonblocking assignments: {set(leftover)}')

# 4. declarations, defaults, block
decl = ['// ---- generated by gen_decoder.py from the S_DECODE body: the decode record of the queue head',
        'localparam NX_NONE = 3\'d0, NX_PSTART = 3\'d1, NX_PREGS = 3\'d2, NX_IMMF_PSTART = 3\'d3, NX_IMMREG = 3\'d4;',
        'wire [3:0] rd_ir_hi     = rd_ir[15:12];',
        'wire [2:0] rdd_reg9     = rd_ir[11:9];',
        'wire [2:0] rdd_op8_6    = rd_ir[8:6];',
        'wire [2:0] rdd_mode     = rd_ir[5:3];',
        'wire [2:0] rdd_rn       = rd_ir[2:0];',
        'wire [1:0] rdd_move_size = (rd_ir[13:12] == 2\'b01) ? `AP040_SZ_B : (rd_ir[13:12] == 2\'b11) ? `AP040_SZ_W : `AP040_SZ_L;',
        'wire [1:0] rdd_std_size = rd_ir[7:6];',
        'wire       rdd_ea_is_imm = (rdd_mode == 3\'b111) && (rdd_rn == 3\'b100);',
        'wire       rdd_dst_not_alt = (rdd_mode == 3\'b001) || ((rdd_mode == 3\'b111) && (rdd_rn > 3\'b001));',
        'wire       rdd_src_not_data = (rdd_mode == 3\'b001) || ((rdd_mode == 3\'b111) && (rdd_rn > 3\'b100));',
        'reg        n_inplace;', 'reg  [2:0] n_next;', 'reg  [1:0] n_immn;']
for name, (w, d) in RECORD.items():
    wd = width_of(name) if w is None else ''
    decl.append(f'reg {wd:8s} n_{name}; reg n_{name}_v;')
defaults = ['\tn_inplace = 0; n_next = NX_NONE; n_immn = 2\'d1;']
for name, (w, d) in RECORD.items():
    if d is not None:
        defaults.append(f'\tn_{name} = {d}; n_{name}_v = 1;')
    else:
        defaults.append(f'\tn_{name} = 0; n_{name}_v = 0;')
block = '\n'.join(decl) + '\nalways @* begin : decode_record\n' + '\n'.join(defaults) + '\n' + inner + '\nend\n'

check = r'''
`ifdef DECODE_CHECK
// Equivalence check: the record computed in the S_DECODE cycle (rd_ir == ir)
// against the registers the body wrote, one cycle later.  Descriptor-covered
// opcodes are skipped (dispatch_reg_decode overrides the body there).
reg        chk_v; reg [15:0] chk_ir; reg [31:0] chk_pc; reg [2:0] chk_next;
''' + '\n'.join(f'reg {width_of(n) if w is None else "":8s} chk_{n}; reg chk_{n}_v;' for n, (w, d) in RECORD.items()) + r'''
always @(posedge clk) begin
	chk_v <= 0;
	if (ce && state == S_DECODE && !rd_valid && !n_inplace) begin
		chk_v <= 1; chk_ir <= ir; chk_pc <= pc_i; chk_next <= n_next;
''' + '\n'.join(f'\t\tchk_{n} <= n_{n}; chk_{n}_v <= n_{n}_v;' for n in RECORD) + r'''
	end
	if (chk_v && ce) begin
''' + '\n'.join(f'\t\tif (chk_{n}_v && chk_{n} !== {n}' + (' && !(chk_next == NX_IMMREG && state == S_IMMF)' if n == 'rr_b' else '') + f') $display("DECODE_CHECK pc=%h ir=%h field {n} record=%h body=%h", chk_pc, chk_ir, chk_{n}, {n});' for n in RECORD) + r'''
		if (chk_next == NX_PSTART && state != S_PIPE_START) $display("DECODE_CHECK pc=%h ir=%h next PSTART but state=%0d", chk_pc, chk_ir, state);
		if (chk_next == NX_PREGS && state != S_PIPE_REGS) $display("DECODE_CHECK pc=%h ir=%h next PREGS but state=%0d", chk_pc, chk_ir, state);
		if (chk_next == NX_IMMF_PSTART && state != S_PIPE_START && state != S_IMMF) $display("DECODE_CHECK pc=%h ir=%h next IMMF_PSTART but state=%0d", chk_pc, chk_ir, state);
		if (chk_next == NX_IMMREG && state != S_PIPE_REGS && state != S_IMMF) $display("DECODE_CHECK pc=%h ir=%h next IMMREG but state=%0d", chk_pc, chk_ir, state);
		if (chk_next == NX_NONE) $display("DECODE_CHECK pc=%h ir=%h record has no next (in-place expected) state=%0d", chk_pc, chk_ir, state);
	end
end
`endif
'''

# 5. splice before the main always block that contains S_DECODE: find "always @(posedge clk)" preceding start
k = core.rfind('always @(posedge clk', 0, start)
core = core[:k] + block + check + '\n' + core[k:]
open(src_path, 'w').write(core)
print('decoder generated:', len(inner.split('\n')), 'lines; record fields', len(RECORD))
