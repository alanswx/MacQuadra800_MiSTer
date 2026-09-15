#!/usr/bin/env python3
"""Step D: S_DECODE consumes the decode record; the decode body keeps only the
paths the record marks in place.

Usage: reduce_decode_body.py CORE.v  (in place; CORE.v must already carry the record block,
apply_record and the step C/C2 handover).

Semantics: the record block is the S_DECODE body evaluated on rd_ir (== ir in
S_DECODE).  A statement of the body that assigns a record field, or that is
one of the rewritten "next" calls (pipe_go, pipe_go_regpair, pipe_go_regdst,
immf(n, S_PIPE_START), immf_reg), is removed when no execution path through it
contains an in-place statement, since on every such path the record carries the
same value and S_DECODE now applies the record first.  Paths with an in-place
statement keep everything.
"""
import re, sys

RECORD = ['p_src', 'p_dst', 'p_rmw', 'p_wbsup', 'p_flags', 'p_sextw', 'p_dst_mem_bit', 'exec_kind',
          'op_size', 'alu_op', 'p_dreg', 'p_dsize', 'p_ssize', 'p_sreg', 'dst_rn_r', 'dst_mode_r',
          'src_rn_r', 'src_mode_r', 'rr_a', 'rr_b', 'src_val', 'sh_rox', 'md_isdiv', 'md_sign', 'lk_cyc']
NEXT_CALLS = re.compile(r'^(pipe_go|pipe_go_regpair\s*\(.*\)|pipe_go_regdst\s*\(.*\)|immf\s*\(.*,\s*S_PIPE_START\s*\)|immf_reg\s*\(.*\))\s*;$', re.S)

src_path = sys.argv[1]
core = open(src_path).read()

m = re.search(r'\n\t\t\tS_DECODE: begin\n', core)
start = m.start() + 1
m2 = re.search(r'\n\t\t\tS_[A-Z0-9_]+: begin\n', core[m.end():])
end = m.end() + m2.start() + 1
body = core[start:end]
lines = body.split('\n')
assert lines[0].strip() == 'S_DECODE: begin'
j = len(lines) - 1
while lines[j].strip() == '' or lines[j].strip().startswith('//'): j -= 1
assert lines[j] == '\t\t\tend', repr(lines[j])
inner = '\n'.join(lines[1:j])

# ---- tokenizer: strip comments, keep text
def strip_comments(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    return s
text = strip_comments(inner)

# ---- parser for the statement subset used by the body
class Stmt:
    def __init__(self, text): self.text = text.strip()
class Block:
    def __init__(self, items, name=None): self.items, self.name = items, name
class If:
    def __init__(self, cond, then, els): self.cond, self.then, self.els = cond, then, els
class Case:
    def __init__(self, kw, expr, arms): self.kw, self.expr, self.arms = kw, expr, arms  # arms: [(label, node)]

pos = 0
def skip_ws():
    global pos
    while pos < len(text) and text[pos] in ' \t\r\n': pos += 1
def peek_word():
    skip_ws()
    m = re.match(r'[A-Za-z_][A-Za-z_0-9]*', text[pos:])
    return m.group(0) if m else ''
def take_word(w):
    global pos
    skip_ws()
    assert text.startswith(w, pos), (w, text[pos:pos+60])
    pos += len(w)
def take_parens():
    """read a balanced (...) and return the inside"""
    global pos
    skip_ws()
    assert text[pos] == '(', text[pos:pos+60]
    depth = 0; i = pos
    while True:
        c = text[i]
        if c == '(': depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0: break
        i += 1
    inside = text[pos+1:i]
    pos = i + 1
    return inside
def parse_stmt():
    global pos
    skip_ws()
    w = peek_word()
    if w == 'begin':
        take_word('begin')
        skip_ws()
        name = None
        if text[pos] == ':':
            pos += 1
            name = peek_word(); take_word(name)
        items = []
        while True:
            skip_ws()
            if peek_word() == 'end' and not re.match(r'end[A-Za-z_0-9]', text[pos:]):
                take_word('end'); break
            items.append(parse_stmt())
        return Block(items, name)
    if w == 'if':
        take_word('if')
        cond = take_parens()
        then = parse_stmt()
        els = None
        skip_ws()
        if peek_word() == 'else':
            take_word('else')
            els = parse_stmt()
        return If(cond, then, els)
    if w in ('case', 'casez', 'casex'):
        take_word(w)
        expr = take_parens()
        arms = []
        while True:
            skip_ws()
            if peek_word() == 'endcase':
                take_word('endcase'); break
            # label up to ':' at depth 0 (labels can contain braces/parens but the body's don't contain ':')
            i = pos; depth = 0
            while True:
                c = text[i]
                if c in '([{': depth += 1
                elif c in ')]}': depth -= 1
                elif c == ':' and depth == 0: break
                i += 1
            label = text[pos:i].strip()
            pos = i + 1
            node = parse_stmt()
            arms.append((label, node))
        return Case(w, expr, arms)
    # plain statement up to ';' (brace/paren aware)
    i = pos; depth = 0
    while True:
        c = text[i]
        if c in '([{': depth += 1
        elif c in ')]}': depth -= 1
        elif c == ';' and depth == 0: break
        i += 1
    s = text[pos:i+1]
    pos = i + 1
    return Stmt(s)

top = []
while True:
    skip_ws()
    if pos >= len(text): break
    top.append(parse_stmt())
root = Block(top)

# ---- classification
ASSIGN = re.compile(r'^([a-z_0-9]+)\s*(\[[^\]]*\])?\s*<=\s*(.*);$', re.S)
def classify(st):
    """'record' (removable when on record-only paths), 'inplace', or error"""
    t = st.text
    if t == ';': return 'record'
    if re.match(r'^(reg|integer)\b', t): return 'local'
    if re.match(r'^[a-z_0-9]+\s*=[^=]', t): return 'local'   # blocking assignment to a block local
    ma = ASSIGN.match(t)
    if ma:
        name, sel, expr = ma.group(1), ma.group(2), ma.group(3)
        if name in RECORD:
            if sel: sys.exit(f'bit-select assignment to record field: {t}')
            if re.search(r'\bsr\b', expr): return 'inplace'
            return 'record'
        return 'inplace'
    if NEXT_CALLS.match(t): return 'record'
    if re.match(r'^[a-z_0-9]+\s*(\(.*\))?\s*;$', t, re.S): return 'inplace'   # any other task call
    sys.exit(f'unclassified statement: {t!r}')

def has_inplace(n):
    if isinstance(n, Stmt): return classify(n) == 'inplace'
    if isinstance(n, Block): return any(has_inplace(i) for i in n.items)
    if isinstance(n, If): return has_inplace(n.then) or (n.els is not None and has_inplace(n.els))
    if isinstance(n, Case): return any(has_inplace(a) for _, a in n.arms)
    raise TypeError

removed = [0]; kept_record = [0]
def reduce(n, ctx_inplace):
    """ctx_inplace: an in-place statement exists on every path through n (siblings/ancestors).
    Returns the reduced node or None if empty."""
    if isinstance(n, Stmt):
        c = classify(n)
        if c == 'record' and not ctx_inplace:
            removed[0] += 1
            return None
        if c == 'local': return n
        if c == 'record': kept_record[0] += 1
        return n
    if isinstance(n, Block):
        flags = [has_inplace(i) for i in n.items]
        out = []
        for k, it in enumerate(n.items):
            sib = any(f for q, f in enumerate(flags) if q != k)
            r = reduce(it, ctx_inplace or sib)
            if r is not None: out.append(r)
        if not any(not (isinstance(i, Stmt) and classify(i) == 'local') for i in out): return None
        return Block(out, n.name)
    if isinstance(n, If):
        t = reduce(n.then, ctx_inplace)
        e = reduce(n.els, ctx_inplace) if n.els is not None else None
        if t is None and e is None: return None
        return If(n.cond, t if t is not None else Block([]), e)
    if isinstance(n, Case):
        arms = []
        for lab, a in n.arms:
            r = reduce(a, ctx_inplace)
            if r is not None: arms.append((lab, r))
        if not arms: return None
        return Case(n.kw, n.expr, arms)
    raise TypeError

red = reduce(root, False)

# ---- emit
def emit(n, ind):
    T = '\t' * ind
    if isinstance(n, Stmt):
        return T + n.text + '\n'
    if isinstance(n, Block):
        if not n.items: return T + 'begin end\n'
        return T + 'begin' + (' : ' + n.name if n.name else '') + '\n' + ''.join(emit(i, ind + 1) for i in n.items) + T + 'end\n'
    if isinstance(n, If):
        s = T + 'if (' + ' '.join(n.cond.split()) + ')\n'
        s += emit(n.then, ind + 1) if not isinstance(n.then, Block) else emit(n.then, ind)
        if n.els is not None:
            s += T + 'else\n'
            s += emit(n.els, ind + 1) if not isinstance(n.els, Block) else emit(n.els, ind)
        return s
    if isinstance(n, Case):
        s = T + n.kw + ' (' + n.expr.strip() + ')\n'
        for lab, a in n.arms:
            s += T + '\t' + ' '.join(lab.split()) + ':'
            if isinstance(a, Block):
                s += '\n' + emit(a, ind + 1)
            else:
                s += ' ' + emit(a, 0)
        s += T + 'endcase\n'
        return s
    raise TypeError

new_inner = emit(red, 4) if red is not None else ''
new_body = ('\t\t\tS_DECODE: begin\n'
            '\t\t\t\t// Step D: the body keeps only the paths the record marks in\n'
            '\t\t\t\t// place (generated by step_d.py); the record over ir (rd_ir\n'
            '\t\t\t\t// selects ir here) is applied after it, so its values win\n'
            '\t\t\t\t// over the shared statements kept for the in-place paths.\n'
            + new_inner + '\t\t\t\tif (!n_inplace) apply_record_decode;\n' + '\t\t\tend\n')
core = core[:start] + new_body + core[end:]

# ---- the decode-cycle apply task, next to apply_record
task = '''
// Step D: the record applied in the decode cycle itself.  The immediate
// forms take the body's own inline paths (immf / immf_reg), so the queue
// ownership rules and the deferred S_IMMF case are unchanged; rr_b for the
// immediate-to-register form is set by immf_reg on its inline path only, as
// the body did.
task apply_record_decode;
	begin
'''
for n in RECORD:
    if n == 'rr_b':
        task += f'\t\tif (n_{n}_v && n_next != NX_IMMREG) {n} <= n_{n};\n'
    else:
        task += f'\t\tif (n_{n}_v) {n} <= n_{n};\n'
task += '''		case (n_next)
			NX_PSTART: state <= S_PIPE_START;
			NX_PREGS:  state <= S_PIPE_REGS;
			NX_IMMF_PSTART: immf(n_immn, S_PIPE_START);
			NX_IMMREG: immf_reg(n_immn, n_rr_b);
			default: begin end
		endcase
	end
endtask
'''
k = core.index('task apply_record;')
core = core[:k] + task.lstrip('\n') + '\n' + core[k:]
open(src_path, 'w').write(core)
print(f'step D: removed {removed[0]} record statements, kept {kept_record[0]} on in-place paths; body {len(inner.splitlines())} -> {len(new_inner.splitlines())} lines')
