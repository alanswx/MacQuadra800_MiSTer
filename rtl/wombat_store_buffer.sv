//============================================================================
//  wombat_store_buffer — two-entry ordered CPU write queue.
//
//  Only host-qualified, non-faulting physical RAM writes -- and writes into
//  the DAFB VRAM window, which is on-chip block RAM that can never fault --
//  may enter the queue. Their upstream acknowledgement is registered when
//  the transaction is captured; the writes then drain in order through the
//  ordinary bus. Non-qualified writes cannot pass an older queued write, so a
//  DAFB register write still sees every earlier pixel store landed; a read
//  may pass one queued write to another 16-byte line (see pass_ok below).
//
//  The queue sits below ap040_cache. Cache hits need no master transaction and
//  may therefore run while a write drains, which is the latency this block is
//  intended to hide. The host must keep buffer_writes low for ROM, devices, or
//  any region that can report a delayed bus error.
//============================================================================

module wombat_store_buffer
#(
	parameter ENABLE = 1
)
(
	input             clk,
	input             nreset,
	input             ce,
	input             buffer_writes,

	// CPU/cache side: level-held transaction, one-cycle acknowledgement.
	input             s_req,
	input             s_posted,     // the cache already acknowledged this write
	input             s_write,
	input             s_instr,
	input       [1:0] s_size,
	input      [31:0] s_addr,
	input      [31:0] s_wdata,
	input       [2:0] s_fc,
	output            s_ack,
	output     [31:0] s_rdata,

	// Platform side: the existing post-cache bus contract.
	output            m_req,
	output            m_write,
	output            m_instr,
	output      [1:0] m_size,
	output     [31:0] m_addr,
	output     [31:0] m_wdata,
	output      [2:0] m_fc,
	input             m_ack,
	input      [31:0] m_rdata,
	input             m_err,

	// High until every accepted buffered write has reached platform ack.
	output            pending
);

reg  [1:0] count;
reg        accept_ack;
reg        drain_active;
reg        direct_active;

reg        q0_instr, q1_instr;
reg  [1:0] q0_size,  q1_size;
reg [31:0] q0_addr,  q1_addr;
reg [31:0] q0_wdata, q1_wdata;
reg  [2:0] q0_fc,    q1_fc;

// Wombat's physical RAM window occupies the low 1 GB. buffer_writes excludes
// the boot overlay; the remaining address check excludes the fixed ROM window
// and every device region even if a caller accidentally leaves the qualifier
// high. The DAFB VRAM window ($F9000000-$F91FFFFF, the machine's decode 2)
// is added explicitly: QuickDraw's pixel stores are the hottest uncached
// writes in the machine, and posting them hides the platform round trip
// exactly as it does for RAM.
wire vram_window = (s_addr[31:21] == 11'b1111_1001_000);
wire buffer_req = (ENABLE != 0) && buffer_writes && s_req && s_write &&
	                 ((s_addr[31:30] == 2'b00) || vram_window);

// accept_ack doubles as the held-request guard. In the cycle after capture it
// prevents the still-asserted request from being enqueued twice, matching the
// registered-ack discipline used by wombat_bus32.
wire push = buffer_req && !accept_ack && (count != 2'd2);
wire pop  = drain_active && (m_ack || m_err);

// Direct transactions wait until the queue is empty. Their live attributes
// are stable under the upstream level-held request until s_ack or m_err.
// A read may pass ONE queued write whose 16-byte line differs from its own
// (2026-09-19): a cache miss or a bypass read used to wait for both queued
// stores to reach the SDRAM (about 5 % of the Speedometer bracket).  The
// drain of the head starts the cycle after its capture, so in practice
// the read passes the second of two queued stores once the first has
// landed.  A read of the queued store's own line still waits (a fill must
// see the store), non-qualified writes still wait, and a full queue always
// drains first, so a third store stalling the CPU is never starved by a
// stream of reads.
wire pass_ok = (ENABLE != 0) && s_req && !s_write && !buffer_req &&
               (count == 2'd1) && (s_addr[31:4] != q0_addr[31:4]);
wire direct_request = s_req && !buffer_req && ((count == 0) || pass_ok) && !drain_active;

assign pending = (count != 0);
// A posted write is acknowledged in its capture cycle: nothing upstream
// waits on it combinationally, and accept_ack still guards the held
// request from being captured twice.
assign s_ack   = buffer_req ? (accept_ack | (push & s_posted)) :
                 (direct_active ? m_ack : 1'b0);
assign s_rdata = m_rdata;

assign m_req   = drain_active ? 1'b1     : direct_request;
assign m_write = drain_active ? 1'b1     : s_write;
assign m_instr = drain_active ? q0_instr : s_instr;
assign m_size  = drain_active ? q0_size  : s_size;
assign m_addr  = drain_active ? q0_addr  : s_addr;
assign m_wdata = drain_active ? q0_wdata : s_wdata;
assign m_fc    = drain_active ? q0_fc    : s_fc;

always @(posedge clk) begin
	if (!nreset) begin
		count         <= 0;
		accept_ack    <= 0;
		drain_active  <= 0;
		direct_active <= 0;
		q0_instr <= 0; q1_instr <= 0;
		q0_size  <= 0; q1_size  <= 0;
		q0_addr  <= 0; q1_addr  <= 0;
		q0_wdata <= 0; q1_wdata <= 0;
		q0_fc    <= 0; q1_fc    <= 0;
	end
	else if (ce) begin
		accept_ack <= 0;
		// a posted write was acknowledged in its capture cycle; the
		// requester has moved on, so no held-request guard is needed
		if (push) accept_ack <= !s_posted;

		// Queue update. A simultaneous pop/push is included for completeness;
		// with a full queue the waiting third store is accepted on the next
		// cycle, after the pop has made its slot visible.
		case ({push, pop})
			2'b10: begin
				if (count == 0) begin
					q0_instr <= s_instr;
					q0_size  <= s_size;
					q0_addr  <= s_addr;
					q0_wdata <= s_wdata;
					q0_fc    <= s_fc;
				end
				else begin
					q1_instr <= s_instr;
					q1_size  <= s_size;
					q1_addr  <= s_addr;
					q1_wdata <= s_wdata;
					q1_fc    <= s_fc;
				end
				count <= count + 2'd1;
			end

			2'b01: begin
				q0_instr <= q1_instr;
				q0_size  <= q1_size;
				q0_addr  <= q1_addr;
				q0_wdata <= q1_wdata;
				q0_fc    <= q1_fc;
				count <= count - 2'd1;
			end

			2'b11: begin
				if (count == 2'd1) begin
					q0_instr <= s_instr;
					q0_size  <= s_size;
					q0_addr  <= s_addr;
					q0_wdata <= s_wdata;
					q0_fc    <= s_fc;
				end
				else begin
					q0_instr <= q1_instr;
					q0_size  <= q1_size;
					q0_addr  <= q1_addr;
					q0_wdata <= q1_wdata;
					q0_fc    <= q1_fc;
					q1_instr <= s_instr;
					q1_size  <= s_size;
					q1_addr  <= s_addr;
					q1_wdata <= s_wdata;
					q1_fc    <= s_fc;
				end
			end

			default: begin end
		endcase

		// a passing read eligible in the same cycle wins over the drain of
		// the one queued write (the CPU waits on the read, not the write);
		// with two queued the drain always goes first
		if (drain_active) begin
			if (m_ack || m_err) drain_active <= 0;
		end
		else if (!direct_active && (count != 0) && !direct_request &&
		         !m_ack && !m_err)
			drain_active <= 1;

		if (direct_active) begin
			if (m_ack || m_err) direct_active <= 0;
		end
		else if (!drain_active && direct_request && !m_ack && !m_err)
			direct_active <= 1;
	end
end

endmodule
