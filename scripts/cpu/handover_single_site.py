#!/usr/bin/env python3
"""Step C3: the retire handover moves out of fetch_next (inlined at 83 sites, which
cost 8,400 ALMs of duplicated record muxes) into the single lookahead arm after the
state case, keyed on rd_queue_pop, which fetch_next's pop branch alone sets."""
import sys
p = sys.argv[1]; s = open(p).read()
def rep(old, new, count=1):
    global s
    n = s.count(old); assert n == count, (old[:70], n)
    s = s.replace(old, new)
rep("""			rd_queue_pop = 1;
			// Step C: every retire that pops the next opcode hands it over
			// from the descriptor or the decode record when they cover it.
			if (n_desc_ok) dispatch_reg_decode;
			else if (n_apply_ok) apply_record;
""", """			rd_queue_pop = 1;
""")
rep("""		if (rd_valid && ((state == S_DECODE) ||
		    (rd_queue_pop && !aux_we &&
		     (regs_alu_fire || shift_fire ||
		      ((state == S_MWR) && d_ack && (r_m_ret == S_NEXT))))))
			dispatch_reg_decode;
""", """		// Steps C/C2/C3: every retire that pops the next opcode (rd_queue_pop
		// is set only by fetch_next's pop branch) hands it over from the
		// descriptor or the decode record when they cover it, from this one
		// site: the same call inside fetch_next was inlined at 83 sites and
		// cost 8,400 ALMs of duplicated record muxes.
		if (rd_valid && ((state == S_DECODE) || (rd_queue_pop && n_desc_ok)))
			dispatch_reg_decode;
		else if (rd_queue_pop && n_apply_ok)
			apply_record;
""")
open(p, 'w').write(s); print("step C3 applied")
