//============================================================================
//  sdram_beat32 — 32-bit machine beats on the 16-bit MiSTer SDRAM controller.
//
//  Wraps rtl/sdram.sv (Sorgelig's, from NeoGeo_MiSTer) and the clk_sys <->
//  clk_ram handshake that used to live inline in MacQuadra800.sv.  Three things
//  here that the plain two-access bridge did not do:
//
//  * A READ FILLS A 16-BYTE LINE.  The controller programs BURST_LENGTH=8,
//    so one READ returns four aligned longwords.  All four are retained in
//    this bridge; later reads from that line complete without another SDRAM
//    command.  This matches the AP68040 cache's four-beat refill pattern and
//    removes three serialized clk_sys/clk_ram handshakes per cache miss.
//    Writes still take two accesses; NO_WRITE_BURST=1 in the mode register.
//
//  * THE RELATED CLOCKS USE TIMED HALF-CYCLE HANDOFFS.  clk_sys and clk_ram
//    are phase-aligned 1:3 outputs of the same PLL.  Capturing the request and
//    completion toggles on clk_ram's falling edge removes the two conservative
//    2FF synchronisers while leaving a timed half-cycle on every crossing.
//    Hardware-tested read latency: 7 -> 5 clk_sys (~212 -> ~151 ns).
//
//  * WRITES ARE POSTED.  ack fires as the beat is captured and the drain
//    happens behind the machine's back.  Nothing downstream had to change
//    for that: the whole stall chain — this bridge, wombat_bus32, the
//    cache's write-through C_PASS state, the core — is ack-based, so
//    releasing the ack releases all of it.  Ordering is free, because the
//    next beat still waits on `busy`: a read that follows a posted write
//    cannot start until the write has been issued to the chip.  Posting
//    hides write latency; it does not add bandwidth, so a sustained store
//    stream still drains at the controller's rate.
//
//  Beat contract (clk_sys):
//   - req is level-held; a beat is captured on the first cycle with
//     !busy && !ack, and req may drop as soon as ack is seen.
//   - ack is a single-cycle pulse.  For a read it means "rdata is valid";
//     for a write it means "accepted", not "in the chip".
//   - busy spans the whole access, a posted write's drain included, and is
//     the only thing that orders one beat against the next.
//
//  Byte lanes: be[3] is the byte at addr+0 = wdata[31:24] (the machine's
//  big-endian convention), so the first SDRAM word carries wdata[31:16].
//  Nothing else reads this memory, so the in-chip order only has to agree
//  with itself.
//============================================================================

module sdram_beat32
(
	input             init,          // hold the controller in its power-up sequence
	input             clk_sys,
	input             clk_ram,       // 3x clk_sys, same PLL, phase aligned

	// beat port (clk_sys)
	input             req,
	input             we,
	input      [26:2] addr,
	input       [3:0] be,
	input      [31:0] wdata,
	output reg        ack   = 0,
	output reg [31:0] rdata = 0,
	output reg        busy  = 0,
	output            line_valid_o,
	output     [26:4] line_tag_o,
	output    [127:0] line_data_o,
	output            line_pending_o,
	output     [26:4] line_pending_tag_o,

	// SDRAM pins
	inout      [15:0] SDRAM_DQ,
	output     [12:0] SDRAM_A,
	output            SDRAM_DQML,
	output            SDRAM_DQMH,
	output      [1:0] SDRAM_BA,
	output            SDRAM_nCS,
	output            SDRAM_nWE,
	output            SDRAM_nRAS,
	output            SDRAM_nCAS,
	output            SDRAM_CKE,
	output            SDRAM_CLK
);

// Start each refresh slot at 764 cycles.  A BL8 already in flight can defer
// the command by up to eight clocks; this guard keeps the worst observed gap
// within the SDRAM's 7.8 us distributed-refresh interval at 99 MHz.
reg        refresh = 0;
reg  [9:0] refcnt  = 0;

always @(posedge clk_ram) begin
	refcnt <= refcnt + 1'b1;
	if (refcnt == 10'd763) begin
		refcnt  <= 0;
		refresh <= ~refresh;
	end
end

// ---- clk_sys side: hand one beat over, wait for the ack toggle ----------
reg        req_tgl  = 0;
reg        ack_seen = 0;
reg        posted   = 0;             // the beat in flight was acked at capture
reg [26:2] r_addr;
reg [31:0] r_wdata;
reg  [3:0] r_be;
reg        r_we;

// ---- clk_ram side: one burst read, or two 16-bit writes ----------------
reg        req_seen = 0;
reg        busy_r   = 0;
reg        acc      = 0;             // write half: 0 = high word, 1 = low
reg        rd_burst = 0;
reg  [2:0] rd_word  = 0;
reg        ready_d  = 0;
reg [31:0] hold     = 0;
reg [31:0] line_hold [0:3];
reg        ack_tgl  = 0;
reg        line_done_tgl = 0;

wire [15:0] dout;
wire        ready;

// clk_sys and clk_ram are 0-degree outputs of the same PLL, with an exact
// 1:3 frequency ratio.  They are related clocks, not asynchronous domains.
// The old bridge nevertheless put a two-flop synchronizer in each direction,
// which burned about 60% of a read beat after the SDRAM burst itself became
// fast.  Transfer the toggles on clk_ram's falling edge instead: it is 5 ns
// from either adjacent clk_ram rising edge and can never coincide with a
// clk_sys rising edge.  The request payload remains held for the entire beat;
// the read payload is copied alongside the completion toggle.
//
// These are deliberately separate falling-edge registers.  The controller
// remains wholly rising-edge logic, and TimeQuest can time both half-cycle
// paths because the clocks share a PLL.
reg        req_handoff  = 0;
reg        ack_handoff  = 0;
reg        line_done_handoff = 0;
reg [31:0] data_handoff = 0;
reg [31:0] line_handoff [0:3];

// One fully captured SDRAM burst, indexed as four machine longwords.  The
// tag includes the chip select.  Any accepted write invalidates it before
// the posted acknowledgement, preserving read-after-write ordering.
reg        line_valid = 0;
reg [26:4] line_tag = 0;
reg [31:0] line_data [0:3];
reg        fill_pending = 0;
reg        line_done_seen = 0;
wire       line_hit = line_valid && addr[26:4] == line_tag;
integer    line_i;

assign line_valid_o       = line_valid;
assign line_tag_o         = line_tag;
assign line_data_o        = {line_data[0], line_data[1], line_data[2], line_data[3]};
assign line_pending_o     = fill_pending;
assign line_pending_tag_o = r_addr[26:4];

always @(negedge clk_ram) begin
	req_handoff  <= req_tgl;
	ack_handoff  <= ack_tgl;
	line_done_handoff <= line_done_tgl;
	data_handoff <= hold;
	for (line_i = 0; line_i < 4; line_i = line_i + 1)
		line_handoff[line_i] <= line_hold[line_i];
end

always @(posedge clk_sys) begin
	ack <= 0;

	if (init) begin
		line_valid     <= 0;
		fill_pending   <= 0;
		line_done_seen <= line_done_handoff;
	end
	else if (line_done_handoff != line_done_seen) begin
		line_done_seen <= line_done_handoff;
		line_tag       <= r_addr[26:4];
		line_valid     <= 1;
		fill_pending   <= 0;
		for (line_i = 0; line_i < 4; line_i = line_i + 1)
			line_data[line_i] <= line_handoff[line_i];
	end

	if (!init && req && !busy && !ack && !fill_pending && !we && line_hit) begin
		// The request is still acknowledged synchronously, but needs no
		// clk_ram transaction.  Keeping busy low permits the next line beat
		// to be accepted as soon as the requester retires this ack.
		rdata <= line_data[addr[3:2]];
		ack   <= 1;
	end
	else if (!init && req && !busy && !ack && !fill_pending) begin
		r_addr  <= addr;
		r_wdata <= wdata;
		r_be    <= be;
		r_we    <= we;
		req_tgl <= ~req_tgl;
		busy    <= 1;
		posted  <= we;
		if (we) begin
			line_valid <= 0;
			ack <= 1;                  // posted: the drain is invisible from here
		end
		else begin
			line_valid   <= 0;
			fill_pending <= 1;
		end
	end

	if (busy && (ack_handoff != ack_seen)) begin
		ack_seen <= ack_handoff;
		busy     <= 0;
		posted   <= 0;
		if (!posted) begin
			rdata <= data_handoff;
			ack   <= 1;
		end
	end
end

// rd/wr are held for the whole access: the controller may still be walking
// back to its idle state when a request arrives, and it samples the request
// only there.  Completion is the RISING edge of ready — ready sits low
// before the very first access and through the ~122 us power-up sequence,
// so waiting on the edge cannot false-trigger or deadlock.
//
// rd_burst drops rd as soon as the first word arrives.  The controller remains
// in RDWAIT through the BL8 tail, so a held request cannot be recaptured while
// the remaining seven words are collected.
wire rd = busy_r && !r_we && !rd_burst;
wire wr = busy_r &&  r_we;

wire [1:0] rd_slot = r_addr[3:2] + rd_word[2:1];

always @(posedge clk_ram) begin
	ready_d  <= ready;

	if (rd_burst) begin
		if (!rd_word[0]) line_hold[rd_slot][31:16] <= dout;
		else begin
			line_hold[rd_slot][15:0] <= dout;
			if (rd_slot == r_addr[3:2]) begin
				hold    <= {line_hold[rd_slot][31:16], dout};
				// Release the requested longword immediately.  The rest of the
				// BL8 transfer continues into line_hold while fill_pending keeps
				// any following request from launching a second SDRAM command.
				ack_tgl <= ~ack_tgl;
			end
		end

		if (rd_word == 3'd7) begin
			rd_burst     <= 0;
			busy_r       <= 0;
			line_done_tgl <= ~line_done_tgl;
		end
		else rd_word <= rd_word + 1'b1;
	end
	else if (!busy_r) begin
		if (req_handoff != req_seen) begin
			req_seen <= req_handoff;
			acc      <= 0;
			rd_word  <= 0;
			busy_r   <= 1;
		end
	end
	else if (ready && !ready_d) begin
		if (!r_we) begin
			line_hold[r_addr[3:2]][31:16] <= dout;
			rd_word  <= 1;
			rd_burst <= 1;
		end
		else if (!acc) acc <= 1;     // second half of the write
		else begin
			busy_r  <= 0;
			ack_tgl <= ~ack_tgl;
		end
	end
end

sdram sdram
(
	.init      (init),
	.clk       (clk_ram),
	.SDRAM_EN  (1'b1),

	.SDRAM_DQ  (SDRAM_DQ),
	.SDRAM_A   (SDRAM_A),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_BA  (SDRAM_BA),
	.SDRAM_nCS (SDRAM_nCS),
	.SDRAM_nWE (SDRAM_nWE),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_CKE (SDRAM_CKE),
	.SDRAM_CLK (SDRAM_CLK),

	.sel       (1'b1),
	.addr      ({r_addr, acc}),          // word address; acc picks the half
	.dout      (dout),
	.din       (acc ? r_wdata[15:0] : r_wdata[31:16]),
	.wr        (wr),
	.bs        (acc ? r_be[1:0] : r_be[3:2]),
	.rd        (rd),
	.ready     (ready),
	.refresh   (refresh),

	.cpsel     (1'b0),
	.cpaddr    (26'd0),
	.cpdin     (16'd0),
	.cprd      (),
	.cpreq     (1'b0),
	.cpbusy    ()
);

endmodule
