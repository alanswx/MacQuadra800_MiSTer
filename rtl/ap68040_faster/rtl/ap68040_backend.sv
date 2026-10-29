//--------------------------------------------------------------------------//
// AP68040 - pipelined MC68040                                            //
//                                                                          //
// ap68040_backend.sv - AG, DC1, DC2, EX and WB stages                       //
//                                                                          //
//   AG   read the front register file, effective address, (An)+/-(An)     //
//        and LEA-class register updates (written to the front file)       //
//   DC1  data ATC / cache lookup (ap68040_dmu)                             //
//   DC2  way select and operand alignment (ap68040_dmu)                    //
//   EX   ALU, shifter, multiply/divide, branch resolution, front-file      //
//        result write                                                      //
//   WB   back (architectural) register file, CCR/SR, stores, exceptions,  //
//        interrupts, trace, serialization                                  //
//                                                                          //
// Operand values are read at AG.  A result produced by an older uop in EX  //
// is broadcast and captured by every younger uop in AG/DC1/DC2 whose       //
// operand names that register, so EX never forwards; address operands     //
// (base, index, register updates) instead interlock at AG on any older    //
// uop that will write the register in EX.                                  //
//                                                                          //
// Every redirect (branch mispredict, exception, serialization) happens in  //
// WB, from state registered at the end of EX.                              //
//--------------------------------------------------------------------------//

module ap68040_backend
	import ap68040_pkg::*;
#(
	parameter logic [7:0] FPU_REVISION = 8'h41,   // FSAVE frame revision ($40: 44-byte UNIMP)
	parameter bit         FPU_PIPE  = 1,
	parameter bit         EARLY_RES = 1,
	parameter bit         SKID      = 1,      // the skid register in front of AG
	parameter int         DIV_STEPS = 2,      // divide steps per cycle
	parameter bit         DUAL      = 1       // the second slot (ap68040_pkg s1_t)
)(
	input  logic        clk,
	input  logic        nreset,

	// uops from the sequencer
	input  logic        in_v,
	input  uop_t        in_u,
	input  logic  [4:0] in_nb,          // in_u's base and index next cycle
	input  logic  [4:0] in_nx,
	input  s1_t         in_s,           // ... and the second slot beside it
	output logic        in_rdy,
	output logic        in_rdy_a,       // ... as AG's read addresses assume it (see rra0_q)

	// redirect of the front end (registered)
	output logic        redir_v,
	output logic [31:0] redir_pc,
	output logic        flush,          // kill everything younger than WB
	output logic        fe_flush,       // the front end's flush (D1, D2)
	output logic        ras_rv,         // D1's return stack to restore with it
	output logic  [2:0] ras_rtp,
	output logic  [3:0] ras_rn,

	// exception entry for the sequencer
	output logic        exc_go,         // pulse: run the exception routine
	output logic        exc_pend,       // the entry is being prepared: no uop may issue
	output logic  [3:0] exc_kind,       // routine selector (see EK_*)
	output logic  [4:0] exc_ssp,        // supervisor stack register to use

	// micro-branch result back to the sequencer
	output logic        ucond_v,
	output logic        ucond,

	// architectural state the front end needs
	output logic [15:0] sr,
	output logic  [4:0] sp_sel,         // the stack register SR selects (written with it)
	output logic [31:0] vbr,
	output logic [31:0] cacr,
	output logic  [2:0] sfc,
	output logic  [2:0] dfc,

	// data memory unit (DC1/DC2 lookups; WB stores)
	output logic        dm_req,         // AG -> DC1: a memory uop advances
	output logic [31:0] dm_va,
	output logic  [1:0] dm_mem,
	output logic  [1:0] dm_msz,
	output logic  [2:0] dm_fc,
	output logic        dm_lock,
	output logic        dm_locke,
	output logic        dm_super,
	output logic        dm_older,       // uops older than DC2 are in EX or WB
	output logic        dm_s1,          // DC2's access is the second slot's load
	input  logic        sn_ihit,        // a snoop dropped valid instruction-cache data
	input  logic        tw_busy,        // the DMU runs a table search
	output logic        pst_ev,         // PST: an instruction ends this cycle...
	output logic  [3:0] pst_code,       // ...with this encoding (MC68040UM table 5-6)
	output logic  [3:0] pst_st,         // the present status otherwise
	output logic        irq_pending,    // IPEND: a request beats the mask
	output logic        bht_we,         // Bcc history training (decode's table)
	output logic  [7:0] bht_wa,
	output logic        bht_dis,        // ... the branch went against the static rule
	output logic        lp_we,          // loop exit training (decode's table)
	output logic [11:0] lp_wa,
	output logic        lp_tk,
	output logic        lp_mp,
	output logic        dm_noalloc,     // exception stacking / vector fetch
	output logic        dm_pastc,       // the level-7 vector fetch: read past the cache
	output logic  [1:0] dm_ack,         // acknowledge cycle: 1 IACK, 2 BKPT
	input  logic        dm_hold1,       // the DMU holds DC1
	// WB maintenance (CINV/CPUSH/PFLUSH/PTEST) in the DMU
	output logic        mt_v,
	output logic  [2:0] mt_op,
	output logic  [1:0] mt_scope,
	output logic  [1:0] mt_caches,
	output logic [31:0] mt_addr,
	output logic  [2:0] mt_fc,
	output logic        mt_ng,
	output logic        mt_wr,
	input  logic        mt_done,
	input  logic [31:0] mt_mmusr,       // PTEST: the MMUSR
	input  logic        mt_fault,       // CPUSH: a push ended in TEA (an access error)
	input  logic [15:0] mt_fssw,
	input  logic [31:0] mt_faddr,
	output logic        adv_dc1,        // DC1 -> DC2
	output logic        hold_dc1,       // DC1 holds its uop (stall_dc1: AG cannot advance)
	output logic        adv_dc2,        // DC2 -> EX
	output logic        adv_ex,         // EX -> WB
	output logic        adv_wb,         // WB completes
	input  logic        dm_dc2_rdy,     // DC2 memory op has its result
	input  logic [31:0] dm_ldata,       // load data, right aligned
	input  logic [31:0] dm_ldata_al,    // the aligned operand (AG's capture)
	input  logic        dm_ldata_alv,   // ... is the load's data
	input  logic        dm_fault,       // DC2 access fault (with info below)
	input  logic  [7:0] dm_fvec,        // 2 access error, 3 address error
	input  logic [31:0] dm_faddr,
	input  logic [15:0] dm_fssw,        // ... its special status word
	output logic        dm_st_v,        // WB store data valid this cycle
	output logic [31:0] dm_st_data,
	input  logic        dm_st_rdy,      // store accepted (WB may complete)
	input  logic        dm_st_fault,
	input  logic [15:0] dm_st_fssw,
	input  logic [31:0] dm_st_faddr,

	// interrupts (synchronized level, 0-7)
	input  logic  [2:0] ipl,
	input  logic  [3:0] dbcc_floor,
	output logic  [2:0] iack_lvl,
	output logic        rsto_req,
	input  logic        rsto_busy,

	output logic        kill_now,       // this cycle: younger uops are discarded
	output logic        lk_abandon,     // an open locked sequence is abandoned
	output logic        adv_ag,         // AG -> DC1
	output logic [31:0] dtt0,
	output logic [31:0] dtt1,
	output logic [31:0] itt0,
	output logic [31:0] itt1,
	output logic [31:0] tc,
	output logic [31:0] urp,
	output logic [31:0] srp,

	// debug
	output logic [31:0] dbg_pc,
	output logic        dbg_retire,
	output logic        dbg_retire2,    // ... and a second instruction (the second slot)
	output logic        halted,
	output logic        fetch_stop,     // no new instruction fetches: stopped
                                        // (STOP) or halted
	output logic  [7:0] fp_mvslots
);

// the SR bits the 68040 keeps: T1 T0 S M I2-I0 X N Z V C
localparam logic [15:0] SR_MASK = 16'hF71F;

//--------------------------------------------------------------------------
// exception routine kinds (sequencer entry points)
//--------------------------------------------------------------------------
localparam logic [3:0] EK_FMT0  = 4'd0;   // format $0 (PC = exc_pc)
localparam logic [3:0] EK_FMT2  = 4'd1;   // format $2 / $3 (+ address)
localparam logic [3:0] EK_FMT7  = 4'd2;   // access error
localparam logic [3:0] EK_IRQ   = 4'd3;   // interrupt (IACK + format $0)
localparam logic [3:0] EK_RESET = 4'd4;   // reset: SSP/PC from 0/4
localparam logic [3:0] EK_IRQM  = 4'd5;   // interrupt with M set (throwaway frame)

//--------------------------------------------------------------------------
// pipeline registers
//--------------------------------------------------------------------------
logic        ag_v, dc1_v, dc2_v, ex_v, wb_v;
uop_t        ag_u, dc1_u, dc2_u, ex_u, wb_u;
// the second slot of each stage (valid with the stage: X_v && X_s.v), and
// its operand values
s1_t         ag_s, dc1_s, dc2_s, ex_s, wb_s;
logic [31:0] dc1_a1, dc1_b1, dc2_a1, dc2_b1, ex_a1, ex_b1;
logic [31:0] wb1_res;
logic  [4:0] wb1_ccr;         // CCR after the pair
logic [31:0] wb_npc1;         // the instruction after the second slot's
logic [31:0] ex_npc, wb_npc;  // EX's and WB's next instruction (pc + 2 ilen)

// operand values carried with the uop
logic [31:0] dc1_a, dc1_b, dc1_ea;
// early results: a simple register operation computes its result in AG
// as well (ag_er), carried beside the uop (ee: valid) for the base and
// index of younger uops; EX still produces and writes it as always
logic        dc1_ee, dc2_ee, ex_ee;
logic [31:0] dc1_er, dc2_er, ex_er;
logic        erb, erx;         // agb_q / agx_q hold the youngest writer's early result
logic [31:0] dc2_a, dc2_b, dc2_ea;
logic [31:0] ex_a,  ex_b,  ex_ea,  ex_ld;
logic        ex_fault;
logic        ex1_flt;         // the second slot's load faulted (fetched again from WB)
logic        wb1_flt;
logic  [7:0] ex_fvec;
logic [31:0] ex_faddr;
logic [15:0] ex_fssw;

// results carried into WB
logic [31:0] wb_res;
logic  [4:0] wb_ccr;          // CCR after this uop
logic        wb_dwe;          // result register write (after EX kills)
logic [31:0] wb_upd_val, wb_upd2_val;
logic        wb_redir;        // the uop redirects the front end
logic [31:0] wb_redir_pc;
logic  [7:0] wb_exc;          // exception vector, 0 none
logic        wb_exc_pcv;      // the frame PC is wb_exc_pc (odd change of flow)
logic [31:0] wb_exc_pc;
logic        wb_oddrte;       // RTE to an odd PC: its SR is committed first
logic        wb_exc_fmtv;     // the frame format is wb_exc_fmt (FPU exceptions)
logic  [3:0] wb_exc_fmt;
logic        wb_xcommit;      // the uop's address updates stand (FPU unimp/unsupp)
logic [31:0] wb_exc_addr;
// an odd branch target's address error takes its address from wb_otgt,
// registered on every EX advance, chosen at WB by wb_exa_odd: the target
// adder and the odd/taken decision stay off wb_exc_addr's priority select
logic [31:0] wb_otgt;          // (the whole target: a JSR's frame PC; the address takes it even)
logic        wb_exa_odd;
logic        wb_pc_tgt;        // the frame PC is wb_otgt (an odd JSR target)
logic [31:0] wb_fpc;           // an FPU exception's frame PC
logic        wb_pc_fp;         // ... which the frame takes
logic [15:0] wb_exc_ssw;      // SSW of an access error
logic        wb_st;           // store at WB
logic [31:0] wb_st_data;
logic [15:0] wb_sr_new;       // SR write
logic        wb_sr_we;

// AG register updates travel with the uop for the back file
logic [31:0] dc1_upd, dc1_upd2, dc2_upd, dc2_upd2, ex_upd, ex_upd2;

//--------------------------------------------------------------------------
// register files
//--------------------------------------------------------------------------
// Register files (ap68040_rf, MLAB): the front file holds the newest
// values (AG address updates, EX results), the back file the architectural
// ones (WB).  fv[r] says the front copy of r is current; a redirect or an
// exception clears fv, so every register reads the back file again -- no
// copy.  Five read ports at AG: base, index, upd2 register, A, B.
logic [31:0] fv;
logic        fv_clr;          // fv clears (the clock after a kill)
// an FPU uop may act once it is the oldest in flight -- or when the one at
// WB is an earlier uop of its own instruction that commits: no exception
// (a load's fault is known by now), not the last uop (no instruction
// boundary between them: no interrupt or trace), and not a store (a bus
// error on a store comes after WB)
// (ew_same: ex_u.pc == wb_u.pc, kept as the two load -- the compare
// stays off the FPU's hold, and so the stall chain)
logic ew_same;
logic wb_ok;                  // WB's uop has no exception (wb_exc == 0), registered
wire wb_fpchk = wb_v && !wb_u.last && wb_ok &&
                (wb_u.mem == M_NONE || wb_u.mem == M_LD) &&
                ex_v && ex_u.op == OP_FPU && ew_same;
// FPU interface outputs (ap68040_fpif)
logic        fp_hold, fp_dkill, fp_taken, fp_xnext, fp_xcommit, fp_stkill;
logic [31:0] fp_res, fp_xaddr;
logic  [7:0] fp_xvec;
logic  [3:0] fp_xfmt;
// logic  [7:0] fp_mvslots; (now output port)
logic  [2:0] fp_crslots;
logic  [4:0] fp_svwords, fp_rswords;
logic [31:0] fp_get1, fp_get2;
logic  [2:0] fwe, bwe;
logic  [1:0] fwe_ag;           // fwe[0..1] without the advance (AG holds an update)
logic  [4:0] fwa [3], bwa [3];
logic [31:0] fwd [3], bwd [3];
localparam int NRP = DUAL ? 6 : 5;
// (with the skid, two more read ports: AG's base and index at the held
// uop's registers beside ports 0 and 1 at the next head's -- see rsel_q)
localparam int NRF = NRP + (SKID ? 2 : 0);
localparam int PH0 = NRF - 2, PH1 = NRF - 1;
logic  [4:0] rra [6];
logic  [4:0] rfa [8];
logic [31:0] frd [8], brd [8], rrd [6];
logic  [4:0] ccr_f, ccr_b;

// special registers (architectural, written at WB)
logic [15:0] sr_r;            // T1 T0 S M 0 I2 I1 I0 (CCR lives in ccr_b)
logic [31:0] vbr_r, cacr_r;
logic  [2:0] sfc_r, dfc_r;
logic [31:0] tc_r, itt0_r, itt1_r, dtt0_r, dtt1_r, mmusr_r, urp_r, srp_r;

// exception information for the exception microroutine
logic [31:0] xi_pc, xi_addr;
logic [15:0] xi_sr, xi_vecw, xi_ssw;
logic [31:0] xi_vaddr, xi_ea, xi_w3a, xi_w3d;
logic        xi_f7;           // the frame is format $7: T5-T7 too
logic  [2:0] xw_ph;           // exception entry: back-file writes of T5-T13
logic        xw_pend;         // ... xw_ph != 0, a flip-flop of its own (exc_pend)

assign sr   = {sr_r[15:5], ccr_b};
// (sp_sel: a flip-flop written beside sr_r, so the sequencer's choice of
// A7 does not start from S and M through their fan-out -- that began the
// uop's base register into the register file's read address at 60 MHz)
function automatic logic [4:0] sp_of(input logic [15:0] s);
	sp_of = !s[13] ? R_USP : s[12] ? R_MSP : R_ISP;
endfunction
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && sp_sel != sp_of(sr_r)) begin
		$display("FAIL: sp_sel %0d, the SR's %0d", sp_sel, sp_of(sr_r));
		$finish;
	end
// synthesis translate_on
assign dtt0 = dtt0_r;
assign dtt1 = dtt1_r;
assign itt0 = itt0_r;
assign itt1 = itt1_r;
assign tc   = tc_r;
assign urp  = urp_r;
assign srp  = srp_r;
assign vbr  = vbr_r;
assign cacr = cacr_r;
assign sfc  = sfc_r;
assign dfc  = dfc_r;

//--------------------------------------------------------------------------
// stall / advance (bubbles collapse: a stage moves into an empty one)
//--------------------------------------------------------------------------
logic wb_hold, ex_hold, dc2_hold, ag_hold;
logic dbf_hold;
logic stall_wb, stall_ex, stall_dc2, stall_dc1, stall_ag;

// EX holds for a multicycle unit; DC2 for memory; WB for stores/serial ops
logic md_busy;                // multiply/divide running (register)
logic ex_md_start;
// DC2 holds until the data memory unit has its result
assign dc2_hold  = dc2_v && (((dc2_u.mem != M_NONE) && (dc2_u.exc == 8'd0)) || (dc2_s.v && dc2_s.ld)) && !dm_dc2_rdy;
assign stall_wb  = wb_v  && wb_hold;
assign stall_ex  = ex_v  && (ex_hold  || stall_wb);
assign stall_dc2 = dc2_v && (dc2_hold || stall_ex);
assign stall_dc1 = dc1_v && (stall_dc2 || dm_hold1);
assign stall_ag  = ag_v  && (ag_hold  || stall_dc1);

assign adv_wb  = wb_v  && !stall_wb;
assign adv_ex  = ex_v  && !stall_ex;
assign adv_dc2 = dc2_v && !stall_dc2;
assign adv_dc1 = dc1_v && !stall_dc1;
assign hold_dc1 = stall_dc1;
assign adv_ag  = ag_v  && !stall_ag;

// AG's input: a skid register in front of it, so the sequencer's pop does
// not wait for the stall chain.  The sequencer may pop whenever the skid is
// empty; a uop it pops that AG cannot take waits in the skid, and AG takes
// the skid's first.  The register file is read, and the forwarding formed,
// for the uop entering AG (ain_u), wherever it comes from.
logic        sk_v;
// (a copy of sk_v for the register file's read addresses alone: sk_v
// selects the whole uop, and its fan-out would delay the reads)
(* preserve *) logic sk_vr;
uop_t        sk_u;
s1_t         sk_s;
wire         ain_v = sk_v || in_v;
uop_t        ain_u;
s1_t         ain_s;
assign ain_u   = sk_v ? sk_u : in_u;
assign ain_s   = sk_v ? sk_s : in_s;
// (without the skid the sequencer's pop waits for AG: the stall chain)
assign in_rdy  = (SKID ? !sk_v : !stall_ag) && !flush && !stopped && !eredir_pend && !exc_pend;
// (with the skid, AG's registered read addresses assume the pop from the
// skid alone: in a clock the flush, STOP, a pending early redirect or a
// pending exception entry holds the pop, the sequencer's FIFO is empty or
// AG takes nothing before the FIFO is cleared, so the assumed address is
// never used -- the pop's other conditions, from WB's and the exception
// entry's state, ran through the sequencer's head into the register
// file's address at 60/66 MHz; the sim check below holds the addresses to
// every uop AG takes)
assign in_rdy_a = SKID ? !sk_v : in_rdy;
// (the back-file writes of the routine's operands take several cycles
// after the flush: the sequencer must not issue from the old stream, which
// the fetch queue still holds, before exc_go)
// (from its own flip-flop: the zero test of xw_ph, with its fan-out, began
// the sequencer's step, emit and uq0 load -- into the register file's read
// address -- at 60 MHz)
assign exc_pend = xw_pend;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && xw_pend != (xw_ph != 3'd0)) begin
		$display("FAIL: xw_pend %b, xw_ph %0d", xw_pend, xw_ph);
		$finish;
	end
// synthesis translate_on
wire         ag_take = !stall_ag && !stopped && !halted;   // AG loads ain_u

//--------------------------------------------------------------------------
// AG
//--------------------------------------------------------------------------
// interlock: base, index and update registers must not have an older
// writer in DC1/DC2/EX (their value only exists after EX)
// (the second slots' writers count as well)
function automatic logic pend_w(input logic [4:0] r);
	pend_w = (dc1_v && dc1_u.d_v && dc1_u.d_reg == r) ||
	         (dc2_v && dc2_u.d_v && dc2_u.d_reg == r) ||
	         (ex_v  && ex_u.d_v  && ex_u.d_reg  == r) ||
	         (dc1_v && dc1_s.v && dc1_s.d_v && dc1_s.d_reg == r) ||
	         (dc2_v && dc2_s.v && dc2_s.d_v && dc2_s.d_reg == r) ||
	         (ex_v  && ex_s.v  && ex_s.d_v  && ex_s.d_reg  == r);
endfunction

// a plain load leaving DC2 hands its data to a base or index waiting in
// AG (cap_b/cap_x: the EX-stage writer is then no longer waited for)
logic cap_b, cap_x;
function automatic logic pend_dc(input logic [4:0] r);
	pend_dc = (dc1_v && dc1_u.d_v && dc1_u.d_reg == r) ||
	          (dc2_v && dc2_u.d_v && dc2_u.d_reg == r) ||
	          (dc1_v && dc1_s.v && dc1_s.d_v && dc1_s.d_reg == r) ||
	          (dc2_v && dc2_s.v && dc2_s.d_v && dc2_s.d_reg == r);
endfunction
wire ex_wr_b = ex_v && ex_u.d_v && ex_u.d_reg == ag_u.base;
wire ex_wr_x = ex_v && ex_u.d_v && ex_u.d_reg == ag_u.idx;
// (a second slot in EX: no load hand-over, AG waits for its write)
wire ex1_wr_b = ex_v && ex_s.v && ex_s.d_v && ex_s.d_reg == ag_u.base;
wire ex1_wr_x = ex_v && ex_s.v && ex_s.d_v && ex_s.d_reg == ag_u.idx;
// the youngest older writer of a register, and whether it is early:
// {found, early, stage (1 DC1, 2 DC2, 3 EX)}
// (a second slot is the younger of its stage, and never early)
function automatic logic [3:0] yw(input logic [4:0] r);
	if (dc1_v && dc1_s.v && dc1_s.d_v && dc1_s.d_reg == r) yw = {1'b1, 1'b0, 2'd1};
	else if (dc1_v && dc1_u.d_v && dc1_u.d_reg == r)  yw = {1'b1, dc1_ee, 2'd1};
	else if (dc2_v && dc2_s.v && dc2_s.d_v && dc2_s.d_reg == r) yw = {1'b1, 1'b0, 2'd2};
	else if (dc2_v && dc2_u.d_v && dc2_u.d_reg == r) yw = {1'b1, dc2_ee, 2'd2};
	else if (ex_v && ex_s.v && ex_s.d_v && ex_s.d_reg == r) yw = {1'b1, 1'b0, 2'd3};
	else if (ex_v && ex_u.d_v && ex_u.d_reg == r)    yw = {1'b1, ex_ee,  2'd3};
	else                                             yw = 4'd0;
endfunction
function automatic logic [31:0] ywv(input logic [1:0] st);
	ywv = (st == 2'd1) ? dc1_er : (st == 2'd2) ? dc2_er : ex_er;
endfunction
wire [3:0] yw_b = yw(ag_u.base);
wire [3:0] yw_x = yw(ag_u.idx);
// an early youngest writer: AG waits only until its result is loaded
// EX's result reaches AG's base/index a cycle after it is written, from a
// register (exq_*): stale_b/x mark a base/index loaded before that write
// (it entered AG as EX wrote it, or its writer left EX while AG waited);
// AG waits that cycle and reloads it from exq_val
logic        stale_b, stale_x;
logic [31:0] exq_val;
logic        stale_b1, stale_x1;      // ... by the second slot's write (exq1_val)
logic [31:0] exq1_val;
// An index that is AG's own second update of the uop leaving AG (upd2: the
// register-file read of its register, the adder, then the scale, into
// agx_q in one clock -- a 60/66 MHz path; rare: CMPM-style (Ay)+,(Ax)+ and
// then that register as an index) is loaded the clock after, from the
// update registered (ag2_v), while AG waits.  The base, which follows such
// an update in every copy loop, keeps the direct bypass.
logic        ag2_x;
logic [31:0] ag2_v;
// The writes' interlock (pend_w for AG's updates and the second slot's
// address-register form) in two parts: the older writers in DC1 and DC2
// registered a clock ahead (pw_q) -- a writer there now was in AG, DC1 or
// DC2 a clock ago, and in a clock moves at most a stage, so it is still
// waited for -- and EX's, which can leave, at once.  The compares of AG's
// registers against six stages' destinations, ORed, began the stall cone
// at 60 MHz (into the register files' read addresses and the front file's
// writes).  A simulation check holds each term to pend_w.
function automatic logic ex_w(input logic [4:0] r);
	ex_w = (ex_v && ex_u.d_v && ex_u.d_reg == r) ||
	       (ex_v && ex_s.v && ex_s.d_v && ex_s.d_reg == r);
endfunction
// the writers that will be in DC1 and DC2 after a clock: AG's (when it
// moves on, as it does when AG takes the next) and DC1's and DC2's
function automatic logic pend_ag(input logic [4:0] r);
	pend_ag = (ag_v && ag_u.d_v && ag_u.d_reg == r) ||
	          (ag_v && ag_s.v && ag_s.d_v && ag_s.d_reg == r) || pend_dc(r);
endfunction
logic [2:0] pw_q;                // AG's upd, upd2 and second-slot writes' DC1/DC2 waits
wire  [2:0] pw_new = {DUAL && ain_s.v && ain_s.agop && (pend_ag(ain_s.a_reg) || pend_ag(ain_s.d_reg)),
                      ain_u.upd2_v && pend_ag(ain_u.upd2_reg),
                      ain_u.upd_v  && pend_ag(ain_u.upd_reg)};
wire  [2:0] pw_hold = {ag_s.v && ag_s.agop && (pend_dc(ag_s.a_reg) || pend_dc(ag_s.d_reg)),
                       ag_u.upd2_v && pend_dc(ag_u.upd2_reg),
                       ag_u.upd_v  && pend_dc(ag_u.upd_reg)};
always_ff @(posedge clk)
	pw_q <= !nreset ? 3'd0 : (ag_take && ain_v && !flush) ? pw_new : pw_hold;
wire  [2:0] pw_t = {pw_q[2] || (ag_s.v && ag_s.agop && (ex_w(ag_s.a_reg) || ex_w(ag_s.d_reg))),
                    pw_q[1] || (ag_u.upd2_v && ex_w(ag_u.upd2_reg)),
                    pw_q[0] || (ag_u.upd_v  && ex_w(ag_u.upd_reg))};
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ag_v && pw_t != {ag_s.v && ag_s.agop && (pend_w(ag_s.a_reg) || pend_w(ag_s.d_reg)),
	                               ag_u.upd2_v && pend_w(ag_u.upd2_reg),
	                               ag_u.upd_v  && pend_w(ag_u.upd_reg)}) begin
		$display("FAIL: AG's write interlock %b by the registered waits %b, by the stages %b%b%b", pw_t, pw_q,
		         ag_s.v && ag_s.agop && (pend_w(ag_s.a_reg) || pend_w(ag_s.d_reg)),
		         ag_u.upd2_v && pend_w(ag_u.upd2_reg), ag_u.upd_v && pend_w(ag_u.upd_reg));
		$finish;
	end
// synthesis translate_on
wire ag_interlock = ag_v && (
	(ag_u.idx_v && ag2_x) ||
	(ag_u.base_v && (yw_b[2] ? !erb : (pend_dc(ag_u.base) || (ex_wr_b && !cap_b) || ex1_wr_b || stale_b))) ||
	(ag_u.idx_v  && (yw_x[2] ? !erx : (pend_dc(ag_u.idx)  || (ex_wr_x && !cap_x) || ex1_wr_x || stale_x))) ||
	// a register AG writes waits for every older writer (else the EX write
	// of the captured load could land after this one)
	pw_t[0] || pw_t[1] ||
	// the second slot's address-register form: its source final, and no
	// older writer of its destination
	pw_t[2] ||
	// AG's second update and a second slot's AG write share their
	// front-file port with a second slot's EX write (the older one first)
	((ag_u.upd2_v || (ag_s.v && ag_s.agop)) && ex_v && ex_s.v && ex_s.d_v));

// the load whose data can be handed over: its result is the data itself
// (a long MOVE, MOVEA.W sign-extended, a memory-indirect pointer)
// dc2_capd selects the data; it is marked captured only as the load moves
// to EX (adv_dc2): AG is interlocked while such a load is in DC2 (pend_dc),
// so a value taken before the load advances -- not final yet, perhaps -- is
// replaced when it does; the advance, the end of the stall chain, stays off
// the data multiplexers
wire        dc2_capd = dc2_u.d_v && dc2_u.op == OP_MOV && dc2_u.cond == 4'd0 &&
                       dc2_u.mem == M_LD && dc2_u.a_src == OS_MEM && dc2_u.sz == SZ_L &&
                       dc2_u.exc == 8'd0 && dm_ldata_alv && dc2_v;
// (from the DMU's aligned word, not its general byte gather: a short path;
// a misaligned load reaches AG a cycle later, through EX's write)
wire [31:0] dc2_capv = dc2_u.a_sxw ? {{16{dm_ldata_al[15]}}, dm_ldata_al[15:0]} : dm_ldata_al;
// (as AG's index, in one select: a word index and MOVEA.W's extension both
// take the low word's sign -- through dc2_capv and then ixf's word form the
// load's data reached agx_q a select later, a 60 MHz path)
wire [31:0] dc2_capx = (ag_u.idx_l && !dc2_u.a_sxw) ? dm_ldata_al
                                                    : {{16{dm_ldata_al[15]}}, dm_ldata_al[15:0]};
wire [31:0] dc2_capxs = ag_u.idx_v ? (dc2_capx << ag_u.scale) : 32'd0;
// ... the same for the uop entering AG
wire [31:0] dc2_capxi = !ain_u.idx_v ? 32'd0 :
                        (((ain_u.idx_l && !dc2_u.a_sxw) ? dm_ldata_al
                                                        : {{16{dm_ldata_al[15]}}, dm_ldata_al[15:0]}) << ain_u.scale);

assign ag_hold = ag_interlock;

// (DUAL: a sixth read port, the second slot's A; its B reads port 2, the
// upd2 register's, which the uop beside it does not use; the front file's
// port 1 also takes the second slot's EX write, the back file has a third
// port for its WB write)
ap68040_rf #(.NR(NRF)) rff (.clk(clk), .we(fwe), .wa(fwa), .wd(fwd), .ra(rfa[0:NRF-1]), .rd(frd[0:NRF-1]));
ap68040_rf #(.NR(NRF), .NW(DUAL ? 3 : 2)) rfb (.clk(clk), .we(bwe), .wa(bwa), .wd(bwd), .ra(rfa[0:NRF-1]), .rd(brd[0:NRF-1]));
// AG's base and index are read as the uop enters AG (ports 0/1 address
// the incoming uop) and kept in registers, so AG's address adders, and the
// data cache's set index after them, start from flip-flops
// (registered a cycle ahead: the skid's next copy if it will hold a uop,
// else the sequencer's next head; the select between the skid and the
// head, with its fan-out to every register's read, began the register
// read into agx_q/agb_q, a 60/66 MHz path.  The skid's next uop, when it
// holds one, is the one entering AG now.)
logic [4:0] rra0_q, rra1_q;
// (the read addresses without the take: ports 0/1 read the next head's
// registers (in_nb, in_nx) every clock and, with the skid, PH0/PH1 the
// held uop's -- the skid's or the head's -- and rsel_q, the take's
// complement registered, picks the data.  The take, the end of the stall
// chain from WB's store answer, was the select of every bank's registered
// read address, a 60 MHz path; now it ends at one flip-flop.)
logic [4:0] rrh0_q, rrh1_q;
logic       rsel_q;
// (whether the skid holds a uop next clock, without the flush and the
// kill: after either, the flush holds AG for a clock, so an address formed
// in the kill's clock is never used -- kill_now, from WB, was a 60/66 MHz
// path into these addresses)
wire sk_vn = sk_v ? !ag_take : (SKID && in_v && in_rdy_a && !ag_take);
// (AG's take selects last: the skid holds nothing after a take, and
// without one it holds what it has or the head that would enter it --
// the take, from the stall cone, ended two selects from the read address)
wire sk_vh = sk_v || (SKID && in_v && in_rdy_a);
always_ff @(posedge clk) begin
	rra0_q <= in_nb;
	rra1_q <= in_nx;
	rrh0_q <= sk_vr ? sk_u.base : in_u.base;
	rrh1_q <= sk_vr ? sk_u.idx  : in_u.idx;
	rsel_q <= SKID && !ag_take && sk_vh;
end
// synthesis translate_off
logic [4:0] sim_rra0, sim_rra1;   // the single registered addresses, as they were
logic       sim_rra_v;
always_ff @(posedge clk) begin
	sim_rra_v <= nreset;
	sim_rra0 <= ag_take ? in_nb : sk_vh ? (sk_vr ? sk_u.base : in_u.base) : in_nb;
	sim_rra1 <= ag_take ? in_nx : sk_vh ? (sk_vr ? sk_u.idx  : in_u.idx)  : in_nx;
	if (nreset && sim_rra_v && ((rsel_q ? rrh0_q : rra0_q) != sim_rra0 || (rsel_q ? rrh1_q : rra1_q) != sim_rra1)) begin
		$display("FAIL: AG's read addresses by the registered take %0d/%0d, the selected ones %0d/%0d",
		         rsel_q ? rrh0_q : rra0_q, rsel_q ? rrh1_q : rra1_q, sim_rra0, sim_rra1);
		$finish;
	end
end
// synthesis translate_on
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && sk_vn != (!ag_take && sk_vh)) begin
		$display("FAIL: the skid's next valid %b, by the take %b", sk_vn, !ag_take && sk_vh);
		$finish;
	end
// synthesis translate_on
assign rra[0] = rra0_q;   // (= ain_u's)
assign rra[1] = rra1_q;
// synthesis translate_off
logic sim_rra_ok;
always_ff @(posedge clk) begin
	sim_rra_ok <= nreset;
	if (nreset && sim_rra_ok && !flush && !stall_ag && ain_v && !stopped &&
	    ((ain_u.base_v && (rsel_q ? rrh0_q : rra0_q) != ain_u.base) ||
	     (ain_u.idx_v && (rsel_q ? rrh1_q : rra1_q) != ain_u.idx))) begin
		$display("FAIL: AG's registered read addresses %0d/%0d, the incoming uop's %0d/%0d",
		         rsel_q ? rrh0_q : rra0_q, rsel_q ? rrh1_q : rra1_q, ain_u.base, ain_u.idx);
		$finish;
	end
end
// synthesis translate_on
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && wb_commit && wb_dwe && wb_u.upd2_v) begin
		$display("FAIL: a uop with both a register result and upd2 (pc %h): the back file has two write ports", wb_u.pc);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && sk_vr != sk_v) begin
		$display("FAIL: the skid's copy sk_vr %b differs from sk_v %b", sk_vr, sk_v);
		$finish;
	end
// synthesis translate_on
// (port 2's address registered as the pair enters AG: the select by the
// second slot's valid was the first hop of the path through the register
// read, upd2's adder and its front-file write)
logic [4:0] rra2_q;
assign rra[2] = rra2_q;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ag_v && rra2_q != ((DUAL && ag_s.v) ? ag_s.b_reg : ag_u.upd2_reg)) begin
		$display("FAIL: AG's port 2 address %0d, the pair's %0d", rra2_q, (DUAL && ag_s.v) ? ag_s.b_reg : ag_u.upd2_reg);
		$finish;
	end
// synthesis translate_on
// (ports 3/4 addressed by copies of AG's A and B registers, kept apart:
// ag_u's fields fan out to every compare of EX's broadcast and the
// operand selects, and from them into the files' read addresses was the
// start of a 60 MHz path through the read, the broadcast and DC1's B)
(* preserve *) logic [4:0] ag_ra_q, ag_rb_q;
assign rra[3] = ag_ra_q;
assign rra[4] = ag_rb_q;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ag_v && (ag_ra_q != ag_u.a_reg || ag_rb_q != ag_u.b_reg)) begin
		$display("FAIL: AG's read address copies %0d/%0d, the uop's %0d/%0d",
		         ag_ra_q, ag_rb_q, ag_u.a_reg, ag_u.b_reg);
		$finish;
	end
// synthesis translate_on
assign rra[5] = ain_s.a_reg;      // (read as the pair enters AG: ag_a1q)
always_comb begin
	for (int i = 0; i < 8; i++) rfa[i] = 5'd0;
	for (int i = 0; i < NRP; i++) rfa[i] = rra[i];
	if (SKID) begin rfa[PH0] = rrh0_q; rfa[PH1] = rrh1_q; end
	for (int i = 0; i < NRP; i++) rrd[i] = fv[rra[i]] ? frd[i] : brd[i];
	// (ports 0/1: the next head's read, or the held uop's by the
	// registered take)
	if (SKID && rsel_q) begin
		rrd[0] = fv[rrh0_q] ? frd[PH0] : brd[PH0];
		rrd[1] = fv[rrh1_q] ? frd[PH1] : brd[PH1];
	end
	if (!DUAL) rrd[5] = '0;
end

logic [31:0] agb_q, agx_q;     // the base, and the index sign-extended and scaled
wire  [31:0] ag_base = agb_q;
wire  [31:0] ag_ix   = agx_q;
function automatic logic [31:0] ixf(input logic [31:0] v, input uop_t u);
	ixf = u.idx_v ? ((u.idx_l ? v : {{16{v[15]}}, v[15:0]}) << u.scale) : 32'd0;
endfunction
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && dc2_capd && (dc2_capxs !== ixf(dc2_capv, ag_u) || dc2_capxi !== ixf(dc2_capv, ain_u))) begin
		$display("FAIL: the captured load as AG's index %h %h, by the two selects %h %h",
		         dc2_capxs, dc2_capxi, ixf(dc2_capv, ag_u), ixf(dc2_capv, ain_u));
		$finish;
	end
// synthesis translate_on
wire [31:0] ag_ea   = ag_base + ag_ix + ag_u.disp;
wire [31:0] ag_pinc = ag_base + {{24{ag_u.upd_amt[7]}}, ag_u.upd_amt};
wire [31:0] ag_updv = ag_u.pinc ? ag_pinc : ag_ea;
wire [31:0] ag_u2v  = rrd[2] + {{24{ag_u.upd2_amt[7]}}, ag_u.upd2_amt};
// bit field memory transfers sized by the field (see ucode.py _bf_mem_load)
wire        ag_bfh    = (ag_u.mem != M_NONE) && (ag_u.op == OP_MOV) && (ag_u.cond == 4'hE);
// (the tail's flag registered with the uop, and bf_nb's 3 with bf_nb: the
// pair selects the displacement into the address adder, and the decode and
// the compare in front of it were a 60 MHz path to DC1's lookup)
function automatic logic bft_of(input uop_t u);
	bft_of = (u.mem != M_NONE) && (u.op == OP_MOV) && (u.cond == 4'hD);
endfunction
logic       ag_bft_q;
wire        ag_bft    = ag_bft_q;
wire        ag_rte7   = (ag_u.mem != M_NONE) && (ag_u.op == OP_MOV) && (ag_u.cond == 4'hB);
// FPU transfers cancelled by run-time state: FMOVEM slots, FSAVE and
// FRESTORE frame words (dyn; the FPU interface latched the state in EX
// before these uops' addresses could be formed)
function automatic logic dyncan_of(input uop_t u, input logic [7:0] mv, input logic [4:0] sw,
                                   input logic [4:0] rw);
	dyncan_of = (u.dyn == 3'd1 && !mv[u.dynk[2:0]]) || (u.dyn == 3'd2 && u.dynk >= sw) ||
	            (u.dyn == 3'd3 && u.dynk >= rw);
endfunction
// (registered: for the uop entering AG, or again for the one held, from
// the interface's state of the clock before -- which is set before these
// uops reach AG (checked): the frame size's decode and compare, through
// AG's front-file write and its bypass into agx_q, was a 60 MHz path)
logic       ag_dc_q;
wire        ag_dyncan = ag_dc_q;
always_ff @(posedge clk)
	ag_dc_q <= ag_take ? dyncan_of(ain_u, fp_mvslots, fp_svwords, fp_rswords)
	                   : dyncan_of(ag_u, fp_mvslots, fp_svwords, fp_rswords);
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ag_v && ag_dc_q != dyncan_of(ag_u, fp_mvslots, fp_svwords, fp_rswords)) begin
		$display("FAIL: AG's registered transfer cancel %b, the interface state's %b (pc %h dyn %0d dynk %0d)",
		         ag_dc_q, !ag_dc_q, ag_u.pc, ag_u.dyn, ag_u.dynk);
		$finish;
	end
// synthesis translate_on
wire        ag_cancel = (ag_bft && !(bf_nb == 3'd3 || bf_nb == 3'd5)) ||
                        (ag_rte7 && !rte_fmt7) || ag_dyncan;
// a continued MOVEM transfers from the stacked EA
logic       cm_hit_q;          // ag_u.pc == cm_pc, registered
wire        ag_cm     = cm_pend && cm_hit_q && (ag_u.mem != M_NONE) &&
                        (ag_u.op == OP_MOV) && (ag_u.cond == 4'hC);
wire  [1:0] ag_msz    = ag_bfh ? ((bf_nb == 3'd1) ? SZ_B : (bf_nb <= 3'd3) ? SZ_W : SZ_L)
                               : ag_u.msz;
// the memory address: the cases are folded into the adder's operands
// (their selects are registers), so nothing follows the sum on its way
// to the data cache's set index
wire [31:0] ag_mbase  = ag_cm ? cm_ea : ag_base;
wire [31:0] ag_mix    = ag_cm ? 32'd0 : ag_ix;
wire [31:0] ag_mdisp  = ag_cm ? ag_u.target :
                        (ag_bft && bf_nb3) ? ag_u.disp - 32'd2 : ag_u.disp;
wire [31:0] ag_maddr  = ag_mbase + ag_mix + ag_mdisp;

// operand read with the EX broadcast of this cycle (see the snoop below)
logic        exw_v;           // EX writes the front file this cycle
logic        exw_fw;          // ... as the younger uops' operands see it (no exception decision)
logic        fp_fin_q, fp_dk_q;   // an FPU uop with a register result: done, its suppression (exw_fw)
logic  [4:0] exw_reg;
logic [31:0] exw_val;

// the second slot's EX write and its broadcast (it has no exception: the
// uop beside it taking one flushes every uop that captured it)
logic        exw1_v;
logic        exw1_fw;         // ... as the younger uops' operands see it (see exw_fw)
logic  [4:0] exw1_reg;
logic [31:0] exw1_val;
// a register operand's value with this cycle's EX writes: e0 the first
// slot's (of the given form), and the second slot's (never both: the two
// write different registers)
function automatic logic [31:0] bcast(input logic e0, input logic [4:0] r, input logic [31:0] v);
	bcast = (e0 && exw_reg == r) ? exw_val : (exw1_fw && exw1_reg == r) ? exw1_val : v;
endfunction

function automatic logic [31:0] opnd(input logic [1:0] src, input logic [4:0] r,
                                     input logic [31:0] rv,
                                     input logic [31:0] imm, input logic sxw);
	logic [31:0] v;
	case (src)
		OS_REG:  v = bcast(exw_fw, r, rv);   // (AG's: flushed with an excepting EX)
		OS_IMM:  v = imm;
		default: v = 32'd0;
	endcase
	opnd = v;
endfunction

wire [31:0] ag_a = ag_u.a_upd ? ag_updv : opnd(ag_u.a_src, ag_u.a_reg, rrd[3], ag_u.imm, ag_u.a_sxw);
wire [31:0] ag_immb = {{15{ag_u.imm_b[16]}}, ag_u.imm_b};   // the B immediate extended
wire [31:0] ag_b = ag_u.b_upd ? ag_updv : opnd(ag_u.b_src, ag_u.b_reg, rrd[4], ag_immb, 1'b0);
// the second slot's operands: A read as the pair enters AG (ag_a1q,
// following EX's writes while it waits), B in AG as the first slot's
logic [31:0] ag_a1q;
// (the held and the taken values formed apart, kept: synthesis shared the
// register compare of EX's broadcast between them, the stall choosing the
// register in front of the compare and the 32-bit select, a 60 MHz path;
// the stall selects last, below)
(* keep *) wire [31:0] ag_a1h, ag_a1t;
wire [31:0] ag_a1 = ag_s.a_imm ? {{24{ag_s.imm[7]}}, ag_s.imm} :
                    ag_s.a_v ? ag_a1q : 32'd0;
wire [31:0] ag_b1 = ag_s.b_v ? bcast(exw_fw, ag_s.b_reg, rrd[2]) : 32'd0;
// an address-register form: its value (written to the front file through
// port 1 as the pair leaves AG; it waits for every older writer of its
// source and of its destination)
wire [31:0] ag1_val = (ag_s.sxw ? {{16{ag_a1q[15]}}, ag_a1q[15:0]} : ag_a1q) +
                      {{24{ag_s.imm[7]}}, ag_s.imm};
wire        ag1w_ag = DUAL && ag_v && ag_s.v && ag_s.agop;     // without the advance
wire        ag1w    = ag1w_ag && adv_ag;
// ag_a1q's two values (declared with it): held, EX's writes laid over it;
// taken, the pair's read with this cycle's AG and EX writes laid over it
function automatic logic [31:0] a1t_of(input logic [4:0] r, input logic [31:0] rd);
	logic [31:0] v;
	v = rd;
	if (fwe_ag[0] && ag_u.upd_reg == r)  v = ag_updv;
	if (fwe_ag[1] && ag_u.upd2_reg == r) v = ag_u2v;
	if (ag1w_ag && ag_s.d_reg == r)      v = ag1_val;
	a1t_of = bcast(exw_fw, r, v);
endfunction
assign ag_a1h = bcast(exw_fw, ag_s.a_reg, ag_a1q);
assign ag_a1t = a1t_of(ain_s.a_reg, rrd[5]);

// AG's early result: MOVE, ADD, SUB, AND, OR, EOR and LSL/ASL by an
// immediate count, from register or immediate operands whose values are
// known here (no older writer still to produce one, or an early one).
// The same function as EX (ap68040_alu, ap68040_alu_slow): checked in
// simulation against what EX writes.
function automatic logic e_op(input uop_t u);
	e_op = u.d_v && (u.mem == M_NONE) && (u.br == BR_NONE) && (u.exc == 8'd0) &&
	       (u.cond == 4'd0) && !u.a_sxw && !u.a_upd && !u.b_upd && !u.upd_v &&
	       !u.upd2_v && (u.dyn == 3'd0) && !u.ser &&
	       (u.a_src != OS_MEM) && (u.b_src != OS_MEM) &&
	       ((u.op == OP_MOV) || (u.op == OP_ADD) || (u.op == OP_SUB) ||
	        (u.op == OP_AND) || (u.op == OP_OR) || (u.op == OP_EOR) ||
	        (((u.op == OP_LSL) || (u.op == OP_ASL)) && (u.a_src == OS_IMM) &&
	         (u.imm[31:4] == 28'd0) && (u.imm[3:0] <= 4'd8)));
endfunction
logic        ea_ok, eb_ok, ag_ee;
logic [31:0] ea_v, eb_v, ag_er;
always_comb begin
	logic [3:0]  w;
	logic [31:0] m, r;
	// (the register file read, not EX's broadcast of this cycle: a
	// writer still in EX that is not early leaves the operand unknown)
	ea_v  = (ag_u.a_src == OS_REG) ? rrd[3] : (ag_u.a_src == OS_IMM) ? ag_u.imm : 32'd0;
	ea_ok = 1'b1;
	if (ag_u.a_src == OS_REG) begin
		w = yw(ag_u.a_reg);
		if (w[3]) begin
			if (w[2]) ea_v = ywv(w[1:0]);
			else ea_ok = 1'b0;
		end
	end
	eb_v  = (ag_u.b_src == OS_REG) ? rrd[4] : (ag_u.b_src == OS_IMM) ? ag_immb : 32'd0;
	eb_ok = 1'b1;
	if (ag_u.b_src == OS_REG) begin
		w = yw(ag_u.b_reg);
		if (w[3]) begin
			if (w[2]) eb_v = ywv(w[1:0]);
			else eb_ok = 1'b0;
		end
	end
	ag_ee = EARLY_RES && ag_v && e_op(ag_u) && ea_ok && eb_ok;
	m  = (ag_u.sz == SZ_B) ? 32'h0000_00FF : (ag_u.sz == SZ_W) ? 32'h0000_FFFF : 32'hFFFF_FFFF;
	// (the size mask applies to the result only: the low bits of each of
	// these depend on the operands' low bits alone)
	case (ag_u.op)
		OP_MOV:  r = ea_v;
		OP_ADD:  r = eb_v + ea_v;
		OP_SUB:  r = eb_v - ea_v;
		OP_AND:  r = eb_v & ea_v;
		OP_OR:   r = eb_v | ea_v;
		OP_EOR:  r = eb_v ^ ea_v;
		default: r = eb_v << ea_v[3:0];               // LSL, ASL
	endcase
	ag_er = (r & m) | (eb_v & ~m);
end

// A snoop dropped instruction-cache data the front end may already have
// run ahead into (it predicts calls and returns, beyond the 68040's
// prefetch): the next instruction to reach AG is refetched, with it
// everything younger.  Instructions already past AG are in execution.
// An exception routine's uops are not instructions (their pc is 0): the
// refetch waits for the handler's first instruction, which the routine's
// final jump fetches afresh anyway.
logic snp_pend;
wire  ag_snref = snp_pend && ag_v && ag_u.first && !ag_u.exr;
always_ff @(posedge clk) begin
	if (!nreset || flush) snp_pend <= 1'b0;
	else if (sn_ihit) snp_pend <= 1'b1;
	else if (adv_ag && ag_snref) snp_pend <= 1'b0;
end

// memory request to the DMU, issued as the uop leaves AG
logic s_bit;
assign s_bit      = sr_r[13];
// (the second slot's load: the pair's access, at operand A, the uop beside
// it has none; its fields are AG's registers, ahead of the address)
wire ag_m1 = DUAL && ag_s.v && ag_s.ld;
assign dm_req     = adv_ag && (((ag_u.mem != M_NONE) && (ag_u.exc == 8'd0) && !ag_cancel) || ag_m1) && !ag_snref;
assign dm_va      = ag_m1 ? ag_a1q : ag_maddr;
assign dm_mem     = ag_m1 ? M_LD : ag_u.mem;
assign dm_msz     = ag_m1 ? ag_s.sz : ag_msz;
assign dm_lock    = ag_u.mlock && !ag_m1;
assign dm_locke   = ag_u.mlocke && !ag_m1;
// FC2 of the access selects the root and the supervisor checks: MOVES
// translates its SFC/DFC space (WinUAE: super = (sfc & 4) != 0)
assign dm_super   = dm_fc[2];
assign dm_older   = ex_v || wb_v;
assign dm_s1      = DUAL && dc2_v && dc2_s.v && dc2_s.ld;



// Bcc history: the counter counts disagreement with the static rule
// (saturating 0..3); trained as the branch leaves EX, written a cycle
// later unless that cycle flushes (the branch was on a wrong path: an
// older uop at WB redirected or trapped as it left EX)
wire        bht_agree = (ex_taken == ex_u.bst);
logic       bht_we_q;
always_ff @(posedge clk) begin
	bht_we_q <= nreset && adv_ex && ex_u.op == OP_BCC && ex_u.br == BR_COND;
	bht_wa   <= ex_u.pc[8:1];
	bht_dis  <= !bht_agree;
end
assign bht_we = bht_we_q && !flush;
// loop exits: every backward Bcc/DBcc, the same way
logic       lp_we_q;
always_ff @(posedge clk) begin
	lp_we_q <= nreset && adv_ex && ex_u.bst &&
	           ((ex_u.op == OP_BCC && ex_u.br == BR_COND) || ex_u.op == OP_DBCC);
	lp_wa   <= ex_u.pc[12:1];
	lp_tk   <= ex_taken;
	lp_mp   <= ex_mispred;
end
assign lp_we = lp_we_q && !flush;
assign dm_noalloc = (ag_u.mfc == MFC_SUP) && !ag_m1;
// A level-7 interrupt's handler fetch (the routine's last uop: the vector
// read, cond 15, a branch to the loaded address) reads past the data
// cache: a system's NMI monitor answers that read itself (the Amiga's
// HRTMon/Action Replay overlay), and a vector line cached by the level 4-6
// autovectors beside it would hide the override.  A dirty line is pushed.
logic exc_l7;   // the exception being taken is a level-7 interrupt
assign dm_pastc = exc_l7 && !ag_m1 && (ag_u.mfc == MFC_SUP) && (ag_u.mem == M_LD) &&
                  (ag_u.br == BR_A) && (ag_u.cond == 4'hF);
// acknowledge cycles (TT=3): 1 interrupt, 2 breakpoint
assign dm_ack     = ag_m1 ? 2'd0 : (ag_u.mfc == MFC_IACK) ? 2'd1 : (ag_u.mfc == MFC_BKPT) ? 2'd2 : 2'd0;
always_comb begin
	case (ag_m1 ? MFC_NORM : ag_u.mfc)
		MFC_SFC: dm_fc = sfc_r;
		MFC_DFC: dm_fc = dfc_r;
		MFC_SUP: dm_fc = 3'd5;
		MFC_IACK: dm_fc = 3'd7;
		default: dm_fc = (ag_u.mprog && !ag_m1) ? {s_bit, 2'b10} : {s_bit, 2'b01};
	endcase
end

//--------------------------------------------------------------------------
// EX
//--------------------------------------------------------------------------
// operand values entering EX: A or B may be the load data (whether, as
// flip-flops loaded with the uop: the source fields' compare, with its
// fan-out, began every path from EX's operands -- 60/66 MHz)
logic       ex_amem, ex_bmem;
wire [31:0] ex_av0 = ex_amem ? ex_ld : ex_a;
wire [31:0] ex_av  = ex_u.a_sxw ? {{16{ex_av0[15]}}, ex_av0[15:0]} : ex_av0;
wire [31:0] ex_bv  = ex_bmem ? ex_ld : ex_b;
// DBcc's counter test on both of B's sources, the source last: through
// ex_bv the select's fan-out and the compare began the taken decision,
// the mispredict and the front end's flush at 60 MHz
(* keep *) wire ex_bnz_l = (ex_ld[15:0] != 16'd0);
(* keep *) wire ex_bnz_r = (ex_b[15:0] != 16'd0);
wire        ex_bnz = ex_bmem ? ex_bnz_l : ex_bnz_r;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_bnz !== (ex_bv[15:0] != 16'd0)) begin
		$display("FAIL: be: DBcc's counter test by source %b, the operand's %b", ex_bnz, ex_bv[15:0] != 16'd0);
		$finish;
	end
// synthesis translate_on
// ... A and B for the slow unit, their selects made as the uop enters EX (ex_a, ex_b and ex_ld load nowhere else):
// ex_bmem's select and fan-out began the barrel shifter's path into xs_q,
// ex_av's the CHK2 compare's into its exception, at 60 MHz
logic [31:0] ex_as, ex_bs;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_amem != (ex_u.a_src == OS_MEM) || ex_bmem != (ex_u.b_src == OS_MEM))) begin
		$display("FAIL: EX's operand sources %b%b, the uop's %0d %0d", ex_amem, ex_bmem, ex_u.a_src, ex_u.b_src);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && ex_v && ((ex_slow && ex_as !== ex_av) || ex_bs !== ex_bv)) begin
		$display("FAIL: EX's registered slow A, B %h %h, the selected ones %h %h (pc %h)",
		         ex_as, ex_bs, ex_av, ex_bv, ex_u.pc);
		$finish;
	end
// synthesis translate_on

logic [31:0] alu_res;
logic  [4:0] alu_flags;
logic        alu_cc, alu_trap;

logic [RC_N-1:0] ex_rc_q;      // alu_rc(ex_u.op), registered with the uop
logic [31:0] alu_res_ref;

ap68040_alu alu (
	.op(ex_u.op), .rc(ex_rc_q), .sz(ex_u.sz), .cond(ex_u.cond),
	.a(ex_av), .b(ex_bv), .ea(ex_ea),
	.flags_in(ccr_f),
	.res(alu_res), .res_ref(alu_res_ref), .flags_out(alu_flags),
	.cc_true(alu_cc), .trap(alu_trap)
);
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_rc_q !== alu_rc(ex_u.op) || alu_res !== alu_res_ref)) begin
		$display("FAIL: EX's ALU result %h by class %h, by the op %h (op %0d)",
		         alu_res, ex_rc_q, alu_res_ref, ex_u.op);
		$finish;
	end
// synthesis translate_on

// multiply / divide
logic        md_done, md_ovf;
logic        md_ovf16;        // a divide's quotient does not fit 16 bits (or md_ovf)
logic [31:0] md_hi, md_lo;
logic [31:0] md_hiin;         // OP_MDHI latch (64-bit dividend high)
logic [31:0] md_rem;          // remainder / product high, for OP_MDRES
logic [31:0] md_lol;          // quotient / product low, for OP_MDRES
logic        md_ovfl;         // the last divide overflowed
logic        md_go;           // this EX uop has started the unit
logic        md_fin;          // ... and the unit has finished (done is a pulse: EX may
                              // be stalled by WB in that cycle)
logic        md_z;            // ... is a divide by zero (from its second cycle)
// EX's opcode classes, registered with ex_u when it loads (ex_u is written
// nowhere else), so the EX hold -- which every earlier stage's stall waits
// on -- reads flops instead of 7-bit opcode compares.  At 60/66 MHz the
// compare -> stall_ex -> stall_dc2 -> register-file write enable cone was
// the worst CPU-clock path.
logic        ex_md_q, ex_fp_q, ex_dbcc_q, ex_slow_q;
logic        ex_alu_q;        // EX's result is the ALU's (see exw_val)
logic        ex_slr_q;        // a slow op's result is the shifter's (see xs)
wire         ex_is_md   = ex_md_q;
wire         ex_div0    = (ex_u.op == OP_DIV) &&
                          ((ex_u.sz == SZ_W) ? (ex_av[15:0] == 16'd0) : (ex_av == 32'd0));
assign ex_md_start = ex_v && ex_is_md && !md_go && !ex_div0 && !md_busy && !ex_fault;

// word forms: DIVU.W/DIVS.W divide the 32-bit Dn by a 16-bit source;
// MULU.W/MULS.W multiply the low words
wire        md_sign = ex_u.cond[0];
wire [31:0] md_a    = (ex_u.sz == SZ_W) ?
                      (md_sign ? {{16{ex_av[15]}}, ex_av[15:0]} : {16'd0, ex_av[15:0]}) : ex_av;
wire [31:0] md_blo  = (ex_u.op == OP_MUL && ex_u.sz == SZ_W) ?
                      (md_sign ? {{16{ex_bv[15]}}, ex_bv[15:0]} : {16'd0, ex_bv[15:0]}) : ex_bv;
wire [31:0] md_bhi  = (ex_u.op == OP_DIV) ?
                      ((ex_u.cond[1]) ? md_hiin : (md_sign ? {32{ex_bv[31]}} : 32'd0)) : 32'd0;

ap68040_muldiv #(.DSTEPS(DIV_STEPS)) md (
	.clk(clk), .nreset(nreset), .kill(kill_now),
	.start(ex_md_start), .is_div(ex_u.op == OP_DIV), .sign_op(md_sign),
	.op_a(md_a), .op_hi(md_bhi), .op_lo(md_blo),
	.busy(md_busy), .done(md_done), .res_hi(md_hi), .res_lo(md_lo), .ovf(md_ovf),
	.ovf16(md_ovf16)
);

// FPU: OP_FPU uops act once no older uop is in flight (WB empty)
wire         ex_is_fp = ex_fp_q;
wire dc2_disp = adv_dc2 && (dc2_u.op == OP_FPU) && (dc2_u.cond == 4'd1) &&
                (dc2_u.pc == ex_u.pc) && (dc2_u.exc == 8'd0);

// (CHK's size-field flags, registered with the uop: the size compare
// began the unit's hold into EX's stall at 60 MHz)
logic ex_fuse_q, ex_eal_q;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_fuse_q != (ex_u.sz == SZ_W) || ex_eal_q != (ex_u.sz == SZ_B))) begin
		$display("FAIL: EX's FPU flags %b%b for the size %0d", ex_fuse_q, ex_eal_q, ex_u.sz);
		$finish;
	end
// synthesis translate_on
ap68040_fpif #(.FPU_REVISION(FPU_REVISION), .FPU_PIPE(FPU_PIPE)) fpif (
	.clk(clk), .nreset(nreset),
	.ex_v(ex_v && ex_is_fp && !ex_fault && ex_u.exc == 8'd0), .sub(ex_u.cond),
	.fuse(ex_fuse_q), .eal(ex_eal_q),
	.imm(ex_u.imm[7:0]), .immb(ex_u.imm_b[7:0]),
	.av(ex_av), .bv(ex_bv), .aw(ex_a[15:0]), .bw(ex_b[15:0]),
	.dw_a(dc2_a[15:0]), .dw_b(dc2_b[15:0]), .dw_ld(!stall_ex), .latch(ex_latch), .ea(ex_ea), .pc(ex_u.pc),
	.safe(!wb_v || wb_fpchk), .adv(adv_ex), .kill(kill_now), .dynk(ex_u.dynk[2:0]), .dc2_disp(dc2_disp),
	.hold(fp_hold), .res(fp_res), .dkill(fp_dkill), .taken(fp_taken),
	.xvec(fp_xvec), .xfmt(fp_xfmt), .xnext(fp_xnext), .xaddr(fp_xaddr),
	.xcommit(fp_xcommit), .st_kill(fp_stkill),
	.mv_slots(fp_mvslots), .cr_slots(fp_crslots),
	.sv_words(fp_svwords), .rs_words(fp_rswords),
	.get_w1(fp_get1), .get_w2(fp_get2)
);

// EX holds while the unit runs, until the cycle its result is presented
// (a divide by zero holds its first cycle too: the zero test of the
// operand stays off the stall path, and the exception goes a cycle later)
assign ex_hold = (ex_v && ex_is_fp && !ex_fault && ex_u.exc == 8'd0 && ex_u.d_v && !fp_fin_q) ||
                 (ex_v && ex_is_md && !md_z && !ex_fault && !md_done && !md_fin) ||
                 (ex_v && ex_slow && !ex_ph) ||
                 (ex_v && ex_is_fp && !ex_fault && ex_u.exc == 8'd0 && fp_hold) || dbf_hold;

// DBcc period floor (the dbcc_floor input): a taken DBcc leaving EX loads
// the counter with floor-1, and a DBcc in EX waits while it is nonzero, so
// consecutive DBccs leave EX (and retire: WB never holds one) at least
// dbcc_floor clocks apart.  The hold is keyed on the previous DBcc's real
// outcome, not on a prediction, and it commits nothing: Dn is written and
// the predictors trained on adv_ex only, and a flush clears ex_v.  Only a
// DBcc that follows a taken DBcc waits, so a loop's exit and a lone DBcc
// cost nothing extra.  Hosts calibrated on a real 68040's DBcc loops set
// the floor (NeXT: 9 clocks at 55 MHz for the ROM's 4 clocks at 25 MHz).
logic [3:0] dbf_cnt;
logic       dbf_nz;
assign dbf_hold = ex_v && ex_dbcc_q && dbf_nz;
always_ff @(posedge clk) begin
	if (!nreset) begin
		dbf_cnt <= 4'd0;
		dbf_nz  <= 1'b0;
	end
	else if (adv_ex && (ex_u.op == OP_DBCC) && ex_taken) begin
		dbf_cnt <= (dbcc_floor > 4'd1) ? dbcc_floor - 4'd1 : 4'd0;
		dbf_nz  <= (dbcc_floor > 4'd1);
	end
	else if (dbf_nz) begin
		dbf_cnt <= dbf_cnt - 4'd1;
		dbf_nz  <= (dbf_cnt != 4'd1);
	end
end

// multiply/divide result and flags
logic [31:0] md_res;
logic  [4:0] md_flags;
logic        md_dkill;
always_comb begin
	md_res   = ex_bv;
	md_flags = ccr_f;
	md_dkill = 1'b0;
	if (ex_u.op == OP_MUL) begin
		if (ex_u.sz == SZ_W || !ex_u.cond[1]) begin
			// 32-bit product (MULx.W is 16x16 -> 32)
			md_res   = md_lo;
			md_flags = {ccr_f[4], md_lo[31], md_lo == 32'd0,
			            (ex_u.sz == SZ_L) &&
			            (md_sign ? (md_hi != {32{md_lo[31]}}) : (md_hi != 32'd0)),
			            1'b0};
		end
		else begin
			// 64-bit: this uop writes Dl; OP_MDRES writes Dh
			md_res   = md_lo;
			md_flags = {ccr_f[4], md_hi[31], {md_hi, md_lo} == 64'd0, 1'b0, 1'b0};
		end
	end
	else begin
		// divide
		if (ex_u.sz == SZ_W) begin
			// quotient must fit 16 bits
			// (registered by the unit with the quotient: the test of md_lo
			// was on the way to EX's forwarding enable at 60 MHz)
			if (md_ovf16) begin
				md_dkill = 1'b1;
				md_flags = {ccr_f[4], ccr_f[3], ccr_f[2], 1'b1, 1'b0};
			end
			else begin
				md_res   = {md_hi[15:0], md_lo[15:0]};
				md_flags = {ccr_f[4], md_lo[15], md_lo[15:0] == 16'd0, 1'b0, 1'b0};
			end
		end
		else begin
			if (md_ovf) begin
				md_dkill = 1'b1;
				md_flags = {ccr_f[4], ccr_f[3], ccr_f[2], 1'b1, 1'b0};
			end
			else begin
				md_res   = md_lo;
				md_flags = {ccr_f[4], md_lo[31], md_lo == 32'd0, 1'b0, 1'b0};
			end
		end
	end
end

// (the result for EX's other written value, whose class says MUL or DIV
// already: the op compare there, and SZ_W's, began EX's forwarding into
// DC1's operands at 60 MHz.  The multiply's result is md_lo whatever its
// size; ex_fuse_q is ex_u.sz == SZ_W)
logic        ex_mul_q;
wire  [31:0] md_resx = ex_mul_q ? md_lo :
                       ex_fuse_q ? (md_ovf16 ? ex_bv : {md_hi[15:0], md_lo[15:0]}) :
                                   (md_ovf ? ex_bv : md_lo);

// (a divide's suppression for the kill terms below, ex_kc[1]: md_dkill's
// divide branch without the op decode -- ex_fuse_q is ex_u.sz == SZ_W --
// which put ex_u.op on the way into EX's forwarding enable at 60 MHz)
wire md_dkd = ex_fuse_q ? md_ovf16 : md_ovf;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_kc[1] && md_dkd != md_dkill) begin
		$display("FAIL: a divide's suppression %b, md_dkill %b", md_dkd, md_dkill);
		$finish;
	end
// synthesis translate_on

// latch for CAS / bit fields
logic [31:0] ex_latch;

//--------------------------------------------------------------------------
// bit field unit.  BFSET latched the offset (bf_off) and width (bf_w,
// 1..32).  Register form (cond[3] = 0): the field is in B, numbered from
// bit 31, wrapping.  Memory form: B is the long word at EA + offset/8 and
// ex_latch[7:0] the byte after it; the field starts offset & 7 bits in.
// A is the BFINS source.  Flags come from the field, for BFINS from the
// inserted value.
//--------------------------------------------------------------------------
logic [31:0] bf_off;
logic  [5:0] bf_w;
// derived from the width when BFSET latches it (off the EX paths): 32 - width,
// the field mask at the top, BFEXTS's sign mask
logic  [5:0] bf_wn;
logic [31:0] bf_top, bf_sx;
logic  [2:0] bf_nb;             // memory form: bytes holding the field (1..5)
logic        bf_nb3;            // ... is 3 (registered with it, for AG)

// MOVEM continuation (MC68040UM 8.4.6.5, SSW CM)
logic        rte_fmt7;          // the RTE's frame is format $7
logic        cm_n_v;            // ... and its SSW has CM set
logic [31:0] cm_n_ea;           // ... its EA
logic        cm_pend;           // the next instruction continues a MOVEM
logic [31:0] cm_ea, cm_pc;
logic [31:0] wb_mv_ea;          // the WB MOVEM transfer's calculated EA

// leading zero count of a nonzero 32-bit value, as a balanced tree
function automatic logic [4:0] clz32(input logic [31:0] v);
	logic [4:0] n;
	logic [31:0] x;
	x = v;
	n[4] = (x[31:16] == 16'd0); if (n[4]) x = {x[15:0], 16'd0};
	n[3] = (x[31:24] == 8'd0);  if (n[3]) x = {x[23:0], 8'd0};
	n[2] = (x[31:28] == 4'd0);  if (n[2]) x = {x[27:0], 4'd0};
	n[1] = (x[31:30] == 2'd0);  if (n[1]) x = {x[29:0], 2'd0};
	n[0] = !x[31];
	clz32 = n;
endfunction
logic  [7:0] bf_lonew;          // memory form: the new byte after the long
logic [31:0] bf_res;
logic  [7:0] bf_lo_out;
// BFINS takes a cycle more: its source left-aligned to the field width
// (ins_top) is registered first (bf_ins_q, in ex_pb's cycle), so the field
// merge starts from flip-flops -- three variable shifts in a row do not
// close at 60 MHz without register retiming
// Every bit field operation takes that cycle: the rotated operand is
// registered (bf_rot_q), and the extraction, flags and merge start from it
// (a rotate and a second variable shift in one cycle do not close at 65 MHz)
logic        ex_pb;
logic [31:0] bf_ins_q, bf_rot, bf_rot_q;
logic [31:0] bf_rr;             // the shared right rotator's output (below)
logic  [5:0] rox_nx, rox_nx_q;  // ROXL/ROXR: their count mod (size + 1), the same way
logic  [6:0] rox_nxl, rox_nxl_q; // ROXL: its funnel amount, the same way (from the registered count)
wire         ex_pre = (ex_u.op == OP_BF) || (ex_u.op == OP_ROXL) || (ex_u.op == OP_ROXR);
logic        ex_bfx;            // a bit field extract (cond 1, 3), loaded with ex_u
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_bfx != ((ex_u.cond[2:0] == 3'd1) || (ex_u.cond[2:0] == 3'd3))) begin
		$display("FAIL: EX's extract kind %b, by the condition %0d", ex_bfx, ex_u.cond);
		$finish;
	end
// synthesis translate_on
wire         ex_bfins = (ex_u.op == OP_BF) && (ex_u.cond[2:0] == 3'd7);
logic  [4:0] bf_flags;
logic [31:0] bf_hn, bf_hn_ref;  // the memory form's head bytes (below), and the old form
always_comb begin
	logic [4:0]  o;
	logic [31:0] top, rot, fld, ins_top, nrot, nrot_v, nreg, zf;
	logic [39:0] win, mask40, ins40, nwin;
	logic [5:0]  lz;
	logic        nflag, zflag;
	logic [2:0]  t;
	t   = ex_u.cond[2:0];
	top = bf_top;
	ins_top = bf_ins_q;
	if (!ex_u.cond[3]) begin
		o   = bf_off[4:0];
		// rotate left by o: a funnel of B with itself
		rot = 32'(({ex_bv, ex_bv} << o) >> 32);
		win = '0; mask40 = '0; ins40 = '0;
	end
	else begin
		o   = {2'b00, bf_off[2:0]};
		// the bytes read, left justified: B holds the head transfer (byte,
		// word or long), the latch the tail byte
		case (bf_nb)
			3'd1:    win = {ex_bv[7:0], 32'd0};
			3'd2:    win = {ex_bv[15:0], 24'd0};
			3'd3:    win = {ex_bv[15:0], ex_latch[7:0], 16'd0};
			3'd4:    win = {ex_bv, 8'd0};
			default: win = {ex_bv, ex_latch[7:0]};
		endcase
		rot = 32'((win << o) >> 8);
		mask40 = {top, 8'h00} >> o;
		ins40  = {ins_top, 8'h00} >> o;
	end
	bf_rot = rot;
	rot    = bf_rot_q;
	case (t)
		3'd2: nrot_v = rot ^ top;                     // BFCHG
		3'd4: nrot_v = rot & ~top;                    // BFCLR
		3'd6: nrot_v = rot | top;                     // BFSET
		default: nrot_v = (rot & ~top) | (ins_top & top);   // BFINS
	endcase
	// One right rotator for three shifts that never run in the same cycle:
	// the pre-cycle's BFINS source (ex_av << (32 - w): rotated right by w,
	// masked to the field's top bits), and in the main cycle the extracted
	// field (rot >> (32 - w): rotated right by 32 - w, masked to the low w
	// bits) or the register's merged value rotated back (nreg, by the offset)
	begin
		logic [31:0] ri;
		logic  [4:0] ra;
		logic        ext;
		// (BFEXTU/BFEXTS's kind registered with the uop, ex_bfx: the
		// compare of EX's condition field through this select and the
		// rotator into EX's result was a 60 MHz path into the next uop's A)
		ext = ex_bfx;
		ri  = !ex_pb ? ex_av : ext ? rot : nrot_v;
		ra  = !ex_pb ? bf_w[4:0] : ext ? bf_wn[4:0] : o;
		bf_rr = 32'({ri, ri} >> ra);
	end
	fld = bf_rr & ~bf_sx;
	nrot = nrot_v;
	nreg = bf_rr;
	case (t)
		3'd2: nwin = win ^ mask40;
		3'd4: nwin = win & ~mask40;
		3'd6: nwin = win | mask40;
		default: nwin = (win & ~mask40) | (ins40 & mask40);
	endcase
	// leading zeros of the field (FFO): a log-depth count over the top-
	// aligned field; a zero field gives the width
	zf = rot & top;
	lz = (zf == 32'd0) ? bf_w : {1'b0, clz32(zf)};
	if (t == 3'd7) begin
		nflag = ins_top[31];
		zflag = (ins_top & top) == 32'd0;
	end
	else begin
		nflag = rot[31];
		zflag = zf == 32'd0;
	end
	bf_flags = {ccr_f[4], nflag, zflag, 1'b0, 1'b0};
	// the bytes written back: the head right justified, the tail byte
	bf_lo_out = (bf_nb == 3'd3) ? nwin[23:16] : nwin[7:0];
	// (the head: B's bytes operated on with the mask's and the source's
	// at the same bytes -- they are where the window put B -- so bf_nb
	// selects registered values beside the operation instead of the
	// window before it and the head after, a 60 MHz path)
	begin
		logic [31:0] hm, hi, hb;
		case (bf_nb)
			3'd1:       begin hm = {24'd0, mask40[39:32]}; hi = {24'd0, ins40[39:32]}; hb = {24'd0, ex_bv[7:0]};  end
			3'd2, 3'd3: begin hm = {16'd0, mask40[39:24]}; hi = {16'd0, ins40[39:24]}; hb = {16'd0, ex_bv[15:0]}; end
			default:    begin hm = mask40[39:8];           hi = ins40[39:8];           hb = ex_bv;                end
		endcase
		case (t)
			3'd2: bf_hn = hb ^ hm;
			3'd4: bf_hn = hb & ~hm;
			3'd6: bf_hn = hb | hm;
			default: bf_hn = (hb & ~hm) | (hi & hm);
		endcase
	end
	bf_hn_ref = (bf_nb == 3'd1) ? {24'd0, nwin[39:32]} :
	            (bf_nb == 3'd2 || bf_nb == 3'd3) ? {16'd0, nwin[39:24]} :
	            nwin[39:8];
	case (t)
		3'd1: bf_res = fld;                                            // BFEXTU
		3'd3: bf_res = fld | (rot[31] ? bf_sx : 32'd0);                  // BFEXTS
		3'd5: bf_res = bf_off + {26'd0, lz};                           // BFFFO
		3'd0: bf_res = ex_bv;                                          // BFTST
		default: bf_res = !ex_u.cond[3] ? nreg : bf_hn;
	endcase
end
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_u.op == OP_BF && ex_u.cond[3] && bf_hn !== bf_hn_ref) begin
		$display("FAIL: the bit field's head bytes %h, the window's %h (bytes %0d, op %0d)",
		         bf_hn, bf_hn_ref, bf_nb, ex_u.cond[2:0]);
		$finish;
	end
// synthesis translate_on


//--------------------------------------------------------------------------
// EX result selection
//--------------------------------------------------------------------------
logic [31:0] ex_res;
logic  [4:0] ex_flags;
logic        ex_dkill;        // suppress the register write
logic  [5:0] ex_kc;           // EX's uop is FPU, DIV, MDRES, DBcc, CHK2B, CAS2R (the ones that can)
logic        ex_dkill_chk;    // (simulation: the case form)
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_u.d_v && (!ex_slow || ex_ph) && ex_dkill != ex_dkill_chk) begin
		$display("FAIL: ex_dkill %b, the case form %b (op %0d, pc %h)", ex_dkill, ex_dkill_chk, ex_u.op, ex_u.pc);
		$finish;
	end
// synthesis translate_on
logic        ex_taken;        // control transfer taken
logic [31:0] ex_target;
logic  [7:0] ex_xvec;         // exception raised in EX
logic [31:0] ex_st;           // store data
logic        ex_sr_we;
logic [15:0] ex_sr_new;

// special register read: the MOVEC numbers as {ext[11], ext[3:0]}
// ($000-$007 -> $00-$07, $800-$807 -> $10-$17; USP, MSP and ISP live in
// the register file), then SR and CCR
function automatic logic [31:0] spr_read(input logic [7:0] n);
	case (n)
		8'h00: spr_read = {29'd0, sfc_r};
		8'h01: spr_read = {29'd0, dfc_r};
		8'h02: spr_read = cacr_r;
		8'h03: spr_read = tc_r;
		8'h04: spr_read = itt0_r;
		8'h05: spr_read = itt1_r;
		8'h06: spr_read = dtt0_r;
		8'h07: spr_read = dtt1_r;
		8'h11: spr_read = vbr_r;
		8'h15: spr_read = mmusr_r;
		8'h16: spr_read = urp_r;
		8'h17: spr_read = srp_r;
		8'h20: spr_read = {16'd0, sr_r[15:5], ccr_f};     // SR
		8'h21: spr_read = {27'd0, ccr_f};                   // CCR
		default: spr_read = 32'd0;
	endcase
endfunction

// slow (two-cycle) operations: computed in EX's first cycle, registered,
// used in the second, so their logic never reaches the result path
function automatic logic is_slow(input logic [6:0] op);
	case (op)
		OP_ASL, OP_ASR, OP_LSL, OP_LSR, OP_ROL, OP_ROR, OP_ROXL, OP_ROXR,
		OP_ABCD, OP_SBCD, OP_NBCD, OP_PACK, OP_UNPK, OP_BF, OP_CHK2B,
		OP_SPR, OP_SRLOG, OP_RTE, OP_RTEF, OP_IACKV, OP_MISC: is_slow = 1'b1;
		default: is_slow = 1'b0;
	endcase
endfunction

typedef struct packed {
	logic [31:0] res;
	logic  [4:0] flags;
	logic        dkill;
	logic        taken;
	logic [31:0] target;
	logic  [7:0] xvec;
	logic        sr_we;
	logic [15:0] sr_new;
} exo_t;

wire  ex_slow = ex_slow_q;
// shifts and rotates: N and Z are the result's sign and zero test at the
// size, taken in the second cycle from the registered result (the barrel
// shift and a 32-bit zero test do not fit one cycle with the count logic)
wire  ex_shift = (ex_u.op == OP_ASL) || (ex_u.op == OP_ASR) || (ex_u.op == OP_LSL) ||
                 (ex_u.op == OP_LSR) || (ex_u.op == OP_ROL) || (ex_u.op == OP_ROR) ||
                 (ex_u.op == OP_ROXL) || (ex_u.op == OP_ROXR);
logic ex_ph;                    // second cycle of a slow op
// the shift's kind for the slow unit, one-hot, registered with ex_u
function automatic logic [7:0] shk_of(input logic [6:0] o);
	shk_of = {o == OP_ROXR, o == OP_ROXL, o == OP_ROR, o == OP_ROL,
	          o == OP_LSR, o == OP_ASR, o == OP_LSL, o == OP_ASL};
endfunction
logic [7:0] ex_shk;
// the shifter funnel's input form, one-hot by kind and size: right shifts
// (and no shift) B/W/L, rotates, rotates through X, left shifts
function automatic logic [11:0] rvm_of(input logic [7:0] k, input logic [1:0] sz);
	logic [2:0] z;
	logic       ro, rx, sl;
	z  = (sz == SZ_B) ? 3'b001 : (sz == SZ_W) ? 3'b010 : 3'b100;
	ro = !k[2] && (k[4] || k[5]);
	rx = !k[2] && !ro && (k[6] || k[7]);
	sl = !k[2] && !ro && !rx && (k[0] || k[1]);
	rvm_of = {sl ? z : 3'b000, rx ? z : 3'b000, ro ? z : 3'b000,
	          (!ro && !rx && !sl) ? z : 3'b000};
endfunction
logic [11:0] ex_rvm;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_shk != shk_of(ex_u.op) || ex_rvm != rvm_of(ex_shk, ex_u.sz))) begin
		$display("FAIL: the registered shift kind %b, the op's %b", ex_shk, shk_of(ex_u.op));
		$finish;
	end
// synthesis translate_on
exo_t xf, xs, xs_q;

logic [31:0] sl_res;
logic  [4:0] sl_flags;
logic        sl_sim_c, sl_sim_asr, sl_sim_rv;
ap68040_alu_slow alu_s (
	.op(ex_u.op), .shk(ex_shk), .rvm(ex_rvm), .sz(ex_u.sz), .a(ex_as), .b(ex_bs), .cnt(ex_a[5:0]), .flags_in(ccr_f),
	.nx_q(rox_nx_q), .nx(rox_nx), .nxl_q(rox_nxl_q), .nxl(rox_nxl),
	.res(sl_res), .flags_out(sl_flags), .sim_c(sl_sim_c), .sim_asr_eq(sl_sim_asr), .sim_rv_eq(sl_sim_rv)
);
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_shift && (!ex_pre || ex_pb) && sl_flags[0] !== sl_sim_c) begin
		$display("FAIL: the shift's direct carry %b, the funnel's %b (op %0d, sz %0d, count %0d, b %h, pc %h)",
		         sl_flags[0], sl_sim_c, ex_u.op, ex_u.sz, ex_a[5:0], ex_bv, ex_u.pc);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && ex_v && ex_shift && sl_sim_rv !== 1'b1) begin
		$display("FAIL: the shift funnel's input by the registered form differs from the kind's (op %0d, sz %0d, pc %h)",
		         ex_u.op, ex_u.sz, ex_u.pc);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && ex_v && ex_shift && (!ex_pre || ex_pb) && sl_sim_asr !== 1'b1) begin
		$display("FAIL: ASR's sign after the shift differs from the sign-filled funnel's (sz %0d, count %0d, b %h)",
		         ex_u.sz, ex_a[5:0], ex_bv);
		$finish;
	end
// synthesis translate_on
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && wb_v && ew_same != (ex_u.pc == wb_u.pc)) begin
		$display("FAIL: ew_same %b, the EX and WB PCs %h %h", ew_same, ex_u.pc, wb_u.pc);
		$finish;
	end
// synthesis translate_on
// (the shift count is never a memory operand: a count register or a
// constant, so it comes straight from the operand register)
// synthesis translate_off
always_ff @(posedge clk)
	if (ex_v && ex_u.a_src == OS_MEM &&
	    (ex_u.op == OP_ASL || ex_u.op == OP_ASR || ex_u.op == OP_LSL || ex_u.op == OP_LSR ||
	     ex_u.op == OP_ROL || ex_u.op == OP_ROR || ex_u.op == OP_ROXL || ex_u.op == OP_ROXR)) begin
		$display("FAIL: a shift with its count from memory (pc %h)", ex_u.pc);
		$finish;
	end
// synthesis translate_on

// fast operations
always_comb begin
	xf.res    = alu_res;
	xf.flags  = alu_flags;
	xf.dkill  = 1'b0;
	xf.taken  = 1'b0;
	xf.target = ex_u.target;
	xf.xvec   = 8'd0;
	xf.sr_we  = 1'b0;
	xf.sr_new = {sr_r[15:5], alu_flags};
	case (ex_u.op)
		OP_FPU: begin
			xf.res   = fp_res;
			xf.flags = ccr_f;
			xf.dkill = fp_dkill;
			xf.taken = fp_taken;
			xf.xvec  = fp_xvec;
		end
		OP_MUL, OP_DIV: begin
			xf.res   = md_res;
			xf.flags = md_flags;
			xf.dkill = md_dkill;
			// (from md_z, registered: EX holds a divide by zero's first
			// clock, and nothing reads the record of a held EX -- the
			// operand's zero test ran into EX's exception, the early
			// redirect and the CCR at 60 MHz)
			if (md_z) begin
				xf.xvec  = 8'd5;
				xf.flags = {ccr_f[4:1], 1'b0};
			end
		end
		OP_MDRES: begin
			xf.res   = ex_u.cond[0] ? md_lol : md_rem;
			xf.dkill = md_ovfl;
		end
		OP_MDHI:   xf.res = ex_av;
		OP_BCC:    xf.taken = alu_cc;
		OP_DBCC: begin
			// (the counter before the decrement: Dn.W - 1 == -1 exactly when
			// Dn.W is 0 -- the adder stays off the branch decision)
			xf.taken = !alu_cc && ex_bnz;
			xf.dkill = alu_cc;
		end
		OP_TRAPCC: if (alu_trap) xf.xvec = 8'd7;
		OP_CHK:    if (alu_trap) xf.xvec = 8'd6;
		OP_CCRLOG: xf.res = ex_bv;
		OP_SPW:    xf.res = ex_av;
		OP_LATCH:  xf.res = ex_av;
		OP_CAS2C: begin
			if (!ex_u.cond[0] || cas2_eq) xf.flags = cmp_flags;
			else xf.flags = ccr_f;
		end
		OP_CAS2R: begin
			xf.res   = (ex_av & ex_szm) | (ex_bv & ~ex_szm);
			xf.dkill = cas2_eq;
		end
		OP_BFSET:  xf.res = ex_u.cond[0] ? {24'd0, bf_lonew} : {{3{ex_av[31]}}, ex_av[31:3]};
		OP_CAS: begin
			xf.flags = alu_flags;
			xf.res   = ex_bv;
		end
		default: ;
	endcase
	// control transfers
	case (ex_u.br)
		BR_IMM:  begin xf.taken = 1'b1; xf.target = ex_u.target; end
		BR_EA:   begin xf.taken = 1'b1; xf.target = ex_ea; end
		BR_A:    begin xf.taken = 1'b1; xf.target = ex_av; end
		BR_B:    begin xf.taken = 1'b1; xf.target = ex_bv; end
		default: ;
	endcase
end

// slow operations (first EX cycle)
always_comb begin
	xs.res    = ex_bs;          // (the shifter's result: last, below)
	xs.flags  = ex_shift ? {sl_flags[4], 2'b00, sl_flags[1:0]} : sl_flags;
	xs.dkill  = 1'b0;
	xs.taken  = 1'b0;
	xs.target = ex_u.target;
	xs.xvec   = 8'd0;
	xs.sr_we  = 1'b0;
	xs.sr_new = {sr_r[15:5], ccr_f};
	case (ex_u.op)
		OP_CHK2B: begin
			// WinUAE i_CHK2: signed compares of the sign-extended bounds
			// (lower in ex_latch, upper in A) with B, which is sign-extended
			// only when it is a data register (cond[1]); the 68040 leaves N, V
			logic signed [31:0] lo, up, rg;
			logic z, c;
			case (ex_u.sz)
				SZ_B: begin lo = {{24{ex_latch[7]}}, ex_latch[7:0]}; up = {{24{ex_as[7]}}, ex_as[7:0]};
				            rg = ex_u.cond[1] ? {{24{ex_bs[7]}}, ex_bs[7:0]} : ex_bs; end
				SZ_W: begin lo = {{16{ex_latch[15]}}, ex_latch[15:0]}; up = {{16{ex_as[15]}}, ex_as[15:0]};
				            rg = ex_u.cond[1] ? {{16{ex_bs[15]}}, ex_bs[15:0]} : ex_bs; end
				default: begin lo = ex_latch; up = ex_as; rg = ex_bs; end
			endcase
			z = (up == rg) || (lo == rg);
			c = !z && ((lo <= up) ? ((rg < lo) || (rg > up)) : ((rg > up) && (rg < lo)));
			xs.res   = ex_bs;
			xs.dkill = 1'b1;
			xs.flags = {ccr_f[4], ccr_f[3], z, ccr_f[1], c};
			if (ex_u.cond[0] && c) xs.xvec = 8'd6;
		end
		OP_SRLOG: begin
			logic [15:0] cur, n;
			cur = {sr_r[15:5], ccr_f};
			case (ex_u.cond[1:0])
				2'd0:    n = cur & ex_as[15:0];
				2'd1:    n = cur | ex_as[15:0];
				2'd2:    n = cur ^ ex_as[15:0];
				default: n = ex_as[15:0];
			endcase
			xs.sr_new = n & SR_MASK;
			xs.sr_we  = 1'b1;
			xs.flags  = xs.sr_new[4:0];
		end
		OP_SPR: begin
			logic [31:0] v, m;
			v = spr_read(ex_u.imm[7:0]);
			m = (ex_u.sz == SZ_B) ? 32'h0000_00FF : (ex_u.sz == SZ_W) ? 32'h0000_FFFF : 32'hFFFF_FFFF;
			xs.res = (v & m) | (ex_bs & ~m);
			xs.flags = ccr_f;
		end
		OP_MISC: begin
			xs.flags = ccr_f;
			xs.res   = ex_as;              // maintenance: the address
			if (ex_u.cond == 4'd2) begin
				// STOP #imm: SR = imm, then wait for an interrupt
				xs.sr_new = ex_as[15:0] & SR_MASK;
				xs.sr_we  = 1'b1;
				xs.flags  = xs.sr_new[4:0];
			end
			// BKPT: after its acknowledge cycle, the illegal instruction
			// exception (format $0, the BKPT's PC)
			if (ex_u.cond == 4'd9) xs.xvec = 8'd4;
		end
		OP_IACKV: begin
			// IACK data: [7:0] vector, [8] AVEC, [9] TEA (spurious)
			logic [7:0] v;
			xs.flags = ccr_f;
			if (!ex_u.cond[0]) begin
				v = ex_as[9] ? 8'd24 : ex_as[8] ? (8'd24 + {5'd0, irq_lvl_r}) : ex_as[7:0];
				xs.res = {22'd0, v, 2'b00};                 // format $0 word
			end
			else begin
				v = ex_latch[9] ? 8'd24 : ex_latch[8] ? (8'd24 + {5'd0, irq_lvl_r}) : ex_latch[7:0];
				xs.res = vbr_r + {22'd0, v, 2'b00};         // vector address
			end
		end
		OP_RTEF: begin
			// 68040 frame formats: $0 8, $1 8 (throwaway), $2 12, $3 12,
			// $7 60 bytes; others are a format error -- including $4, which
			// "the MC68040 does not generate or recognize" (MC68040UM 8.4.5;
			// only the LC/EC040 use it)
			xs.flags = ccr_f;
			if (ex_u.cond[0]) begin
				// FRESTORE header (FPU in reset state): only a NULL frame
				// (version byte $00) is compatible, anything else is a
				// format error at the FRESTORE
				xs.res = ex_as;
				if (ex_as[31:24] != 8'd0) xs.xvec = 8'd14;
			end
			else case (ex_as[15:12])
				4'h0, 4'h1: xs.res = 32'd8;
				4'h2, 4'h3: xs.res = 32'd12;
				4'h7:       xs.res = 32'd60;
				default: begin xs.res = 32'd0; xs.xvec = 8'd14; end
			endcase
		end
		OP_RTE: begin
			xs.sr_new = ex_as[15:0] & SR_MASK;
			xs.sr_we  = 1'b1;
			xs.flags  = xs.sr_new[4:0];
			xs.taken  = 1'b1;
			xs.target = rte_fmt1 ? ex_u.pc : ex_bs;
		end
		OP_BF: begin
			xs.res   = bf_res;
			xs.flags = bf_flags;
		end
		default: ;
	endcase
	// The shift, rotate, BCD and SR-logic ops' result enters last, by a
	// flag registered with the uop (ex_slr_q): it was the case's default,
	// behind the other ops' selects, on the path from EX's operand
	// through the shifter into xs_q at 60/66 MHz.
	if (ex_slr_q) xs.res = sl_res;
end

// EX outputs: the registered slow result in a slow op's second cycle
always_comb begin
	exo_t x;
	x = ex_slow ? xs_q : xf;
	if (ex_slow && ex_shift) begin
		x.flags[3] = (ex_u.sz == SZ_B) ? xs_q.res[7] : (ex_u.sz == SZ_W) ? xs_q.res[15] : xs_q.res[31];
		x.flags[2] = (ex_u.sz == SZ_B) ? (xs_q.res[7:0] == 8'd0) :
		             (ex_u.sz == SZ_W) ? (xs_q.res[15:0] == 16'd0) : (xs_q.res == 32'd0);
	end
	ex_res    = x.res;
	ex_flags  = x.flags;
	// (the uops that can suppress their write, by flags registered as they
	// enter EX, so the kill is an AND-OR of its sources: no op decode on
	// the way to the forwarding enable; the others never kill, slow ones
	// included)
	ex_dkill  = (ex_kc[0] && fp_dkill) || (ex_kc[1] && md_dkd) ||
	            (ex_kc[2] && md_ovfl) || (ex_kc[3] && alu_cc) ||
	            ex_kc[4] || (ex_kc[5] && cas2_eq);
	// synthesis translate_off
	ex_dkill_chk = x.dkill;
	// synthesis translate_on
	ex_taken  = x.taken;
	ex_target = x.target;
	ex_xvec   = x.xvec;
	ex_sr_we  = x.sr_we;
	ex_sr_new = x.sr_new;
end

// CAS: flags of (memory - Dc) and the equal decision
wire [31:0] cas_dc_m = ex_latch;
logic [31:0] cas_res;
logic  [4:0] cas_flags;
logic        cas_cc, cas_tr;
ap68040_alu cas_alu (
	.op(OP_CMP), .rc(alu_rc(OP_CMP)), .sz(ex_u.sz), .cond(4'd0),
	.a(cas_dc_m), .b(ex_bv), .ea(32'd0), .flags_in(ccr_f),
	.res(cas_res), .res_ref(), .flags_out(cas_flags), .cc_true(cas_cc), .trap(cas_tr)
);
wire cas_eq = cas_flags[2];

// compare B - A (CAS2)
logic [31:0] cmp_res;
logic  [4:0] cmp_flags;
logic        cmp_cc, cmp_tr;
ap68040_alu cmp_alu (
	.op(OP_CMP), .rc(alu_rc(OP_CMP)), .sz(ex_u.sz), .cond(4'd0),
	.a(ex_av), .b(ex_bv), .ea(32'd0), .flags_in(ccr_f),
	.res(cmp_res), .res_ref(), .flags_out(cmp_flags), .cc_true(cmp_cc), .trap(cmp_tr)
);
logic        cas2_eq;           // CAS2: both pairs equal so far
logic        rte_fmt1;          // RTE: the frame is a throwaway ($1)
wire  [31:0] ex_szm = (ex_u.sz == SZ_B) ? 32'h0000_00FF :
                      (ex_u.sz == SZ_W) ? 32'h0000_FFFF : 32'hFFFF_FFFF;

// store data, and stores the EX op cancels.  The store data's forms are
// one-hot flags registered with the uop (CAS, CAS2W, an FPU store's first
// and second words), its default the value EX writes (exw_val, with its
// selects registered too): the op decode in front of the selects, and
// ex_res's own, were the path into wb_st_data at 60 MHz.  A simulation
// check holds it to the old form for every store.
logic ex_stkill;
logic [3:0] ex_sts_q;           // EX's store data is: CAS's, CAS2W's, fp_get1, fp_get2
function automatic logic [3:0] sts_of(input uop_t u);
	sts_of = {u.op == OP_MOV && u.mem == M_ST && u.cond == 4'd2,
	          u.op == OP_MOV && u.mem == M_ST && u.cond == 4'd1,
	          u.op == OP_CAS2W, u.op == OP_CAS};
endfunction
always_comb begin
	ex_stkill = 1'b0;
	ex_st = ex_sts_q[0] ? (cas_eq ? ex_av : ex_bv) :
	        ex_sts_q[1] ? ((ex_u.cond[0] && !cas2_eq) ? ex_bv : ex_av) :
	        ex_sts_q[2] ? fp_get1 : ex_sts_q[3] ? fp_get2 : exw_val;
	if (ex_u.op == OP_CAS2W) ex_stkill = !ex_u.cond[0] && !cas2_eq;
	// an FPU store whose result is not written (an enabled integer
	// SNAN/OPERR, an unimplemented / unsupported store): its stores go
	if (fp_stkill && ex_u.mem == M_ST && !ex_is_fp) ex_stkill = 1'b1;
end

// a store into the instruction stream just ahead (see EX -> WB).  Code
// the front end fetched elsewhere (a predicted target) is the program's
// to keep coherent: the 68040 prefetches both paths of a branch and
// requires CPUSHA before self-modified code runs (MC68040UM 4.5, 7.7).
wire ex_smc = (ex_u.mem == M_ST || ex_u.mem == M_RMW) &&
              ((ex_ea[31:6] == ex_npc[31:6]) ||
               (ex_ea[31:6] == ex_npc[31:6] + 26'd1));
logic smc_pend;
// mispredict: the actual path differs from the one the front end took
wire        ex_br      = (ex_u.br != BR_NONE) || (ex_u.op == OP_RTE);
wire [31:0] ex_next    = ex_taken ? ex_target : ex_npc;
wire        ex_mispred = ex_br && ((ex_taken != ex_u.pred) ||
                                   (ex_taken && ex_u.pred && ex_target != ex_u.target));
// a mispredicted branch that WB will redirect for no other reason turns
// the front end round as it leaves EX, a cycle early; the stages behind it
// still go at WB (the front end is not flushed again), and AG takes
// nothing in between
logic       eredir_pend, wb_eredir;
wire        ex_early = ex_mispred && !ex_u.ser && !ex_sr_we &&
                       !(ex_u.last && (smc_pend || ex_smc)) && (ex_u.exc == 8'd0) &&
                       !ex_fault && (ex_xvec == 8'd0) && !ex_odd && !kill_now && !flush;

// a change of flow to an odd address is an address error at the
// instruction (format $2, the address with A0 cleared), before any of its
// side effects -- the BSR/JSR push, the RTS/RTR pop -- except that RTE has
// committed its SR and RTR its CCR.  Bcc and DBcc validate their target
// taken or not (DBcc before its condition: Dn is left untouched).
// The frame PC follows gencpu, as the cputest 68040 AE group records it:
// the instruction, except JMP (opcode + 2; + 6 for the indexed modes), JSR
// (the odd target: the fault is the fetch there) and the handler fetch of
// an exception (the vector offset, without VBR).
// (Bcc/DBcc: the decoded target, so the check does not wait for the ALU
// result that decides taken -- that path ends in the register file write
// enable.  Every other change of flow is unconditional or an FPU one.)
// The unconditional transfers (and RTE) are always taken; the others'
// target is the decoded one, and only the FPU's (FBcc FDBcc) can be taken
// besides Bcc and DBcc: its own taken, not EX's selected one.
wire        ex_bdb  = (ex_u.op == OP_BCC) || (ex_u.op == OP_DBCC);
wire        ex_ubr  = (ex_u.br == BR_IMM) || (ex_u.br == BR_EA) ||
                      (ex_u.br == BR_A) || (ex_u.br == BR_B) || (ex_u.op == OP_RTE);
wire [31:0] ex_otgt = (!ex_bdb && ex_ubr) ? ex_target : ex_u.target;
wire        ex_odd  = ex_br && (ex_bdb ? ex_u.target[0] :
                                ex_ubr ? ex_target[0] :
                                ((ex_u.op == OP_FPU) && fp_taken && ex_u.target[0]));
// (a JSR's frame PC is its target: wb_otgt, chosen at WB by wb_pc_tgt,
// so the target adder stays off wb_exc_pc's select)
logic [31:0] ex_odd_pc;
wire         ex_odd_jsr = (ex_u.br == BR_B && ex_u.op == OP_MOV) ||
                          (ex_u.br == BR_IMM && ex_u.op == OP_MOV && ex_u.imm_b[15:6] == 10'b0100_1110_10);
always_comb begin
	ex_odd_pc = ex_u.pc;
	if (ex_u.br == BR_EA)
		ex_odd_pc = ex_u.pc + (((ex_u.imm_b[5:3] == 3'd6) ||
		                        (ex_u.imm_b[5:0] == 6'o73)) ? 32'd6 : 32'd2);
	else if (ex_odd_jsr)
		ex_odd_pc = ex_u.pc;                 // JSR (JSR_K: the opword in B): wb_otgt
	else if (ex_u.br == BR_A && ex_u.op == OP_MOV && ex_u.cond == 4'hF)
		ex_odd_pc = ex_ea - vbr_r;
end

// front-file write by EX, and its broadcast to younger operands
// (CAS writes Dc either way: on a match the value written -- the
// operand read, over Dc's bits above the size -- is Dc itself, so the
// compare stays off the write enable)
wire ex_d_eff = ex_u.d_v && !ex_dkill;
// The front file's kill: DBcc writes it either way -- its counter
// decremented, or, when the condition holds (the kill), unchanged (B, the
// register as read) -- so EX's condition is in the value, not on the
// write enable and the front file's write select (ex_u.cond -> rff lvt at
// 60/66 MHz).  The back file, written at WB, keeps the kill.
wire ex_dkill_f = (ex_kc[0] && fp_dkill) || (ex_kc[1] && md_dkd) ||
                  (ex_kc[2] && md_ovfl) || ex_kc[4] || (ex_kc[5] && cas2_eq);
// (the odd-target check as it concerns a register write: only DBcc and
// FDBcc are branches that write one, so the ALU's taken stays off the
// operand forwarding -- the FPU's own taken, not EX's selected one)
wire ex_odd_w = ex_br && (ex_bdb ? ex_u.target[0] :
                          (ex_u.op == OP_FPU) && fp_taken && ex_target[0]);
// The front file is written without EX's exception decision (the fault,
// the vector, an odd branch target: the FPU's and the ALU's late
// conditions, on the write enable's path at 60/66 MHz).  A uop that takes
// an exception reaches WB with wb_ok clear, and its x_go clears fv and
// discards every younger uop: no uop that survives reads what it wrote.
// The back file, written at WB, keeps the full test.
assign exw_v   = adv_ex && ex_u.d_v && !ex_dkill_f && (ex_u.exc == 8'd0);
// synthesis translate_off
wire   sim_exw_ok = adv_ex && ex_d_eff && !ex_fault && (ex_xvec == 8'd0) && !ex_odd_w &&
                 (ex_u.exc == 8'd0);
// synthesis translate_on
// the same for AG's base/index loads: without EX's exception decision (a
// late signal) -- a uop that takes an exception flushes AG with the rest
wire        exw_ag  = adv_ex && ex_d_eff;
// ... and for the operands of the uops in DC1 and DC2: a uop that takes an
// exception flushes them too, and the flush clears the front file (fv), so
// the forwarding needs only whether EX writes the register (the timing path).
// Nor does it wait for EX to advance (the stall chain, which ends in the
// FPU's and the DMU's late holds), except for the uops whose write can be
// suppressed (ex_kc): a value a held EX broadcasts may not be its result
// yet, but every younger operand that took it -- AG's, DC1's and DC2's,
// held or advancing -- takes EX's broadcast again in the clock EX
// advances, which a uop that always writes always makes.  A uop whose
// write can be suppressed broadcasts once EX's own work is done (!ex_hold)
// and its write is not suppressed: from then until it advances its value
// and its suppression are final (a waiting WB is the only thing between:
// adv_ex, through WB's store hold, was a 60/66 MHz path).  Checked below.
// An FPU uop that writes an integer register broadcasts from flip-flops:
// fp_fin_q is set at the end of the first clock the interface does not
// hold it, with its suppression (fp_dk_q), and EX holds that clock -- the
// uop leaves a clock later.  The interface already keeps its outcome
// while EX waits after its hold drops (WB can hold EX then), checked
// below; the interface's hold and suppression, through EX's hold, were
// the forwarding enable's 60 MHz path into every younger operand.  (A
// faulted one, or one with a decode exception, does not wait or
// broadcast: the exception flushes the younger uops.)
// (the other uops' side by EX's hold and kill without the FPU's terms,
// which are off for them -- ex_kc[0] is ex_fp_q, checked -- but which
// synthesis kept: the interface's decode and kill through it into every
// younger operand were a 60 MHz path)
wire ex_hold_i  = (ex_v && ex_is_md && !md_z && !ex_fault && !md_done && !md_fin) ||
                  (ex_v && ex_slow && !ex_ph) || dbf_hold;
wire ex_dkill_i = (ex_kc[1] && md_dkd) || (ex_kc[2] && md_ovfl) || ex_kc[4] || (ex_kc[5] && cas2_eq);
assign exw_fw = ex_v && ex_u.d_v && (((ex_kc & 6'b110111) == 6'd0) ||
                                     (ex_kc[0] ? (fp_fin_q && !fp_dk_q) : (!ex_hold_i && !ex_dkill_i)));
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_kc[0] != ex_fp_q || (!ex_kc[0] && (ex_hold_i != ex_hold || ex_dkill_i != ex_dkill_f)))) begin
		$display("FAIL: EX's integer hold/kill %b/%b, the full ones %b/%b (kc0 %b fp %b, pc %h)",
		         ex_hold_i, ex_dkill_i, ex_hold, ex_dkill_f, ex_kc[0], ex_fp_q, ex_u.pc);
		$finish;
	end
// synthesis translate_on
// (cleared as the next uop enters EX, and read only while EX holds a uop:
// the flush, WB's kill and EX's advance in the clear were 60 MHz paths;
// the suppression follows the interface until the flag is set)
always_ff @(posedge clk) begin
	if (!nreset || adv_dc2) fp_fin_q <= 1'b0;
	else if (ex_v && ex_is_fp && ex_u.d_v && !ex_fault && ex_u.exc == 8'd0 && !fp_hold) fp_fin_q <= 1'b1;
	if (!fp_fin_q) fp_dk_q <= fp_dkill;
end
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && fp_fin_q && (fp_hold || fp_dk_q != fp_dkill)) begin
		$display("FAIL: an FPU uop's outcome changed after its hold dropped: hold %b, suppression %b -> %b (pc %h)",
		         fp_hold, fp_dk_q, fp_dkill, ex_u.pc);
		$finish;
	end
// synthesis translate_on
// synthesis translate_off
logic [31:0] sim_rpc;           // the redirect address as the redirects wrote it
always_ff @(posedge clk)
	if (nreset && redir_v && redir_pc !== sim_rpc) begin
		$display("FAIL: the redirect address %h, the redirect's own %h", redir_pc, sim_rpc);
		$finish;
	end
logic        sim_eb;            // such a uop broadcast before advancing
logic [31:0] sim_eb_val;
always_ff @(posedge clk) begin
	if (nreset && sim_eb && ex_v && (adv_ex || ex_hold) &&
	    (ex_dkill_f || exw_val != sim_eb_val || ex_hold)) begin
		$display("FAIL: EX broadcast %h before advancing; at the advance %h, suppressed %b, hold %b (pc %h)",
		         sim_eb_val, exw_val, ex_dkill_f, ex_hold, ex_u.pc);
		$finish;
	end
	if (!nreset || flush || kill_now || adv_ex || !ex_v) sim_eb <= 1'b0;
	else if (exw_fw && (ex_kc & 6'b110111) != 6'd0) begin
		if (sim_eb && exw_val != sim_eb_val) begin
			$display("FAIL: EX's held broadcast changed %h -> %h (pc %h)", sim_eb_val, exw_val, ex_u.pc);
			$finish;
		end
		sim_eb <= 1'b1;
		sim_eb_val <= exw_val;
	end
end
// synthesis translate_on
assign exw_reg = ex_u.d_reg;
// The value written and broadcast: the ALU's result enters at the last
// multiplexer (ex_alu_q, registered with the uop), the other sources
// before it -- the ALU's result was three selects deep (the fast ops'
// overrides, the slow ops', CAS's) on the forwarding path into the younger
// operands at 60/66 MHz.  A simulation check holds it to the old form.
logic [31:0] exw_oth, exw_oth_ref;
// (the other sources by classes registered with the uop, AND-OR, ex_oc_q:
// slow, MUL/DIV, MDRES, A (MDHI, SPW, LATCH), B (CCRLOG and the rest),
// CAS2R, BFSET, CAS, DBcc -- the op decode in front of the case reached
// the broadcast into DC1's operands at 60 MHz; the case is kept as the
// reference, checked)
function automatic logic [8:0] oc_of(input logic [6:0] o, input logic slow);
	oc_of = '0;
	if (slow) oc_of[0] = 1'b1;
	else case (o)
		OP_MUL, OP_DIV:            oc_of[1] = 1'b1;
		OP_MDRES:                  oc_of[2] = 1'b1;
		OP_MDHI, OP_SPW, OP_LATCH: oc_of[3] = 1'b1;
		OP_CAS2R:                  oc_of[5] = 1'b1;
		OP_BFSET:                  oc_of[6] = 1'b1;
		OP_CAS:                    oc_of[7] = 1'b1;
		OP_DBCC:                   oc_of[8] = 1'b1;
		default:                   oc_of[4] = 1'b1;
	endcase
endfunction
logic [8:0] ex_oc_q;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && ex_oc_q[1] && (ex_mul_q != (ex_u.op == OP_MUL) || md_resx != md_res)) begin
		$display("FAIL: EX's multiply/divide result %h by the registered kind %b, the op's %h",
		         md_resx, ex_mul_q, md_res);
		$finish;
	end
// synthesis translate_on
always_comb
	exw_oth = ({32{ex_oc_q[0]}} & xs_q.res) |
	          ({32{ex_oc_q[1]}} & md_resx) |
	          ({32{ex_oc_q[2]}} & (ex_u.cond[0] ? md_lol : md_rem)) |
	          ({32{ex_oc_q[3]}} & ex_av) |
	          ({32{ex_oc_q[4]}} & ex_bv) |
	          ({32{ex_oc_q[5]}} & ((ex_av & ex_szm) | (ex_bv & ~ex_szm))) |
	          ({32{ex_oc_q[6]}} & (ex_u.cond[0] ? {24'd0, bf_lonew} : {{3{ex_av[31]}}, ex_av[31:3]})) |
	          ({32{ex_oc_q[7]}} & ((ex_bv & ex_szm) | (ex_latch & ~ex_szm))) |
	          // (DBcc: the high word is B's either way -- only the counter
	          // word waits on the condition, which ran from the CCR's
	          // forward through every bit's value into DC1's operand)
	          ({32{ex_oc_q[8]}} & {ex_bv[31:16], alu_cc ? ex_bv[15:0] : alu_res[15:0]});
always_comb begin
	exw_oth_ref = ex_bv;
	if (ex_slow) exw_oth_ref = xs_q.res;
	else case (ex_u.op)
		OP_FPU:           exw_oth_ref = fp_res;
		OP_MUL, OP_DIV:   exw_oth_ref = md_res;
		OP_MDRES:         exw_oth_ref = ex_u.cond[0] ? md_lol : md_rem;
		OP_MDHI:          exw_oth_ref = ex_av;
		OP_CCRLOG:        exw_oth_ref = ex_bv;
		OP_SPW:           exw_oth_ref = ex_av;
		OP_LATCH:         exw_oth_ref = ex_av;
		OP_CAS2R:         exw_oth_ref = (ex_av & ex_szm) | (ex_bv & ~ex_szm);
		OP_BFSET:         exw_oth_ref = ex_u.cond[0] ? {24'd0, bf_lonew} : {{3{ex_av[31]}}, ex_av[31:3]};
		OP_CAS:           exw_oth_ref = (ex_bv & ex_szm) | (ex_latch & ~ex_szm);
		OP_DBCC:          exw_oth_ref = alu_cc ? ex_bv : alu_res;   // (the kill: unchanged)
		default:          exw_oth_ref = ex_bv;
	endcase
end
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && !ex_fp_q && (ex_oc_q !== oc_of(ex_u.op, ex_slow) || exw_oth !== exw_oth_ref)) begin
		$display("FAIL: EX's other value %h by class %b, the case's %h (op %0d)", exw_oth, ex_oc_q, exw_oth_ref, ex_u.op);
		$finish;
	end
// synthesis translate_on
// (the FPU's result next to last, by ex_fp_q: through the case it began
// the forward into AG from FPSR's read at 60 MHz; an FPU op is never slow)
assign exw_val = ex_alu_q ? alu_res : ex_fp_q ? fp_res : exw_oth;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && ex_v && !(ex_u.op == OP_DBCC && alu_cc) &&
	    exw_val !== ((ex_u.op == OP_CAS) ? ((ex_bv & ex_szm) | (ex_latch & ~ex_szm)) : ex_res)) begin
		$display("FAIL: EX's written value %h, the old form %h (op %0d, slow %b, pc %h)", exw_val,
		         (ex_u.op == OP_CAS) ? ((ex_bv & ex_szm) | (ex_latch & ~ex_szm)) : ex_res, ex_u.op, ex_slow, ex_u.pc);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && ex_v && (ex_sts_q !== sts_of(ex_u) ||
	    ((ex_u.mem == M_ST || ex_u.mem == M_RMW) &&
	     ex_st !== ((ex_u.op == OP_CAS) ? (cas_eq ? ex_av : ex_bv) :
	                (ex_u.op == OP_CAS2W) ? ((ex_u.cond[0] && !cas2_eq) ? ex_bv : ex_av) :
	                (ex_u.op == OP_MOV && ex_u.mem == M_ST && ex_u.cond == 4'd1) ? fp_get1 :
	                (ex_u.op == OP_MOV && ex_u.mem == M_ST && ex_u.cond == 4'd2) ? fp_get2 : ex_res)))) begin
		$display("FAIL: EX's store data %h (forms %b), the old form's differs (op %0d, pc %h)",
		         ex_st, ex_sts_q, ex_u.op, ex_u.pc);
		$finish;
	end
// synthesis translate_on

// the second slot's ALU, its front-file write and broadcast
logic [31:0] alu1_res;
logic  [4:0] alu1_flags;
ap68040_alu1 alu1 (.op(ex_s.op), .sz(ex_s.sz), .a(ex_s.ld ? ex_ld : ex_a1), .b(ex_b1),
                   .res(alu1_res), .flags_out(alu1_flags));
assign exw1_v   = DUAL && adv_ex && ex_s.v && ex_s.d_v && !ex1_flt;
// (without the advance, as exw_fw: the second slot's write is never
// suppressed, so every operand that took a held EX's broadcast takes it
// again in the clock EX advances -- the stall chain into the operand
// selects was a 60/66 MHz path)
assign exw1_fw  = DUAL && ex_v && ex_s.v && ex_s.d_v && !ex1_flt;
assign exw1_reg = ex_s.d_reg;
assign exw1_val = alu1_res;
// synthesis translate_off
always @(posedge clk)
	if (nreset && sim_exw_ok && ex_ee && exw_val != ex_er) begin
		$display("FAIL: early result %h, EX wrote %h (pc %h op %0d)", ex_er, exw_val, ex_u.pc, ex_u.op);
		$finish;
	end
// synthesis translate_on

//--------------------------------------------------------------------------
// WB
//--------------------------------------------------------------------------
// interrupt recognition at instruction boundaries: a level above the mask,
// or a new level 7 (edge triggered, not masked)
logic  [2:0] ipl_q;
logic        nmi_edge;
logic  [2:0] irq_lvl_r;       // level being acknowledged
// the mask in force at the boundary: an instruction that writes SR (MOVE
// to SR, RTE, ANDI/ORI/EORI to SR) decides with its new mask, so a request
// it unmasks is taken at that very boundary (cputest irq/all).  A request
// that already beat the mask holds IPEND (ipend_r) and is taken at the next
// boundary although the instruction raises the mask; IPEND lasts only while
// the request is held at that level or above.
logic        ipend_r;
logic  [2:0] ipend_lvl;
wire  [2:0]  irq_mask = (wb_v && wb_sr_we && wb_ok) ? wb_sr_new[10:8] : sr_r[10:8];
// level 7 is also recognised by level comparison whenever the mask is
// below 7 (MC68040UM 8.2.9, figure 8-3: RTE or MOVE to SR lowering the
// mask with IPL still at 7 takes it again); at mask 7 only its edge
wire         irq_pend = nmi_edge || (ipl_q > irq_mask) ||
                        (ipl_q != 3'd7 && ipend_r && ipl_q >= ipend_lvl);
wire  [2:0]  irq_lvl  = nmi_edge ? 3'd7 : ipl_q;

logic        stopped;         // STOP: waiting for an interrupt
logic [31:0] stop_pc;         // the instruction after STOP
logic        trace_defer;     // a trace held back by an interrupt
logic [31:0] trace_addr;      // its instruction address
logic        rst_issued;      // RESET instruction: RSTO requested
logic        wb_stv;          // WB: a store, and no exception
logic        xstk;            // an exception routine runs (entry to its last uop)
logic        xr_dbl;          // ... and it is an access error's, an address
                              // error's or reset's (a fault in it: halt)
logic        x_first;         // the routine is done, its handler's first
                              // instruction has not completed yet
logic        wb_cof;          // the uop's control transfer was taken

wire wb_is_exc   = wb_v && !wb_ok;
wire wb_commit   = adv_wb && !wb_is_exc;
wire wb_bound    = wb_commit && wb_u.last;
// Claim against the SR mask that commits on this clock (upstream 190ea48).
wire [2:0] claim_mask = (wb_commit && wb_sr_we) ? wb_sr_new[10:8] : sr_r[10:8];
// the second slot commits with its uop, unless that one redirects (a store
// into the code ahead: the second slot is fetched again)
wire wb1_go      = wb_s.v && !wb_redir;
wire wb1_commit  = DUAL && wb_commit && wb1_go;
// (after the second slot: where the first continues -- a branch's target
// or its next instruction, as EX found it -- plus the one word)
assign      wb_npc1 = wb_redir_pc + 32'd2;
wire [31:0] wb_next = (DUAL && wb1_go) ? wb_npc1 : wb_redir_pc;
wire  [4:0] wb_ccr_c = (DUAL && wb1_go) ? wb1_ccr : wb_ccr;   // CCR at the boundary

// trace uses the T bits the instruction started with (sr_r before its own
// SR write): T1 every instruction, T0 taken transfers and the 68040 list
wire tr_now      = sr_r[15] || (sr_r[14] && (wb_u.t0cof || wb_cof));
wire wb_is_stop  = (wb_u.op == OP_MISC) && (wb_u.cond == 4'd2);
// STOP is traced under T1, and under T0 only when it changes the upper SR
// byte (WinUAE MakeFromSR_x); a traced STOP does not stop
wire stop_traced = wb_is_stop && (sr_r[15] || (sr_r[14] && (wb_sr_new[15:8] != sr_r[15:8])));
// an interrupt accepted at a boundary where a trace is also due goes first;
// the trace is held (trace_defer) and taken at the end of the interrupt's
// exception processing, stacking the handler's entry address (MC68040UM
// 8.3: the interrupt's processing follows the other exception's at once)
wire trace_due   = wb_bound && (wb_is_stop ? stop_traced : (tr_now || trace_defer));
// a MOVEM continuation armed by RTE runs before a pending interrupt
wire cm_block    = cm_pend || (wb_v && wb_u.op == OP_RTE && cm_n_v);
wire take_irq    = irq_pend && !cm_block && (wb_bound || (stopped && !wb_v));
wire take_trace  = trace_due && !take_irq;
wire wb_refetch;
// a speculative fetch fault (code 1) is no exception: WB refetches the
// instruction once on demand, and only a second fault there is an access
// error (rt_armed/rt_pc)
// exceptions that stack the next instruction: the instruction completed
wire wb_post_trap = (wb_exc >= 8'd32 && wb_exc < 8'd48) ||
                    wb_exc == 8'd5 || wb_exc == 8'd6 || wb_exc == 8'd7;
assign wb_refetch = adv_wb && wb_v && (wb_exc == EXC_IFS || wb_exc == EXC_IFSA);
logic        rt_armed;
logic [31:0] rt_pc;
// a double bus fault (MC68040UM 8.2.1): an access or address error while
// the routine of an access error, an address error or reset runs (the
// stacking, the vector fetch, an odd handler address), or while the first
// instruction of its handler is fetched (an instruction access error: TM
// is a program space): the processor halts (PST $5) instead of taking it
wire dbl_fault   = xr_dbl && !halted &&
                   (adv_wb && wb_is_exc && !wb_refetch &&
                    ((xstk && (wb_exc == 8'd2 || wb_exc == 8'd3)) ||
                     (x_first && wb_exc == 8'd2 && (wb_exc_ssw[2:0] == 3'd2 || wb_exc_ssw[2:0] == 3'd6))));
// x_go and kill_now with adv_wb last: the store's answer reaches adv_wb
// through WB's hold, and from there ran through the boundary, the trace
// and interrupt takes and x_go into kill_now and the stall chain's
// registers at 60/66 MHz.  The two cofactors (adv_wb 1 and 0) come from
// WB's record and registered state; the forms above are checked below.
wire wb_bound_a  = !wb_is_exc && wb_u.last;
wire trace_a     = wb_bound_a && (wb_is_stop ? stop_traced : (tr_now || trace_defer));
wire irq_a       = irq_pend && !cm_block && (wb_bound_a || (stopped && !wb_v));
wire irq_n       = irq_pend && !cm_block && stopped && !wb_v;
wire refetch_a   = wb_v && (wb_exc == EXC_IFS || wb_exc == EXC_IFSA);
wire dbl_a       = xr_dbl && !halted && wb_is_exc && !refetch_a &&
                   ((xstk && (wb_exc == 8'd2 || wb_exc == 8'd3)) ||
                    (x_first && wb_exc == 8'd2 && (wb_exc_ssw[2:0] == 3'd2 || wb_exc_ssw[2:0] == 3'd6)));
wire x_go_a      = ((wb_is_exc && !refetch_a) || (trace_a && !irq_a) || irq_a) && !dbl_a && !halted;
wire x_go_n      = irq_n && !halted;
wire x_go        = adv_wb ? x_go_a : x_go_n;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && x_go != (((adv_wb && wb_is_exc && !wb_refetch) || take_trace || take_irq) &&
	                       !dbl_fault && !halted)) begin
		$display("FAIL: backend: x_go %b by its cofactors, %b by the boundary", x_go, !x_go);
		$finish;
	end
// synthesis translate_on
// a locked sequence (TAS, CAS, CAS2, a table update) ends with its LOCKE
// write; before that only an exception ends it
assign lk_abandon = x_go || dbl_fault;

// register file write ports.  Front: the AG address updates and the EX
// result.  Back: the WB commit (a result beats an address update), the
// address update of a trap after its instruction, and at exception entry
// the routine's operands (T8-T13, and T5-T7 for a format $7 frame, two
// per cycle).
always_comb begin
	logic wcom, wpost;
	fwe[0] = adv_ag && ag_u.upd_v && !ag_dyncan;  fwa[0] = ag_u.upd_reg;  fwd[0] = ag_updv;
	fwe[1] = adv_ag && ag_u.upd2_v && !ag_dyncan; fwa[1] = ag_u.upd2_reg; fwd[1] = ag_u2v;
	fwe_ag[0] = ag_v && ag_u.upd_v && !ag_dyncan;
	fwe_ag[1] = ag_v && ag_u.upd2_v && !ag_dyncan;
	// (port 1 also takes the second slot's writes, EX's or AG's: AG holds
	// its own meanwhile -- while EX holds a second-slot writer at all, so
	// the port's address and data are selected without EX's advance, the
	// stall chain into the front file's write decode at 60/66 MHz; the
	// enable alone has it)
	// (AG's second-slot write likewise by its condition without AG's
	// advance, which only enables it: without the advance the port writes
	// nothing either way -- AG's stall chose the port's address, with its
	// fan-out into the live-value table's write decode, at 60 MHz)
	if (exw1_fw) begin fwe[1] = exw1_v; fwa[1] = exw1_reg; fwd[1] = exw1_val; end
	else if (ag1w_ag) begin fwe[1] = adv_ag; fwa[1] = ag_s.d_reg; fwd[1] = ag1_val; end
	fwe[2] = exw_v;                 fwa[2] = exw_reg;       fwd[2] = exw_val;
	wcom  = wb_commit;
	wpost = adv_wb && wb_is_exc && (wb_post_trap || wb_xcommit);
	// the back file: two write ports, the later winning on the same
	// register.  Port 0 the address update; port 1 the result, else the
	// second (deferred) update -- a uop with upd2 writes no register result
	// (its destination is memory), and its upd2 yields to its upd on the
	// same register.  So a result beats an update, and upd beats upd2.
	bwe[0] = (wcom || wpost) && wb_u.upd_v;  bwa[0] = wb_u.upd_reg;  bwd[0] = wb_upd_val;
	if (wcom && wb_dwe) begin
		bwe[1] = 1'b1; bwa[1] = wb_u.d_reg; bwd[1] = wb_res;
	end
	else begin
		bwe[1] = (wcom || wpost) && wb_u.upd2_v && !(wb_u.upd_v && wb_u.upd_reg == wb_u.upd2_reg);
		bwa[1] = wb_u.upd2_reg; bwd[1] = wb_upd2_val;
	end
	// port 2: the second slot (exception entry: its uop flushed, never at once)
	bwe[2] = wb1_commit && (wb_s.d_v || wb_s.agop); bwa[2] = wb_s.d_reg; bwd[2] = wb1_res;
	case (xw_ph)
		3'd1: begin
			bwe = 3'b011;
			bwa[0] = R_T0 + 5'd8;  bwd[0] = xi_vaddr;
			bwa[1] = R_T0 + 5'd9;  bwd[1] = xi_pc;
		end
		3'd2: begin
			bwe = 3'b011;
			bwa[0] = R_T0 + 5'd10; bwd[0] = {16'd0, xi_sr};
			bwa[1] = R_T0 + 5'd11; bwd[1] = xi_addr;
		end
		3'd3: begin
			bwe = 3'b011;
			bwa[0] = R_T0 + 5'd12; bwd[0] = {16'd0, xi_vecw};
			bwa[1] = R_T0 + 5'd13; bwd[1] = {16'd0, xi_ssw};
		end
		3'd4: begin
			bwe = 3'b011;
			bwa[0] = R_T0 + 5'd5;  bwd[0] = xi_ea;
			bwa[1] = R_T0 + 5'd6;  bwd[1] = xi_w3a;
		end
		3'd5: begin
			bwe = 3'b001;
			bwa[0] = R_T0 + 5'd7;  bwd[0] = xi_w3d;
		end
		default: ;
	endcase
end


// WB holds: store not accepted yet; RESET until RSTO is done
// (both registered with the uop at EX -> WB, checked: the maintenance
// decode, through WB's hold and commit into the back file's write select,
// was a 60 MHz path)
function automatic logic rst_of(input uop_t u);
	rst_of = (u.op == OP_MISC) && (u.cond == 4'd1);
endfunction
function automatic logic mt_of(input uop_t u);
	mt_of = (u.op == OP_MISC) && (u.cond >= 4'd3) && (u.cond <= 4'd5);
endfunction
logic wb_rst_q, wb_mt_q;
wire wb_reset    = wb_rst_q;
wire wb_mt       = wb_mt_q;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && wb_v && (wb_rst_q != rst_of(wb_u) || wb_mt_q != mt_of(wb_u))) begin
		$display("FAIL: WB's registered RESET/maintenance flags %b/%b, the uop's %b/%b (pc %h)",
		         wb_rst_q, wb_mt_q, rst_of(wb_u), mt_of(wb_u), wb_u.pc);
		$finish;
	end
// synthesis translate_on
logic mt_seen;                // the DMU finished this WB uop's maintenance
assign wb_hold = wb_v && (halted || (!wb_is_exc &&
                 ((wb_st && !dm_st_rdy) || (wb_st && dm_st_fault) ||
                  (wb_reset && (!rst_issued || rsto_busy)) ||
                  (wb_mt && !mt_seen))));

assign mt_v      = wb_v && wb_mt && !wb_is_exc && !mt_seen;
assign mt_op     = (wb_u.cond == 4'd3) ? (wb_u.imm_b[5] ? 3'd2 : 3'd1) :
                   (wb_u.cond == 4'd4) ? 3'd3 : 3'd4;
assign mt_scope  = (wb_u.cond == 4'd3) ? wb_u.imm_b[4:3] :
                   (wb_u.cond == 4'd4) ? (wb_u.imm_b[4] ? 2'd3 : 2'd2) : 2'd2;
assign mt_caches = wb_u.imm_b[7:6];
assign mt_addr   = wb_res;
assign mt_fc     = dfc_r;
assign mt_ng     = (wb_u.cond == 4'd4) && !wb_u.imm_b[3];
assign mt_wr     = (wb_u.cond == 4'd5) && !wb_u.imm_b[5];   // PTESTW $F548, PTESTR $F568

logic        rst_seq;         // reset exception pending (first cycles)

// same-cycle kill of every younger uop: WB takes an exception or redirects
assign kill_now = adv_wb ? (wb_is_exc || wb_redir || x_go_a) : x_go_n;

// exception entry values
logic  [7:0] x_vec;
logic  [3:0] x_fmt;
logic [31:0] x_pc, x_addr;
logic [15:0] x_osr, x_ssw, x_nsr;
logic  [3:0] x_kind;
logic  [4:0] x_ssp;
logic        x_wfault;
logic        x_cm;             // SSW CM: a MOVEM continues from x_cm_ea
logic [31:0] x_cm_ea;
always_comb begin
	logic [15:0] cur;
	// the SR the exception sees: after this instruction when it completed
	cur = wb_commit ? (wb_sr_we ? (wb_sr_new & SR_MASK) : {sr_r[15:5], wb_ccr_c})
	                : {sr_r[15:5], wb_ccr};
	if (stopped && !wb_v) cur = {sr_r[15:5], ccr_b};
	if (adv_wb && wb_is_exc && wb_oddrte) cur = wb_sr_new & SR_MASK;
	x_osr  = cur;
	x_ssw  = 16'd0;
	x_addr = wb_u.pc;
	x_pc   = wb_u.pc;
	x_vec  = wb_exc;
	if (adv_wb && wb_is_exc) begin
		x_vec  = wb_exc;
		x_addr = wb_exa_odd ? {wb_otgt[31:1], 1'b0} : wb_exc_addr;
		x_ssw  = wb_exc_ssw;
		if (x_cm) x_ssw = x_ssw | 16'h1000;
		// TRAP #n, TRAPcc, CHK and divide-by-zero stack the next
		// instruction; faults and illegal opcodes the instruction
		x_pc   = ((wb_exc >= 8'd32 && wb_exc < 8'd48) ||
		          wb_exc == 8'd5 || wb_exc == 8'd6 || wb_exc == 8'd7) ? wb_npc : wb_u.pc;
		if (wb_exc_pcv) x_pc = wb_pc_fp ? wb_fpc : wb_pc_tgt ? wb_otgt : wb_exc_pc;
	end
	else if (take_irq) begin
		x_vec  = 8'd24 + {5'd0, irq_lvl};   // replaced by the IACK result
		x_pc   = (stopped && !wb_v) ? stop_pc : wb_next;
	end
	else begin
		// trace: format $2, PC = where execution continues, address = the
		// traced instruction
		x_vec  = 8'd9;
		x_pc   = wb_next;
		x_addr = trace_defer ? trace_addr : wb_u.pc;
	end
	// 68040 frames (MC68040UM table 8-?): $7 access error; $2 address
	// error, CHK, TRAPcc/TRAPV, divide by zero, trace; $0 the rest; the FPU
	// brings its own ($0, $2, $3)
	x_fmt  = (x_vec == 8'd2) ? 4'h7 :
	         (x_vec == 8'd3 || x_vec == 8'd5 || x_vec == 8'd6 || x_vec == 8'd7 ||
	          x_vec == 8'd9) ? 4'h2 : 4'h0;
	if (adv_wb && wb_is_exc && wb_exc_fmtv) x_fmt = wb_exc_fmt;
	x_kind = take_irq && !(adv_wb && wb_is_exc) ? (cur[12] ? EK_IRQM : EK_IRQ) :
	         (x_fmt == 4'h7) ? EK_FMT7 : (x_fmt == 4'h2 || x_fmt == 4'h3) ? EK_FMT2 : EK_FMT0;
	x_ssp  = cur[12] ? R_MSP : R_ISP;
	x_wfault = (x_fmt == 4'h7) && !x_ssw[8];

	// the SR inside the handler: S set, T cleared; an interrupt raises the
	// mask to its level and clears M
	x_nsr  = {2'b00, 1'b1, cur[12], cur[11:0]};
	if (take_irq && !(adv_wb && wb_is_exc)) begin
		x_nsr[12]   = 1'b0;
		x_nsr[10:8] = irq_lvl;
	end
end

// an access error of a MOVEM transfer in an indexed or PC-relative mode,
// or of a continued MOVEM (also its refetch), sets CM and stacks the EA
always_comb begin
	x_cm    = adv_wb && wb_is_exc && (wb_exc == 8'd2) &&
	          ((wb_u.op == OP_MOV && wb_u.cond == 4'hC && wb_u.mem != M_NONE) ||
	           (cm_pend && wb_u.pc == cm_pc));
	x_cm_ea = (cm_pend && wb_u.pc == cm_pc) ? cm_ea : wb_mv_ea;
end

// the return stack after the instruction at WB
function automatic logic [6:0] ras_after(input ras_snap_t r);
	case (r.k)
		2'd1:    ras_after = {r.tp + 3'd1, (r.n == 4'd8) ? 4'd8 : r.n + 4'd1};
		2'd2:    ras_after = {r.tp - 3'd1, r.n - 4'd1};
		default: ras_after = {r.tp, r.n};
	endcase
endfunction

// the skid's uop and slot loaded on every clock the skid is empty: they
// are read only once sk_v is set, and sk_v is set by the clock that loads
// them (the take and the stall chain behind it were a 60 MHz path into
// the enable of every bit)
always_ff @(posedge clk)
	if (SKID && !sk_v) begin
		sk_u <= in_u;
		sk_s <= in_s;
	end
// synthesis translate_off
uop_t sim_sk_u;
s1_t  sim_sk_s;
always_ff @(posedge clk) begin
	if (!flush && !sk_v && SKID && in_v && in_rdy && !ag_take) begin
		sim_sk_u <= in_u;
		sim_sk_s <= in_s;
	end
	if (nreset && sk_v && (sim_sk_u != sk_u || sim_sk_s != sk_s)) begin
		$display("FAIL: the skid's uop differs from the one its fill took");
		$finish;
	end
end
// synthesis translate_on

always_ff @(posedge clk) begin
	// (AG's uop PC and the continued MOVEM's PC as they will be: their
	// compare is registered, cm_hit_q)
	// (each candidate pair compared in parallel; AG's late take and WB's
	// write of cm_pc select last)
	logic ag_ld, cm_wr, cm_rst;
	ag_ld  = 1'b0;
	cm_wr  = 1'b0;
	cm_rst = 1'b0;
	redir_v <= 1'b0;
	ras_rv  <= 1'b0;
	exc_go  <= 1'b0;
	flush   <= 1'b0;
	fe_flush <= 1'b0;
	ucond_v <= 1'b0;
	dbg_retire <= 1'b0;
	dbg_retire2 <= 1'b0;

	if (!nreset) begin
		ag_v  <= 1'b0; dc1_v <= 1'b0; dc2_v <= 1'b0; ex_v <= 1'b0; wb_v <= 1'b0;
		ag_s  <= '0; dc1_s <= '0; dc2_s <= '0; ex_s <= '0; wb_s <= '0;
		rra2_q <= '0;
		sk_v  <= 1'b0;
		sk_vr <= 1'b0;
		eredir_pend <= 1'b0;
		wb_eredir   <= 1'b0;
		fv <= 32'd0;
		fv_clr <= 1'b0;
		xw_ph <= 3'd0;
		xw_pend <= 1'b0;
		ccr_f   <= 5'd0;
		ccr_b   <= 5'd0;
		sr_r    <= 16'h2700;
		sp_sel  <= sp_of(16'h2700);
		vbr_r   <= 32'd0;
		cacr_r  <= 32'd0;
		sfc_r   <= 3'd0;
		dfc_r   <= 3'd0;
		tc_r    <= 32'd0;
		itt0_r  <= 32'd0; itt1_r <= 32'd0; dtt0_r <= 32'd0; dtt1_r <= 32'd0;
		mmusr_r <= 32'd0; urp_r  <= 32'd0; srp_r  <= 32'd0;
		xi_pc   <= 32'd0; xi_addr <= 32'd0; xi_sr <= 16'd0; xi_vecw <= 16'd0; xi_ssw <= 16'd0;
		xi_ea   <= 32'd0; xi_w3a <= 32'd0; xi_w3d <= 32'd0; xi_f7 <= 1'b0;
		md_go   <= 1'b0;
		md_hiin <= 32'd0;
		cas2_eq <= 1'b0;
		rte_fmt1 <= 1'b0;
		rte_fmt7 <= 1'b0;
		cm_n_v   <= 1'b0;
		cm_n_ea  <= 32'd0;
		cm_pend  <= 1'b0;
		cm_ea    <= 32'd0;
		cm_pc    <= 32'd0;
		cm_rst   = 1'b1;
		wb_mv_ea <= 32'd0;
		trace_defer <= 1'b0;
		trace_addr <= 32'd0;
		md_fin  <= 1'b0;
		md_z    <= 1'b0;
		ex_ph   <= 1'b0;
		ex_pb   <= 1'b0;
		xs_q    <= '0;
		md_rem  <= 32'd0;
		md_lol  <= 32'd0;
		md_ovfl <= 1'b0;
		ex_latch <= 32'd0;
		bf_off   <= 32'd0;
		bf_w     <= 6'd32;
		bf_wn    <= 6'd0;
		bf_top   <= 32'hFFFF_FFFF;
		bf_sx    <= 32'd0;
		bf_lonew <= 8'd0;
		ipl_q   <= 3'd0;
		nmi_edge <= 1'b0;
		irq_lvl_r <= 3'd0;
		ipend_r  <= 1'b0;
		ipend_lvl <= 3'd0;
		rt_armed <= 1'b0;
		rt_pc    <= 32'd0;
		smc_pend <= 1'b0;
		stopped <= 1'b0;
		stop_pc <= 32'd0;
		rst_issued <= 1'b0;
		mt_seen <= 1'b0;
		wb_cof  <= 1'b0;
		halted  <= 1'b0;
		rst_seq <= 1'b1;
		exc_kind <= EK_RESET;
		exc_l7   <= 1'b0;
		exc_ssp <= R_ISP;
		redir_pc <= 32'd0;
		ras_rtp <= '0;
		ras_rn <= '0;
	end
	else begin
		// (the redirect address is read only with redir_v's pulse: EX's
		// next address every clock, WB's redirects below taking
		// precedence -- as the early redirect's enable, the branch's
		// taken decision behind the operand was a 60 MHz path)
		redir_pc <= ex_next;
		//------------------------------------------------------------------
		// reset exception: the routine loads ISP and PC from 0 and 4
		//------------------------------------------------------------------
		if (rst_seq) begin
			rst_seq  <= 1'b0;
			exc_go   <= 1'b1;
			exc_kind <= EK_RESET;
			exc_l7   <= 1'b0;
			exc_ssp  <= R_ISP;
		end

		ipl_q <= ipl;
		if (ipl_q == 3'd0 || ipl_q == 3'd7 || (ipend_r && ipl_q < ipend_lvl))
			ipend_r <= 1'b0;
		else if (ipl_q > claim_mask && (!ipend_r || ipl_q > ipend_lvl)) begin
			ipend_r   <= 1'b1;
			ipend_lvl <= ipl_q;
		end
		if (ipl == 3'd7 && ipl_q != 3'd7) nmi_edge <= 1'b1;
		else if (ipl != 3'd7) nmi_edge <= 1'b0;

		//------------------------------------------------------------------
		// AG -> DC1
		//------------------------------------------------------------------
		if (adv_ag) begin
			dc1_u   <= ag_u;
			dc1_u.msz <= ag_msz;
			if (ag_snref) begin
				// refetched from here (see snp_pend): no access, no effect
				dc1_u.exc <= EXC_SNR;
				dc1_u.mem <= M_NONE;
			end
			if (ag_cancel) begin
				// no tail byte: a load gives zero, a store nothing; a
				// cancelled FPU transfer also leaves its address registers
				dc1_u.mem   <= M_NONE;
				dc1_u.a_src <= OS_ZERO;
				if (ag_dyncan) begin
					dc1_u.upd_v  <= 1'b0;
					dc1_u.upd2_v <= 1'b0;
				end
			end
			dc1_s   <= ag_s;
			dc1_ee  <= ag_ee && !ag_snref && !ag_cancel;
			dc1_er  <= ag_er;
			dc1_ea  <= ag_u.ag ? ag_maddr : 32'd0;
			dc1_upd <= ag_updv;
			dc1_upd2 <= ag_u2v;
		end
		if (!stall_dc1) dc1_v <= adv_ag;
		// DC1's operands: AG's (with the snoop into the uop entering DC1)
		// whenever DC1 does not hold -- DC1 is empty after a clock it took
		// nothing in -- else its own with EX's writes laid over; DC1's
		// hold selects last (adv_ag's enable and the hold's branch put the
		// stall chain ahead of these selects, a 60/66 MHz path)
		begin
			logic [31:0] na, nb, na1, ha, hb, ha1, hb1;
			na = ag_a;
			nb = ag_b;
			if (exw_fw && ag_u.a_src == OS_REG && ag_u.a_reg == exw_reg) na = exw_val;
			if (exw_fw && ag_u.b_src == OS_REG && ag_u.b_reg == exw_reg) nb = exw_val;
			// (A was read as the pair entered AG: this cycle's EX writes laid over it)
			na1 = ag_s.agop ? ag1_val :
			      (ag_s.a_v && !ag_s.a_imm) ? bcast(exw_fw, ag_s.a_reg, ag_a1) : ag_a1;
			ha = dc1_a;
			hb = dc1_b;
			if (exw_fw && dc1_u.a_src == OS_REG && dc1_u.a_reg == exw_reg) ha = exw_val;
			if (exw_fw && dc1_u.b_src == OS_REG && dc1_u.b_reg == exw_reg) hb = exw_val;
			if (exw1_fw && dc1_u.a_src == OS_REG && dc1_u.a_reg == exw1_reg) ha = exw1_val;
			if (exw1_fw && dc1_u.b_src == OS_REG && dc1_u.b_reg == exw1_reg) hb = exw1_val;
			ha1 = (dc1_s.a_v && !dc1_s.a_imm && !dc1_s.agop) ? bcast(exw_fw, dc1_s.a_reg, dc1_a1) : dc1_a1;
			hb1 = dc1_s.b_v ? bcast(exw_fw, dc1_s.b_reg, dc1_b1) : dc1_b1;
			dc1_a  <= stall_dc1 ? ha  : na;
			dc1_b  <= stall_dc1 ? hb  : nb;
			dc1_a1 <= stall_dc1 ? ha1 : na1;
			dc1_b1 <= stall_dc1 ? hb1 : ag_b1;
		end

		//------------------------------------------------------------------
		// DC1 -> DC2
		//------------------------------------------------------------------
		if (adv_dc1) begin
			dc2_u    <= dc1_u;
			dc2_ee   <= dc1_ee;
			dc2_er   <= dc1_er;
			dc2_a    <= (dc1_u.a_src == OS_REG) ? bcast(exw_fw, dc1_u.a_reg, dc1_a) : dc1_a;
			dc2_b    <= (dc1_u.b_src == OS_REG) ? bcast(exw_fw, dc1_u.b_reg, dc1_b) : dc1_b;
			dc2_s    <= dc1_s;
			dc2_a1   <= (dc1_s.a_v && !dc1_s.a_imm && !dc1_s.agop) ? bcast(exw_fw, dc1_s.a_reg, dc1_a1) : dc1_a1;
			dc2_b1   <= dc1_s.b_v ? bcast(exw_fw, dc1_s.b_reg, dc1_b1) : dc1_b1;
			dc2_ea   <= dc1_ea;
			dc2_upd  <= dc1_upd;
			dc2_upd2 <= dc1_upd2;
		end
		else if (dc2_v) begin
			if (dc2_u.a_src == OS_REG) dc2_a <= bcast(exw_fw, dc2_u.a_reg, dc2_a);
			if (dc2_u.b_src == OS_REG) dc2_b <= bcast(exw_fw, dc2_u.b_reg, dc2_b);
			if (dc2_s.a_v && !dc2_s.a_imm && !dc2_s.agop) dc2_a1 <= bcast(exw_fw, dc2_s.a_reg, dc2_a1);
			if (dc2_s.b_v) dc2_b1 <= bcast(exw_fw, dc2_s.b_reg, dc2_b1);
		end
		if (!stall_dc2) dc2_v <= adv_dc1;

		//------------------------------------------------------------------
		// DC2 -> EX
		//------------------------------------------------------------------
		if (adv_dc2) begin
			ex_u     <= dc2_u;
			ex_amem  <= (dc2_u.a_src == OS_MEM);
			ex_bmem  <= (dc2_u.b_src == OS_MEM);
			ex_md_q  <= (dc2_u.op == OP_MUL) || (dc2_u.op == OP_DIV);
			ex_mul_q <= (dc2_u.op == OP_MUL);
			ex_fp_q  <= (dc2_u.op == OP_FPU);
			ex_dbcc_q <= (dc2_u.op == OP_DBCC);
			ex_rc_q   <= alu_rc(dc2_u.op);
			ex_fuse_q <= (dc2_u.sz == SZ_W);
			ex_eal_q  <= (dc2_u.sz == SZ_B);
			ex_slow_q <= is_slow(dc2_u.op);
			ex_slr_q  <= is_slow(dc2_u.op) && (dc2_u.op != OP_CHK2B) && (dc2_u.op != OP_SPR) &&
			             (dc2_u.op != OP_MISC) && (dc2_u.op != OP_IACKV) && (dc2_u.op != OP_RTEF) &&
			             (dc2_u.op != OP_BF);
			// (no `inside': Quartus 17 rejects it)
			ex_alu_q  <= !is_slow(dc2_u.op) &&
			             (dc2_u.op != OP_FPU) && (dc2_u.op != OP_MUL) && (dc2_u.op != OP_DIV) &&
			             (dc2_u.op != OP_MDRES) && (dc2_u.op != OP_MDHI) && (dc2_u.op != OP_CCRLOG) &&
			             (dc2_u.op != OP_SPW) && (dc2_u.op != OP_LATCH) && (dc2_u.op != OP_CAS2R) &&
			             (dc2_u.op != OP_BFSET) && (dc2_u.op != OP_CAS) && (dc2_u.op != OP_DBCC);
			ex_npc   <= dc2_u.pc + {27'd0, dc2_u.ilen, 1'b0};
			ex_kc    <= {dc2_u.op == OP_CAS2R, dc2_u.op == OP_CHK2B,
			             dc2_u.op == OP_DBCC, dc2_u.op == OP_MDRES, dc2_u.op == OP_DIV,
			             dc2_u.op == OP_FPU};
			ex_shk   <= shk_of(dc2_u.op);
			ex_bfx   <= (dc2_u.cond[2:0] == 3'd1) || (dc2_u.cond[2:0] == 3'd3);
			ex_rvm   <= rvm_of(shk_of(dc2_u.op), dc2_u.sz);
			ex_sts_q <= sts_of(dc2_u);
			ex_oc_q  <= oc_of(dc2_u.op, is_slow(dc2_u.op));
			ex_ee    <= dc2_ee;
			ex_er    <= dc2_er;
			ex_a     <= (dc2_u.a_src == OS_REG) ? bcast(exw_fw, dc2_u.a_reg, dc2_a) : dc2_a;
			ex_b     <= (dc2_u.b_src == OS_REG) ? bcast(exw_fw, dc2_u.b_reg, dc2_b) : dc2_b;
			ex_s     <= dc2_s;
			ex_a1    <= (dc2_s.a_v && !dc2_s.a_imm && !dc2_s.agop) ? bcast(exw_fw, dc2_s.a_reg, dc2_a1) : dc2_a1;
			ex_b1    <= dc2_s.b_v ? bcast(exw_fw, dc2_s.b_reg, dc2_b1) : dc2_b1;
			ex_ea    <= dc2_ea;
			ex_ld    <= dm_ldata;
			begin
				logic [31:0] v;
				v = (dc2_u.a_src == OS_MEM) ? dm_ldata :
				    (dc2_u.a_src == OS_REG) ? bcast(exw_fw, dc2_u.a_reg, dc2_a) : dc2_a;
				// (no word sign extension: no slow op takes A as an address
				// register's word -- checked -- and the extension after the
				// broadcast put EX's FPU hold a level deeper into ex_as)
				ex_as <= v;
			end
			ex_bs    <= (dc2_u.b_src == OS_MEM) ? dm_ldata :
			            (dc2_u.b_src == OS_REG) ? bcast(exw_fw, dc2_u.b_reg, dc2_b) : dc2_b;
			ex_upd   <= dc2_upd;
			ex_upd2  <= dc2_upd2;
			ex_fault <= (dc2_u.mem != M_NONE) && dm_fault;
			ex1_flt  <= DUAL && dc2_s.v && dc2_s.ld && dm_fault;
			ex_fvec  <= dm_fvec;
			ex_faddr <= dm_faddr;
			ex_fssw  <= dm_fssw;
			md_go    <= 1'b0;
			md_fin   <= 1'b0;
			md_z     <= 1'b0;
		end
		if (!stall_ex) ex_v <= adv_dc2;
		// EX's next uop against WB's next: EX's own when it moves on
		if (adv_dc2) ew_same <= adv_ex ? (dc2_u.pc == ex_u.pc) : (dc2_u.pc == wb_u.pc);
		else if (adv_ex) ew_same <= 1'b1;
		if (ex_md_start) md_go <= 1'b1;
		if (ex_v && ex_div0) md_z <= 1'b1;
		// synthesis translate_off
		if (adv_ex && ex_u.op == OP_DIV && !ex_fault && md_z != ex_div0) begin
			$display("FAIL: a divide leaves EX with md_z %b, its divisor zero %b", md_z, ex_div0);
			$finish;
		end
		if (adv_ex && ex_u.op == OP_DIV && ex_u.sz == SZ_W && !ex_fault && !md_z &&
		    md_ovf16 != (md_ovf || (md_sign ? (md_lo[31:15] != {17{md_lo[15]}}) : (md_lo[31:16] != 16'd0)))) begin
			$display("FAIL: a DIVx.W leaves EX with md_ovf16 %b, its quotient %h (ovf %b)", md_ovf16, md_lo, md_ovf);
			$finish;
		end
		// synthesis translate_on
		if (ex_v && ex_pre && !ex_pb) begin
			ex_pb    <= 1'b1;
			bf_ins_q <= bf_rr & bf_top;    // (ex_av << bf_wn)
			bf_rot_q <= bf_rot;
			rox_nx_q <= rox_nx;
			rox_nxl_q <= rox_nxl;
		end
		else if (ex_v && ex_slow && !ex_ph) begin
			ex_ph <= 1'b1;
			xs_q  <= xs;
		end
		if (adv_ex || kill_now) begin ex_ph <= 1'b0; ex_pb <= 1'b0; end

		//------------------------------------------------------------------
		// EX -> WB
		//------------------------------------------------------------------
		if (adv_ex) begin
			wb_u        <= ex_u;
			wb_rst_q    <= rst_of(ex_u);
			wb_mt_q     <= mt_of(ex_u);
			wb_npc      <= ex_npc;
			wb_s        <= ex_s;
			wb1_flt     <= ex1_flt;
			wb1_res     <= alu1_res;
			wb_res      <= exw_val;
			wb_dwe      <= ex_d_eff;
			wb_upd_val  <= ex_upd;
			wb_upd2_val <= ex_upd2;
			wb_st       <= (ex_u.mem == M_ST || ex_u.mem == M_RMW) && !ex_stkill;
			// (the same, and no exception: the DMU's store valid from a
			// flip-flop -- wb_exc's compare sat on the stall chain)
			wb_stv      <= (ex_u.mem == M_ST || ex_u.mem == M_RMW) && !ex_stkill &&
			               ex_u.exc == 8'd0 && !ex_fault && ex_xvec == 8'd0 && !ex_odd;
			wb_ok       <= ex_u.exc == 8'd0 && !ex_fault && ex_xvec == 8'd0 && !ex_odd;
			wb_st_data  <= ex_st;
			// a store into the instruction stream just ahead (the fetch
			// queue and the instructions in flight) refetches after itself:
			// the 68040 does not promise this, the previous core's AmigaOS
			// boot depended on it (t_integer 192)
			// (a store from a uop before the last one -- MOVEM, a bit
			// field, CAS2 -- defers the refetch to the instruction's end:
			// redirecting there would drop the instruction's remaining uops)
			wb_redir    <= ex_mispred || ex_u.ser || ex_sr_we ||
			               (ex_u.last && (smc_pend || ex_smc)) ||
			               // (the second slot's load runs again, alone)
			               (ex_s.v && ex1_flt);
			wb_eredir   <= ex_early;
			// (the return stack to restore is read only with ras_rv, which
			// pulses with a redirect: it is loaded every advance, so the
			// late early-redirect decision is not its enable; WB's later
			// loads take precedence)
			{ras_rtp, ras_rn} <= ras_after(ex_u.ras);
			if (ex_early) begin
				fe_flush    <= 1'b1;
				redir_v     <= 1'b1;
				// synthesis translate_off
				sim_rpc     <= ex_next;
				// synthesis translate_on
				ras_rv      <= ex_u.ras.v;
				eredir_pend <= 1'b1;
			end
			if (ex_u.last) smc_pend <= 1'b0;
			else if (ex_smc) smc_pend <= 1'b1;
			// where execution continues, predicted correctly or not
			wb_redir_pc <= ex_br ? ex_next : ex_npc;
			wb_sr_we    <= ex_sr_we;
			wb_cof      <= ex_br && ex_taken;
			wb_sr_new   <= ex_sr_new;
			if (ex_u.op == OP_CAS2C)
				cas2_eq <= ex_u.cond[0] ? (cas2_eq && cmp_flags[2]) : cmp_flags[2];
			if (ex_u.exc == EXC_SNR) begin
				wb_exc      <= EXC_IFS;     // refetched by WB, never an error
				wb_exc_ssw  <= 16'd0;
			end
			else if (ex_u.exc != 8'd0) begin
				logic ifs, ifa;
				// instruction fetch faults: a speculative one is refetched
				// once (wb_refetch) and becomes an access error when it
				// faults again at the same instruction
				ifs = (ex_u.exc == EXC_IFS || ex_u.exc == EXC_IFSA);
				ifa = (ex_u.exc == EXC_IFA || ex_u.exc == EXC_IFSA);
				if (ifs && !(rt_armed && rt_pc == ex_u.pc))
					wb_exc <= ex_u.exc;
				else if (ifs || ex_u.exc == EXC_IFB || ex_u.exc == EXC_IFA)
					wb_exc <= 8'd2;
				else
					wb_exc <= ex_u.exc;
				// a faulted instruction fetch: the faulting word's address;
				// SSW ATC for an MMU fault, read, long, TT normal, TM the
				// program space of the instruction's privilege
				if (ifs || ex_u.exc == EXC_IFB || ex_u.exc == EXC_IFA) begin
					wb_exc_ssw  <= {5'd0, ifa, 1'b0, 1'b1, 3'b000, 2'b00,
					                sr_r[13] ? 3'd6 : 3'd2};
				end
				else begin
					wb_exc_ssw  <= 16'd0;
				end
			end
			else if (ex_fault) begin
				wb_exc      <= ex_fvec;
				wb_exc_ssw  <= ex_fssw;
			end
			else if (ex_xvec == 8'd0 && ex_odd) begin
				wb_exc      <= 8'd3;
				wb_exc_ssw  <= 16'd0;
			end
			else if (ex_is_fp && ex_xvec != 8'd0) begin
				// FPU exceptions bring their frame format, PC and address
				wb_exc      <= ex_xvec;
				wb_exc_ssw  <= 16'd0;
			end
			else begin
				wb_exc      <= ex_xvec;
				wb_exc_ssw  <= 16'd0;
			end
			// The fault address, apart from the vector decision: an FPU uop's
			// is its interface's (used only when it takes an exception: an odd
			// target's comes from wb_otgt), any other's its PC -- the vector
			// (the FPU's and the ALU's conditions, behind the operands and the
			// load data) stays off this select.
			wb_exc_addr <= (ex_u.exc != 8'd0) ?
			                 ((ex_u.exc == EXC_IFS || ex_u.exc == EXC_IFSA ||
			                   ex_u.exc == EXC_IFB || ex_u.exc == EXC_IFA) ? ex_u.target : ex_u.pc) :
			               ex_fault  ? ex_faddr :
			               ex_is_fp  ? fp_xaddr : ex_u.pc;
			wb_exc_pcv <= ex_u.exc == 8'd0 && !ex_fault && ex_xvec == 8'd0 && ex_odd;
			wb_exa_odd <= ex_u.exc == 8'd0 && !ex_fault && ex_xvec == 8'd0 && ex_odd;
			wb_otgt    <= ex_otgt;
			wb_pc_tgt  <= ex_odd_jsr && (ex_u.br != BR_EA);
			wb_exc_pc  <= ex_odd_pc;
			wb_exc_fmtv <= 1'b0;
			wb_xcommit  <= 1'b0;
			// (an FPU exception's frame PC and format registered whatever the
			// vector, chosen at WB by wb_pc_fp: the vector stays off the
			// 32-bit selects)
			wb_fpc     <= fp_xnext ? ex_npc : ex_u.pc;
			wb_exc_fmt <= fp_xfmt;
			wb_pc_fp   <= 1'b0;
			if (ex_u.exc == 8'd0 && !ex_fault && ex_is_fp && ex_xvec != 8'd0) begin
				wb_exc_pcv  <= 1'b1;
				wb_pc_fp    <= 1'b1;
				wb_exc_fmtv <= 1'b1;
				wb_xcommit  <= fp_xcommit;
			end
			wb_oddrte  <= ex_u.exc == 8'd0 && !ex_fault && ex_xvec == 8'd0 && ex_odd &&
			              ex_u.op == OP_RTE;
			// CCR after this uop (CHK, CHK2, TRAPcc and divide-by-zero set
			// their flags and then trap: the stacked SR carries them)
			// (and after the second slot: its flags over the first's)
			begin
				logic [4:0] nf, c0;
				nf = (ex_u.op == OP_CAS) ? cas_flags : ex_flags;
				c0 = (ex_u.exc == 8'd0 && !ex_fault) ? ((nf & ex_u.ccr_we) | (ccr_f & ~ex_u.ccr_we)) : ccr_f;
				wb_ccr  <= c0;
				wb1_ccr <= (alu1_flags & ex_s.ccr_we) | (c0 & ~ex_s.ccr_we);
				if (ex_u.exc == 8'd0 && !ex_fault)
					ccr_f <= (DUAL && ex_s.v && !ex1_flt) ? ((alu1_flags & ex_s.ccr_we) | (c0 & ~ex_s.ccr_we)) : c0;
			end
			if (ex_u.op == OP_MDHI)  md_hiin  <= ex_av;
			if (ex_u.op == OP_LATCH || (ex_u.op == OP_IACKV && !ex_u.cond[0])) ex_latch <= ex_av;
			if (ex_u.op == OP_RTEF && !ex_u.cond[0]) begin
				rte_fmt1 <= (ex_av[15:12] == 4'h1);
				rte_fmt7 <= (ex_av[15:12] == 4'h7);
			end
			if (ex_u.op == OP_MISC && ex_u.cond == 4'd6) begin
				cm_n_v  <= rte_fmt7 && ex_bv[12];
				cm_n_ea <= ex_av;
			end
			wb_mv_ea <= ex_ea - ex_u.target;
			if (ex_u.op == OP_BFSET && !ex_u.cond[0]) begin
				logic [5:0] w;
				logic [6:0] e;
				w = (ex_bv[4:0] == 5'd0) ? 6'd32 : {1'b0, ex_bv[4:0]};
				e = {4'd0, ex_av[2:0]} + {1'b0, w} + 7'd7;
				bf_off <= ex_av;
				bf_w   <= w;
				bf_wn  <= 6'd32 - w;
				bf_top <= ~(32'hFFFF_FFFF >> w);      // (a shift by 32 gives 0)
				bf_sx  <= 32'hFFFF_FFFF << w;
				bf_nb  <= e[5:3];
				bf_nb3 <= e[5:3] == 3'd3;
			end
			if (ex_u.op == OP_BF) bf_lonew <= bf_lo_out;
		end
		// (not when the next uop enters EX this cycle: the reset above is
		// for it, and the done belongs to the one leaving)
		if (md_done && md_go && !adv_dc2) md_fin <= 1'b1;
		if (md_done) begin
			md_rem  <= md_hi;
			md_lol  <= md_lo;
		end
		// overflow of the uop leaving EX (word forms check 16 bits)
		if (adv_ex && (ex_u.op == OP_DIV || ex_u.op == OP_MUL)) md_ovfl <= (ex_u.op == OP_DIV) && md_dkill;
		if (!stall_wb) wb_v <= adv_ex;

		//------------------------------------------------------------------
		// WB commit
		//------------------------------------------------------------------
		if (wb_commit) begin
			dbg_retire <= wb_u.last;
			dbg_retire2 <= wb1_commit;
			// architectural commit: the back file's write ports (bwe)
			ccr_b <= wb_ccr_c;
			if (wb_u.op == OP_SPW) begin
				// MOVEC to the 68040's control registers (masks: WinUAE
				// m68k_move2c)
				case (wb_u.imm_b[7:0])
					8'h00: sfc_r  <= wb_res[2:0];
					8'h01: dfc_r  <= wb_res[2:0];
					8'h02: cacr_r <= wb_res & 32'h8000_8000;
					8'h03: tc_r   <= wb_res & 32'h0000_C000;
					8'h04: itt0_r <= wb_res & 32'hFFFF_E364;
					8'h05: itt1_r <= wb_res & 32'hFFFF_E364;
					8'h06: dtt0_r <= wb_res & 32'hFFFF_E364;
					8'h07: dtt1_r <= wb_res & 32'hFFFF_E364;
					8'h11: vbr_r  <= wb_res;
					8'h15: mmusr_r <= wb_res;
					8'h16: urp_r  <= wb_res & 32'hFFFF_FE00;
					8'h17: srp_r  <= wb_res & 32'hFFFF_FE00;
					default: ;
				endcase
			end
			if (wb_sr_we) begin
				sr_r  <= {wb_sr_new[15:5], 5'd0};
				sp_sel <= sp_of(wb_sr_new);
				ccr_b <= wb_sr_new[4:0];
			end
			if (wb_is_stop && !stop_traced) begin
				stopped <= 1'b1;
				stop_pc <= wb_npc;
			end
			if (wb_redir) begin
				flush    <= 1'b1;
				if (!wb_eredir) begin
					fe_flush <= 1'b1;
					redir_v  <= 1'b1;
					redir_pc <= wb_redir_pc;
					// synthesis translate_off
					sim_rpc  <= wb_redir_pc;
					// synthesis translate_on
					ras_rv   <= wb_u.ras.v;
					{ras_rtp, ras_rn} <= ras_after(wb_u.ras);
				end
				// the front file restarts from the back one (fv cleared below)
				ccr_f <= wb_sr_we ? wb_sr_new[4:0] : wb_ccr;
			end
			if (wb_bound) trace_defer <= 1'b0;
			if (wb_bound) rt_armed <= 1'b0;
			if (wb_bound) begin
				// RTE of a format $7 frame with CM arms the continuation of
				// the MOVEM it returns to; any other instruction ends it
				cm_pend <= (wb_u.op == OP_RTE) && cm_n_v;
				cm_ea   <= cm_n_ea;
				cm_pc   <= wb_next;
				cm_wr   = 1'b1;
				if (wb_u.op == OP_RTE) cm_n_v <= 1'b0;
			end
		end
		if (wb_refetch) begin
			flush    <= 1'b1;
			fe_flush <= 1'b1;
			redir_v  <= 1'b1;
			redir_pc <= wb_u.pc;
			// synthesis translate_off
			sim_rpc  <= wb_u.pc;
			// synthesis translate_on
			ras_rv   <= wb_u.ras.v;
			{ras_rtp, ras_rn} <= {wb_u.ras.tp, wb_u.ras.n};
			ccr_f    <= ccr_b;
			rt_armed <= 1'b1;
			rt_pc    <= wb_u.pc;
		end

		//------------------------------------------------------------------
		// exception entry: a faulting/trapping uop (its effects discarded,
		// trap flags kept), a trace after an instruction, or an interrupt
		// at an instruction boundary.  The front file restarts from the
		// back file plus this uop's committed writes; T5..T13 carry the
		// routine's operands.
		//------------------------------------------------------------------
		// (the routine's operands and its entry kind follow the entry
		// values every clock outside the operand-write sequence, which reads
		// them, and so hold from the clock x_go starts it: x_go, the end of
		// WB's commit and the interrupt decision, was a 60/66 MHz path into
		// their enables.  x_go never comes inside the sequence -- checked)
		// The routine's operands, written into the back file by the xw
		// sequence: T8 vector address, T9 PC, T10 SR, T11 address, T12
		// format/vector word, T13 SSW; format $7: T5 the EA field (the
		// MOVEM EA with CM, else FA), T6/T7 WB3A/WB3D of a write fault (WB3S
		// stays clear: the instruction restarts)
		if (xw_ph == 3'd0) begin
			xi_f7    <= (x_fmt == 4'h7);
			// (read with exc_go, the sequence's end; the reset sequence
			// sets its own)
			if (!rst_seq) begin
				exc_kind <= x_kind;
				exc_ssp  <= x_ssp;
			end
			xi_sr    <= x_osr;
			xi_vecw  <= {x_fmt, 2'b00, x_vec, 2'b00};
			xi_pc    <= x_pc;
			xi_addr  <= x_addr;
			xi_ssw   <= x_ssw;
			xi_vaddr <= vbr_r + {22'd0, x_vec, 2'b00};
			xi_ea    <= x_cm ? x_cm_ea : x_addr;
			xi_w3a   <= x_wfault ? x_addr : 32'd0;
			xi_w3d   <= x_wfault ? wb_st_data : 32'd0;
		end
		// synthesis translate_off
		if (x_go && xw_ph != 3'd0) begin
			$display("FAIL: an exception entry inside the routine's operand writes");
			$finish;
		end
		// synthesis translate_on
		if (x_go) begin
			rt_armed <= 1'b0;
			cm_pend  <= 1'b0;
			smc_pend <= 1'b0;
			flush    <= 1'b1;
			fe_flush <= 1'b1;
			redir_v  <= 1'b0;
			ras_rv   <= 1'b0;
			xw_ph    <= 3'd1;          // T8-T13 (and T5-T7) first, then exc_go
			xw_pend  <= 1'b1;
			// (read by the routine's accesses, after the sequence)
			exc_l7   <= take_irq && !(adv_wb && wb_is_exc) && (irq_lvl == 3'd7);
			sr_r     <= {x_nsr[15:5], 5'd0};
			sp_sel   <= sp_of(x_nsr);
			ccr_b    <= x_osr[4:0];
			ccr_f    <= x_osr[4:0];
			stopped  <= 1'b0;
			if (take_irq && !(adv_wb && wb_is_exc)) begin
				irq_lvl_r <= irq_lvl;
				ipend_r   <= 1'b0;
				if (irq_lvl == 3'd7) nmi_edge <= 1'b0;
				// a trace due at this boundary is taken at the handler
				if (trace_due) begin
					trace_defer <= 1'b1;
					trace_addr  <= wb_u.pc;
				end
			end
		end

		// exception entry, continued: three cycles of back-file writes
		// (five for a format $7 frame)
		if (xw_ph != 3'd0) begin
			xw_ph <= xw_ph + 3'd1;
			if ((xw_ph == 3'd3 && !xi_f7) || xw_ph == 3'd5) begin
				xw_ph  <= 3'd0;
				xw_pend <= 1'b0;
				exc_go <= 1'b1;
			end
		end

		// front-valid bits: a front write makes the register's front copy
		// current; a redirect, a refetch or an exception drops them all
		// (AG's two writes as a mask formed without the advance, which
		// gates the mask last: the stall chain stays off the decode)
		begin
			logic [31:0] m_ag, m_ex;
			m_ag = (fwe_ag[0] ? (32'd1 << ag_u.upd_reg) : 32'd0) | (fwe_ag[1] ? (32'd1 << ag_u.upd2_reg) : 32'd0) |
       (ag1w_ag ? (32'd1 << ag_s.d_reg) : 32'd0);
			m_ex = (fwe[2] ? (32'd1 << fwa[2]) : 32'd0) | (exw1_v ? (32'd1 << exw1_reg) : 32'd0);
			fv <= fv | (adv_ag ? m_ag : 32'd0) | m_ex;
		end
		// (the clear a clock after the redirect, refetch or exception
		// that kills every younger uop: nothing reads the front file in
		// between -- AG is empty and the flush holds it -- and its
		// conditions, from WB's commit and the exception decision, were a
		// 60/66 MHz path into all 32 bits; checked below)
		fv_clr <= (wb_commit && wb_redir) || wb_refetch || x_go;
		if (fv_clr) fv <= 32'd0;
		// synthesis translate_off
		if (fv_clr && (ag_v || (!flush && !stall_ag && ain_v && !stopped))) begin
			$display("FAIL: the front file is read in the clock its valid bits clear");
			$finish;
		end
		if (((wb_commit && wb_redir) || wb_refetch || x_go) && !kill_now) begin
			$display("FAIL: the front valid bits clear without a kill");
			$finish;
		end
		// synthesis translate_on
		// synthesis translate_off
		if (fwe[0] != (adv_ag && fwe_ag[0]) || (!exw1_v && fwe[1] != (adv_ag && (fwe_ag[1] || ag1w_ag))) ||
    (exw1_v && adv_ag && (fwe_ag[1] || ag1w_ag)) || (fwe_ag[1] && ag1w_ag)) begin
			$display("FAIL: the front writes %b, the advance %b and AG's %b", fwe, adv_ag, fwe_ag);
			$finish;
		end
		// synthesis translate_on

		// a store that took a bus error at WB becomes an access fault of
		// its instruction (WB holds one cycle, then takes it)
		if (wb_v && wb_st && dm_st_rdy && dm_st_fault && wb_exc == 8'd0) begin
			wb_stv      <= 1'b0;
			wb_ok       <= 1'b0;
			wb_exc      <= 8'd2;
			wb_exc_addr <= dm_st_faddr;
			wb_exc_ssw  <= dm_st_fssw;
		end
		// maintenance done: WB completes next cycle; PTEST sets MMUSR; a
		// push of CPUSH's that ended in TEA is an access error (7.6.1)
		if (wb_v && wb_mt && mt_done) begin
			mt_seen <= 1'b1;
			if (wb_u.cond == 4'd5) mmusr_r <= mt_mmusr;
			if (mt_fault && wb_exc == 8'd0) begin
				wb_stv      <= 1'b0;
				wb_ok       <= 1'b0;
				wb_exc      <= 8'd2;
				wb_exc_addr <= mt_faddr;
				wb_exc_ssw  <= mt_fssw;
			end
		end
		if (adv_wb) mt_seen <= 1'b0;

		// RESET instruction: RSTO for 512 bus clocks, WB waits
		if (wb_v && wb_reset && !rst_issued && !wb_is_exc) rst_issued <= 1'b1;
		if (dbl_fault) halted <= 1'b1;
		if (adv_wb) rst_issued <= 1'b0;

		//------------------------------------------------------------------
		// flush: kill every stage (the redirecting/excepting uop has left)
		//------------------------------------------------------------------
		if (flush) begin
			ag_v <= 1'b0; dc1_v <= 1'b0; dc2_v <= 1'b0; ex_v <= 1'b0; wb_v <= 1'b0;
			eredir_pend <= 1'b0;
		end
		else begin
			// D2 (or the skid) -> AG
			if (!stall_ag) ag_v <= ain_v && !stopped && !halted;
			// (port 2's address loaded whenever AG does not stall: AG is
			// empty after a clock it took nothing in.  It sits in the
			// register file's read address registers, and the take's other
			// conditions were a 60/66 MHz path into them)
			if (!stall_ag) rra2_q <= (DUAL && ain_s.v) ? ain_s.b_reg : ain_u.upd2_reg;
			if (ag_take && ain_v) begin
				ag_u      <= ain_u;
				ag_s      <= DUAL ? ain_s : '0;
				ag_ld     = 1'b1;
				ag_u.disp <= ain_u.dmv ? ain_u.disp + {{24{ain_u.dma[7]}}, ain_u.dma} : ain_u.disp;
			end
			// the skid: emptied when AG takes it; filled by a popped uop AG
			// did not take
			if (sk_v) begin
				if (ag_take) begin sk_v <= 1'b0; sk_vr <= 1'b0; end
			end
			else if (SKID && in_v && in_rdy && !ag_take) begin
				sk_v  <= 1'b1;
				sk_vr <= 1'b1;
			end
		end
		if (flush || kill_now) begin sk_v <= 1'b0; sk_vr <= 1'b0; end
		if (kill_now) begin
			ag_v <= 1'b0; dc1_v <= 1'b0; dc2_v <= 1'b0; ex_v <= 1'b0; wb_v <= 1'b0;
		end
	end
	ag_bft_q <= ag_ld ? bft_of(ain_u) : bft_of(ag_u);
	if (ag_ld) begin
		ag_ra_q <= ain_u.a_reg;
		ag_rb_q <= ain_u.b_reg;
	end
	cm_hit_q <= cm_rst ? ((ag_ld ? ain_u.pc : ag_u.pc) == 32'd0) :
	            ag_ld  ? (cm_wr ? (ain_u.pc == wb_next) : (ain_u.pc == cm_pc)) :
	                     (cm_wr ? (ag_u.pc  == wb_next) : (ag_u.pc  == cm_pc));
end
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && cm_hit_q != (ag_u.pc == cm_pc)) begin
		$display("FAIL: the registered MOVEM continuation compare %b, the PCs' %b", cm_hit_q, ag_u.pc == cm_pc);
		$finish;
	end
// synthesis translate_on

assign dm_st_v    = wb_v && wb_stv;
// synthesis translate_off
always_ff @(posedge clk)
	if (nreset && (ag_bft_q != bft_of(ag_u) || bf_nb3 != (bf_nb == 3'd3))) begin
		$display("FAIL: AG's registered bit field tail flag %b / nb3 %b, the uop's %b / %b",
		         ag_bft_q, bf_nb3, bft_of(ag_u), bf_nb == 3'd3);
		$finish;
	end
always_ff @(posedge clk)
	if (nreset && wb_v && (wb_stv != (wb_st && wb_exc == 8'd0) || wb_ok != (wb_exc == 8'd0))) begin
		$display("FAIL: wb_stv %b, the store %b with exception %0d (pc %h)", wb_stv, wb_st, wb_exc, wb_u.pc);
		$finish;
	end
// synthesis translate_on
assign iack_lvl   = irq_lvl_r;
assign rsto_req   = wb_v && wb_reset && !rst_issued && !wb_is_exc;
assign dm_st_data = wb_st_data;
assign dbg_pc     = wb_u.pc;
assign ucond      = 1'b0;

// processor status (MC68040UM 5.9.1, table 5-6): the end of an instruction
// (branch taken / not taken / other) for one bus clock, else the present
// status.  An exception's stacking (from its entry to the routine's last
// uop) ends as a virtual JMP: supervisor, branch taken.
always_ff @(posedge clk) begin
	if (!nreset) xstk <= 1'b1;               // reset processing
	else if (x_go) xstk <= 1'b1;
	else if (adv_wb && wb_u.last) xstk <= 1'b0;
end
// the handler's first instruction: from the routine's end to that
// instruction's completion (a refetch of it is no completion)
always_ff @(posedge clk) begin
	if (!nreset || x_go || halted) x_first <= 1'b0;
	else if (adv_wb && wb_u.last && xstk) x_first <= 1'b1;
	else if (wb_bound || (adv_wb && wb_is_exc && !wb_refetch)) x_first <= 1'b0;
end
always_ff @(posedge clk)
	if (!nreset) xr_dbl <= 1'b1;             // (reset's routine)
	else if (x_go) xr_dbl <= (x_vec == 8'd2 || x_vec == 8'd3);
// IPEND: a request beats the mask; it negates once the interrupt is
// recognized internally (7.8.1: "can precede the external interrupt
// acknowledge bus cycle")
assign irq_pending = irq_pend;
// no instruction fetch from the moment STOP or RESET is at WB (no fetch
// cycle may run with RSTO asserted), while stopped, or halted
assign fetch_stop  = stopped || halted || (wb_v && (wb_is_stop || wb_reset));
assign pst_ev   = adv_wb && wb_u.last && !wb_is_exc;
assign pst_code = xstk ? 4'hB :
                  {sr_r[13], 1'b0,
                   (wb_cof || wb_redir) ? 2'b11 :
                   ((wb_u.op == OP_BCC || wb_u.op == OP_DBCC) ? 2'b10 : 2'b01)};
assign pst_st   = halted ? 4'h5 : stopped ? 4'hD : xstk ? 4'hF :
                  (wb_v && wb_u.op == OP_RTE) ? 4'hE :
                  tw_busy ? {sr_r[13], 3'b100} : {sr_r[13], 3'b000};

// AG's incoming index: a bypassed value (agx_xb) or an early result
// (agx_ex) rather than the register read -- the block below makes the same
// choice (checked)
logic agx_ex, agx_xb;
always_comb begin
	logic [3:0] wx;
	agx_xb = 1'b0;
	if (fwe_ag[0] && ag_u.upd_reg == ain_u.idx)  agx_xb = 1'b1;
	if (fwe_ag[1] && ag_u.upd2_reg == ain_u.idx) agx_xb = 1'b0;
	if (ag1w_ag && ag_s.d_reg == ain_u.idx)      agx_xb = 1'b1;
	if (dc2_capd && dc2_u.d_reg == ain_u.idx)    agx_xb = 1'b1;
	wx = yw(ain_u.idx);
	agx_ex = !(ag_v && ag_u.d_v && ag_u.d_reg == ain_u.idx) &&
	         !(ag_v && ag_s.v && ag_s.d_v && ag_s.d_reg == ain_u.idx) && wx[2];
end

// AG's base and index registers: loaded with the incoming uop (with the
// front-file writes of that cycle bypassed in), then following EX's
// writes while AG holds (an interlocked base or index is written there)
always_ff @(posedge clk) begin
	// a captured EX writer stays captured while it is in EX
	if (adv_ex) begin cap_b <= 1'b0; cap_x <= 1'b0; end
	// (loaded on every clock AG does not stall: AG is empty after a clock it
	// took nothing in -- a flush, STOP or no incoming uop -- so the values
	// are unused then; the take's other conditions, ahead of the stall,
	// put the stall chain's end deeper into these selects at 60/66 MHz)
	if (!stall_ag) begin
		logic [31:0] b, x;
		logic        cb, cx, eb, ex, x2, xb, kb, kx;
		logic  [3:0] wb, wx;
		b = rrd[0];
		x = 32'd0;                     // (the register read itself: below the block)
		cb = 1'b0;
		cx = 1'b0;
		eb = 1'b0;
		ex = 1'b0;
		x2 = 1'b0;
		xb = 1'b0;                     // x is a bypassed value, not the register read
		// (AG's own updates: here AG advances, so fwe[0..1] is just whether
		// it holds one -- adv_ag, the end of the stall chain, stays off the
		// data select)
		// (AG's own values, not the ports': port 1 may carry a second slot's
		// EX write instead)
		if (fwe_ag[0] && ag_u.upd_reg == ain_u.base)  b = ag_updv;
		if (fwe_ag[0] && ag_u.upd_reg == ain_u.idx)   begin x = ag_updv; xb = 1'b1; end
		if (fwe_ag[1] && ag_u.upd2_reg == ain_u.base) b = ag_u2v;
		if (fwe_ag[1] && ag_u.upd2_reg == ain_u.idx)  begin x2 = 1'b1; xb = 1'b0; end
		if (ag1w_ag && ag_s.d_reg == ain_u.base) b = ag1_val;
		if (ag1w_ag && ag_s.d_reg == ain_u.idx)  begin x = ag1_val; x2 = 1'b0; xb = 1'b1; end
		// the load entering EX, unless a younger writer is in AG or DC1
		// (it will be waited for in any case).  Its data enters at the
		// last multiplexer (kb, kx), the index in one select: dc2_capd
		// waits on the DMU's aligned-load test, and through these selects
		// and the scale it was a 60 MHz path into agb_q/agx_q
		kb = dc2_capd && dc2_u.d_reg == ain_u.base;
		kx = dc2_capd && dc2_u.d_reg == ain_u.idx;
		if (kb) cb = adv_dc2;
		if (kx) begin cx = adv_dc2; x2 = 1'b0; xb = 1'b1; end
		// the youngest writer's early result (not the uop leaving AG:
		// its result is loaded next cycle)
		wb = yw(ain_u.base);
		wx = yw(ain_u.idx);
		if (!(ag_v && ag_u.d_v && ag_u.d_reg == ain_u.base) &&
    !(ag_v && ag_s.v && ag_s.d_v && ag_s.d_reg == ain_u.base) && wb[2]) begin
			b = ywv(wb[1:0]); eb = 1'b1; cb = 1'b0; kb = 1'b0;
		end
		if (!(ag_v && ag_u.d_v && ag_u.d_reg == ain_u.idx) &&
    !(ag_v && ag_s.v && ag_s.d_v && ag_s.d_reg == ain_u.idx) && wx[2]) begin
			ex = 1'b1; cx = 1'b0;
		end
		agb_q <= !ain_u.base_v ? 32'd0 : kb ? dc2_capv : b;
		// EX writing it this cycle: the register file read is a cycle
		// early (unless a younger load or early result supplied it)
		stale_b <= ((exw_ag && exw_reg == ain_u.base) || (exw1_v && exw1_reg == ain_u.base)) &&
		           ain_u.base_v && !cb && !eb;
		stale_x <= ((exw_ag && exw_reg == ain_u.idx) || (exw1_v && exw1_reg == ain_u.idx)) &&
		           ain_u.idx_v && !cx && !ex;
		// (whose write it was: the two slots write different registers)
		stale_b1 <= exw1_v && exw1_reg == ain_u.base;
		stale_x1 <= exw1_v && exw1_reg == ain_u.idx;
		// (the early results are scaled beside the writer search)
		ag2_x <= x2 && !ex && ain_u.idx_v;
		ag2_v <= ag_u2v;
		// (the register read scaled on its own, the bypasses' value on its
		// own, then the select: the read went through the bypass selects
		// before the scale, a 60/66 MHz path)
		agx_q <= (kx && !ex) ? dc2_capxi :
		         !ex ? ixf(x, ain_u) :
		         (wx[1:0] == 2'd1) ? ixf(dc1_er, ain_u) :
		         (wx[1:0] == 2'd2) ? ixf(dc2_er, ain_u) : ixf(ex_er, ain_u);
		// synthesis translate_off
		if (nreset && (ex != agx_ex || xb != agx_xb)) begin
			$display("FAIL: AG's index choice %b%b, the block's %b%b", agx_ex, agx_xb, ex, xb);
			$finish;
		end
		// synthesis translate_on
		cap_b <= cb;
		cap_x <= cx;
		erb   <= eb;
		erx   <= ex;
	end
	else begin
		if (yw_b[2]) begin
			if (ag_u.base_v) agb_q <= ywv(yw_b[1:0]);
			erb <= 1'b1;
			stale_b <= 1'b0;
		end
		else begin
			// (an older writer's value is overwritten in time by the
			// youngest's: AG keeps waiting for it)
			if (stale_b && ag_u.base_v) agb_q <= stale_b1 ? exq1_val : exq_val;
			stale_b  <= ag_u.base_v && ((exw_ag && exw_reg == ag_u.base && !cap_b) ||
			                            (exw1_v && exw1_reg == ag_u.base)) &&
			            !(dc2_capd && dc2_u.d_reg == ag_u.base);
			stale_b1 <= exw1_v && exw1_reg == ag_u.base;
			if (dc2_capd && ag_u.base_v && dc2_u.d_reg == ag_u.base) begin
				agb_q <= dc2_capv;
				if (adv_dc2) cap_b <= 1'b1;
			end
		end
		if (yw_x[2]) begin
			stale_x <= 1'b0;
			agx_q <= (yw_x[1:0] == 2'd1) ? ixf(dc1_er, ag_u) :
			         (yw_x[1:0] == 2'd2) ? ixf(dc2_er, ag_u) : ixf(ex_er, ag_u);
			erx <= 1'b1;
		end
		else begin
			if (stale_x) agx_q <= ixf(stale_x1 ? exq1_val : exq_val, ag_u);
			stale_x  <= ag_u.idx_v && ((exw_ag && exw_reg == ag_u.idx && !cap_x) ||
			                           (exw1_v && exw1_reg == ag_u.idx)) &&
			            !(dc2_capd && dc2_u.d_reg == ag_u.idx);
			stale_x1 <= exw1_v && exw1_reg == ag_u.idx;
			if (dc2_capd && dc2_u.d_reg == ag_u.idx) begin
				agx_q <= dc2_capxs;
				if (adv_dc2) cap_x <= 1'b1;
			end
		end
		if (ag2_x) begin
			agx_q <= ixf(ag2_v, ag_u);
			ag2_x <= 1'b0;
		end
	end
	// the incoming index from the register read, scaled, at agx_q's last
	// multiplexer: when AG takes and neither a bypass nor an early result
	// supplies it (agx_ex/agx_xb, the block's own choice above, formed
	// apart) -- through the bypass, early-result and hold selects the read
	// was a 60/66 MHz path
	if (!stall_ag && !agx_ex && !agx_xb) agx_q <= ixf(rrd[1], ain_u);
	// the second slot's operand A: read as the pair enters AG, with that
	// cycle's AG writes and EX writes laid over it; then EX's writes.
	// (Loaded whenever AG does not stall: AG is empty after a cycle it took
	// nothing in, so the value is unused then.  The stall, the end of the
	// stall chain, selects last: a 60/66 MHz path through the load's
	// conditions and the 32-bit select)
	ag_a1q <= stall_ag ? ag_a1h : ag_a1t;
	exq_val  <= exw_val;
	exq1_val <= exw1_val;
	if (flush || !nreset) begin
		cap_b <= 1'b0; cap_x <= 1'b0; erb <= 1'b0; erx <= 1'b0;
		stale_b <= 1'b0; stale_x <= 1'b0;
		ag2_x <= 1'b0;
	end
end

endmodule
