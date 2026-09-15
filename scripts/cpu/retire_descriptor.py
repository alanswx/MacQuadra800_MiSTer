#!/usr/bin/env python3
"""Step E: the register-class descriptor (rd_valid / dispatch_reg_decode) is retired;
the decode record covers its classes.  BOUND=c keeps step C's semantics (the former
descriptor classes hand over at ALU/shift/store producers only), BOUND=c2 hands every
record over at every retire.  Usage: step_e.py CORE.v c|c2"""
import sys, re
p = sys.argv[1]; bound = sys.argv[2]; s = open(p).read()
def rep(old, new, count=1):
    global s
    n = s.count(old); assert n == count, (old[:70], n)
    s = s.replace(old, new)
# the record decodes the descriptor's classes itself
n = s.count("if (rd_valid) begin end")
s = s.replace("if (rd_valid) begin end", "if (1'b0) begin end")
print("record guards opened:", n)
# the single handover arm: record only
rep("""		if (rd_valid && ((state == S_DECODE) || (rd_queue_pop && n_desc_ok)))
			dispatch_reg_decode;
		else if (rd_queue_pop && n_apply_ok)
			apply_record;
""", """		// Step E: the record alone (the register-class descriptor is retired).
		if (rd_queue_pop && n_apply_ok)
			apply_record;
""")
if bound == 'c':
    rep("""wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                        (state != S_DECODE) && !aux_we;""",
        """// Step E (bound c): the classes the descriptor used to cover hand over at
// the ALU/shift/store producers only, as step C did; the decode cycle they
// keep after other retires is the fetch engine's and the store drain's slot.
wire        n_apply_ok = (!rd_valid || regs_alu_fire || shift_fire ||
                          ((state == S_MWR) && d_ack && (r_m_ret == S_NEXT))) &&
                         !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                         (state != S_DECODE) && !aux_we;""")
else:
    rep("""wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                        (state != S_DECODE) && !aux_we;""",
        """// Step E (bound c2): every record hands over at every ordinary retire.
wire        n_apply_ok = !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                         (state != S_DECODE) && !aux_we;""")
# n_desc_ok and the dispatch task are dead: remove them
s = re.sub(r"// dovi: the descriptor dispatch bounded.*?\nwire        n_desc_ok  = .*?;\n", "", s, flags=re.S)
assert "n_desc_ok" not in s
k = s.index("task dispatch_reg_decode;"); e = s.index("endtask", k) + len("endtask\n")
s = s[:k] + "// (dispatch_reg_decode retired by step E: the record covers its classes)\n" + s[e:]
open(p, 'w').write(s); print("step E applied, bound", bound)
