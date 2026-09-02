//============================================================================
//  wombat_store_buffer — two-entry ordered CPU write queue.
//
//  Only host-qualified, non-faulting physical RAM writes may enter the queue.
//  Their upstream acknowledgement is registered when the transaction is
//  captured; the writes then drain in order through the ordinary bus. Reads
//  and non-qualified writes cannot pass an older queued write.
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
// the boot overlay; the remaining top-bit check excludes the fixed ROM window
// and every device region even if a caller accidentally leaves the qualifier
// high.
wire buffer_req = (ENABLE != 0) && buffer_writes && s_req && s_write &&
	                 (s_addr[31:30] == 2'b00);

// accept_ack doubles as the held-request guard. In the cycle after capture it
// prevents the still-asserted request from being enqueued twice, matching the
// registered-ack discipline used by wombat_bus32.
wire push = buffer_req && !accept_ack && (count != 2'd2);
wire pop  = drain_active && (m_ack || m_err);

// Direct transactions wait until the queue is empty. Their live attributes
// are stable under the upstream level-held request until s_ack or m_err.
wire direct_request = s_req && !buffer_req && (count == 0) && !drain_active;

assign pending = (count != 0);
assign s_ack   = buffer_req ? accept_ack : (direct_active ? m_ack : 1'b0);
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
		if (push) accept_ack <= 1;

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

		if (drain_active) begin
			if (m_ack || m_err) drain_active <= 0;
		end
		else if (!direct_active && (count != 0) && !m_ack && !m_err)
			drain_active <= 1;

		if (direct_active) begin
			if (m_ack || m_err) direct_active <= 0;
		end
		else if (!drain_active && (count == 0) && direct_request &&
		         !m_ack && !m_err)
			direct_active <= 1;
	end
end

endmodule
