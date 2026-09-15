#!/usr/bin/env python3
"""Step B: apply the decode record at the lookahead sites for every pipe-class instruction."""
import sys, re
p = sys.argv[1]; s = open(p).read()
def rep(old, new):
    global s
    assert s.count(old) == 1, old[:70]
    s = s.replace(old, new)
RECORD = ['p_src','p_dst','p_rmw','p_wbsup','p_flags','p_sextw','p_dst_mem_bit','exec_kind','op_size','alu_op',
          'p_dreg','p_dsize','p_ssize','p_sreg','dst_rn_r','dst_mode_r','src_rn_r','src_mode_r','rr_a','rr_b',
          'src_val','sh_rox','md_isdiv','md_sign','lk_cyc']
apply = "// Step B: enter the next instruction from the decode record at a producer's\n" \
        "// retire, for every class the record covers (the descriptor's classes\n" \
        "// keep dispatch_reg_decode).  The immediate forms consume their words\n" \
        "// here, as the descriptor's immediate class does.\n" \
        "wire [31:0] n_immv = (n_immn == 2'd2) ? {rd_w1, rd_w2} : {16'd0, rd_w1};\n" \
        "wire        n_words_ok = ((n_next == NX_IMMF_PSTART) || (n_next == NX_IMMREG)) ?\n" \
        "                         (epf_count >= (4'd1 + {2'd0, n_immn})) : 1'b1;\n" \
        "wire        n_apply_ok = !rd_valid && !n_inplace && (n_next != NX_NONE) && n_words_ok;\n" \
        "task apply_record;\n\tbegin\n"
for f in RECORD:
    apply += f"\t\tif (n_{f}_v) {f} <= n_{f};\n"
apply += """		case (n_next)
			NX_PSTART: state <= S_PIPE_START;
			NX_PREGS:  state <= S_PIPE_REGS;
			NX_IMMF_PSTART: begin
				imm <= n_immv;
				epf_pop = 2'd1 + n_immn;
				pc <= pc + 32'd2 + {29'd0, n_immn, 1'b0};
				state <= S_PIPE_START;
			end
			NX_IMMREG: begin
				src_val <= n_immv; imm <= n_immv; x_ext <= n_immv;
				epf_pop = 2'd1 + n_immn;
				pc <= pc + 32'd2 + {29'd0, n_immn, 1'b0};
				state <= S_PIPE_REGS;
			end
			default: begin end
		endcase
	end
endtask

"""
rep("task fetch_next;\n", apply + "task fetch_next;\n")
old_tail = """			else if (epf_count >= 4'd2) begin
				ir <= epf_data[epf_head + 3'd1];
				t0_force <= t0_special(epf_data[epf_head + 3'd1]);
				pc_i <= pc + 32'd2;
				pc <= pc + 32'd4;
				epf_pop = 2'd2;
			end
		end
"""
new_tail = old_tail + """		else if (n_apply_ok && rd_queue_pop && !aux_we && (state != S_DECODE) &&
		         (regs_alu_fire || shift_fire ||
		          ((state == S_MWR) && d_ack && (r_m_ret == S_NEXT))))
			apply_record;
"""
rep(old_tail, new_tail)
open(p, 'w').write(s); print("step B applied")
