#!/usr/bin/env python3
"""Step C2: the descriptor classes dispatch at every retire site too, both handovers
guarded against retires from system states."""
import sys
p = sys.argv[1]; s = open(p).read()
def rep(old, new, count=1):
    global s
    n = s.count(old); assert n == count, (old[:70], n)
    s = s.replace(old, new)
SYS = ['S_HALT','S_STOPPED','S_EXC0','S_EXC1','S_EXC2','S_EXC3','S_EXC4','S_EXC5','S_EXC6','S_EXC_VEC','S_EXC_JMP',
       'S_RTE_SR','S_RTE_PC','S_RTE_FMT','S_RTE_FIN','S_RTE_FIN2','S_USP1','S_MOVEC1','S_MOVEC2','S_MOVES1','S_MOVES2',
       'S_MOVES_WR','S_MOVES_RD','S_PTEST1','S_RESET_HOLD','S_SROP','S_TRAPCC','S_STOP_LD','S_PFLUSH1','S_PFLUSH2',
       'S_PTEST2','S_CINV2','S_EXC4B','S_EPF_FILL','S_EPF_GAP','S_EPF_READY','S_POST_EXC','S_EXC0_F2','S_EXC0_F3',
       'S_EXC0_F4','S_POST_EXC_F2','S_POST_EXC_F3','S_POST_EXC_F4']
sysw = "// A retire from a system state (SR, USP, MOVEC, MOVES, CINV, PFLUSH, RTE,\n" \
       "// STOP, the exception sequences) may change the A7 bank or an auxiliary\n" \
       "// register on this edge: the next opcode decodes in place after it.\n" \
       "wire        sys_retire = " + " ||\n                          ".join(f"(state == {x})" for x in SYS) + ";\n"
rep("""wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                        (state != S_DECODE) && !aux_we;""",
    sysw + """wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                        (state != S_DECODE) && !aux_we && !sys_retire;
// the descriptor classes dispatch at every ordinary retire as well
wire        n_desc_ok  = rd_valid && (state != S_DECODE) && !aux_we && !sys_retire;""")
rep("""			// Step C: every retire that pops the next opcode hands it over
			// from the decode record when the record covers it.
			if (n_apply_ok) apply_record;""",
"""			// Step C: every retire that pops the next opcode hands it over
			// from the descriptor or the decode record when they cover it.
			if (n_desc_ok) dispatch_reg_decode;
			else if (n_apply_ok) apply_record;""")
open(p, 'w').write(s); print("step C2 applied")
