#!/usr/bin/env python3
"""Step C: the record handover inside fetch_next (every retire site); the pipe start's
source-memory paths read the forwarded port so no producer-side guard is needed."""
import sys
p = sys.argv[1]; s = open(p).read()
def rep(old, new, count=1):
    global s
    n = s.count(old); assert n == count, (old[:70], n)
    s = s.replace(old, new)
# 1. forwarded base in the pipe start's (An), (An)+, -(An) source paths
rep("""							3'b010: begin
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(rf_rdata_a, p_ssize, S_PIPE_SDONE);
							end
							3'b011: begin
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(rf_rdata_a, p_ssize, S_PIPE_SDONE);
								rfw({1'b1, src_rn_r},
								    rf_rdata_a + an_adj(src_rn_r, p_ssize));
								u_rec({1'b1, src_rn_r}, rf_rdata_a);
							end
							3'b100: begin : pipe_predec_read
								reg [31:0] predec_addr;
								predec_addr = rf_rdata_a - an_adj(src_rn_r, p_ssize);
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(predec_addr, p_ssize, S_PIPE_SDONE);
								rfw({1'b1, src_rn_r}, predec_addr);
								u_rec({1'b1, src_rn_r}, rf_rdata_a);
							end""",
"""							// The base comes through the forwarded port: a record
							// handed over at a retire that writes this register
							// reaches here while that write lands.
							3'b010: begin
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(rf_capture_a, p_ssize, S_PIPE_SDONE);
							end
							3'b011: begin
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(rf_capture_a, p_ssize, S_PIPE_SDONE);
								rfw({1'b1, src_rn_r},
								    rf_capture_a + an_adj(src_rn_r, p_ssize));
								u_rec({1'b1, src_rn_r}, rf_capture_a);
							end
							3'b100: begin : pipe_predec_read
								reg [31:0] predec_addr;
								predec_addr = rf_capture_a - an_adj(src_rn_r, p_ssize);
								if (p_dst == DK_REG) rr_b <= p_dreg;
								mrd(predec_addr, p_ssize, S_PIPE_SDONE);
								rfw({1'b1, src_rn_r}, predec_addr);
								u_rec({1'b1, src_rn_r}, rf_capture_a);
							end""")
# 2. the apply condition without the producer term, and inside fetch_next's pop branch
rep("""wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok && !n_base_hazard;""",
    """wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok &&
                        (state != S_DECODE) && !aux_we;""")
rep("""			p_dst_mem_bit <= 0;
			exec_kind <= EK_ALU;
			state <= S_DECODE;
			rd_queue_pop = 1;
		end""",
"""			p_dst_mem_bit <= 0;
			exec_kind <= EK_ALU;
			state <= S_DECODE;
			rd_queue_pop = 1;
			// Step C: every retire that pops the next opcode hands it over
			// from the decode record when the record covers it.
			if (n_apply_ok) apply_record;
		end""")
# 3. the step B arm in the lookahead block is now redundant
rep("""		else if (n_apply_ok && rd_queue_pop && !aux_we && (state != S_DECODE) &&
		         (regs_alu_fire || shift_fire ||
		          ((state == S_MWR) && d_ack && (r_m_ret == S_NEXT))))
			apply_record;
""", "")
open(p, 'w').write(s); print("step C applied")
