//============================================================================
//  scsi_cache -- a per-target block cache between the SCSI engine and the
//  MiSTer HPS block-device channel (hps_io).
//
//  The engine (ncr53c96 behind iosb) moves one 512-byte sector at a time and
//  waits for the HPS on every one; a MiSTer Main round trip is ~100 us for a
//  read served from its read-ahead buffer and, for writes, whatever the SD
//  card takes -- images are opened O_SYNC, so a housekeeping pause on the
//  card (100s of ms) lands on every guest write.  This module sits on the
//  engine's block port and:
//
//    reads  - answers hits from block RAM at FPGA speed, fetches misses on
//             demand and then prefetches the following sectors while the
//             channel is otherwise idle (sequential I/O, which is what an
//             install or a file copy is, runs from the cache);
//    writes - accepts the sector into block RAM immediately (the engine sees
//             its ack in ~25 us) and flushes dirty sectors to the HPS in the
//             background, in order, whenever the channel is idle.
//
//  Each target owns one contiguous LBA window of N sectors (a ring with a
//  base LBA and valid/dirty bitmaps).  A request outside the window flushes
//  whatever is dirty and re-bases the window on the new LBA.  That is a
//  read-ahead / write-behind buffer around the current position rather than
//  a general cache, which is cheap in logic and exactly what the traffic
//  looks like; random access degrades to today's behaviour (one HPS round
//  trip per sector).
//
//  Platform-side transactions are serialized (hps_io serves one slot at a
//  time anyway): demand (an engine miss or an uncacheable request) first,
//  then dirty flushes, then prefetch.  The CD-ROM's TOC blob and CD-DA frame
//  windows (LBA >= 0x40000000, served by the Main fork with its own block
//  sizes) pass straight through, bus and all.
//
//  Coherency rules that matter:
//    - a read of a dirty sector is a hit and returns the new data;
//    - a window re-base waits for the channel to be idle and for every
//      dirty sector to be flushed, so a fetch never lands in a stale window;
//    - an engine write to the sector being flushed right now waits;
//    - a mount pulse for a slot whose image size changed invalidates the
//      slot (dirty data belonged to the old image); a pulse with the same
//      size is the top level's post-reset replay and keeps everything, so a
//      guest restart cannot lose the last writes;
//    - nreset only aborts an engine-side transaction in progress; tags,
//      dirty bits and the background flusher survive a machine reset.
//
//  One true dual-port M10K array of SECT0+SECT1+SECT2 sectors: port A is
//  the engine side, port B the HPS side.  Word addressing throughout (the
//  buses are 16 bits wide, big-endian byte pairs as hps_io delivers them).
//============================================================================

module scsi_cache
#(
	parameter SECT0    = 64,             // hard disk 0: 32 KB
	parameter SECT1    = 64,             // hard disk 1: 32 KB
	parameter SECT2    = 16,             // CD-ROM: 8 KB (2048-byte blocks = 4 sectors)
	parameter PF_DEPTH = 8               // sectors prefetched beyond a demand read
)
(
	input         clk,
	input         nreset,

	// ---- engine side (ncr53c96's block port, via iosb)
	input  [31:0] e_lba,
	input   [2:0] e_rd,
	input   [2:0] e_wr,
	output reg [2:0] e_ack,
	output reg [12:0] e_buff_addr,
	output reg [15:0] e_buff_dout,
	input  [15:0] e_buff_din,
	output reg    e_buff_wr,

	// ---- platform side (hps_io)
	output reg [31:0] p_lba,
	output reg  [2:0] p_rd,
	output reg  [2:0] p_wr,
	input   [2:0] p_ack,
	input  [12:0] p_buff_addr,
	input  [15:0] p_buff_dout,
	output [15:0] p_buff_din,
	input         p_buff_wr,

	// ---- mounts, as the engine sees them (one bit at a time, size valid then)
	input   [2:0] img_mounted,
	input  [63:0] img_size,

	// ---- statistics for the bring-up taps
	output reg [15:0] stat_hits,
	output reg [15:0] stat_misses
);

localparam integer NSECT = SECT0 + SECT1 + SECT2;
localparam integer AW    = 16;                       // NSECT*256 <= 65536 words

// slot geometry
function [7:0] slot_base(input [1:0] s);
	slot_base = (s == 2'd0) ? 8'd0 : (s == 2'd1) ? SECT0[7:0] : (SECT0 + SECT1);
endfunction
function [7:0] slot_size(input [1:0] s);
	slot_size = (s == 2'd0) ? SECT0[7:0] : (s == 2'd1) ? SECT1[7:0] : SECT2[7:0];
endfunction

//----------------------------------------------------------------------------
// tags: one window per slot
//----------------------------------------------------------------------------
reg [31:0] win_base [0:2];
reg        win_ok   [0:2];
reg [63:0] valid    [0:2];
reg [63:0] dirty    [0:2];
reg [63:0] size_r   [0:2];                          // image size the slot was mounted with
reg  [1:0] mounted;                                  // slot has an image (size != 0)

//----------------------------------------------------------------------------
// the sector store
//----------------------------------------------------------------------------
reg  [AW-1:0] addr_a;
reg  [15:0]   din_a;
reg           we_a;
wire [15:0]   q_a,    q_b;
// port B is the HPS side: address it combinationally from the platform bus so
// the store behaves like the real ncr_sbuf (a single read register).  During
// a fetch the platform's incoming word is written; during a flush the word is
// read out; passthrough does not touch the store.
wire [AW-1:0] addr_b = {c_sect, p_buff_addr[7:0]};
wire [15:0]   din_b  = p_buff_dout;
wire          we_b   = (cst == C_XFER) && !c_pt && !c_is_wr && p_buff_wr;

`ifdef VERILATOR
	reg [15:0] mem [0:NSECT*256-1];
	reg [15:0] q_a_r, q_b_r;
	always @(posedge clk) begin
		if (we_a) mem[addr_a] <= din_a;
		if (we_b) mem[addr_b] <= din_b;
		q_a_r <= mem[addr_a];
		q_b_r <= mem[addr_b];
	end
	assign q_a = q_a_r;
	assign q_b = q_b_r;
`else
	altsyncram ram
	(
		.clock0    (clk),
		.address_a (addr_a),
		.data_a    (din_a),
		.wren_a    (we_a),
		.q_a       (q_a),
		.address_b (addr_b),
		.data_b    (din_b),
		.wren_b    (we_b),
		.q_b       (q_b),
		.aclr0(1'b0), .aclr1(1'b0),
		.addressstall_a(1'b0), .addressstall_b(1'b0),
		.byteena_a(1'b1), .byteena_b(1'b1),
		.clock1(1'b1),
		.clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1),
		.eccstatus(),
		.rden_a(1'b1), .rden_b(1'b1)
	);
	defparam
		ram.numwords_a = NSECT*256,
		ram.widthad_a  = AW,
		ram.width_a    = 16,
		ram.width_byteena_a = 1,
		ram.numwords_b = NSECT*256,
		ram.widthad_b  = AW,
		ram.width_b    = 16,
		ram.width_byteena_b = 1,
		ram.address_reg_b = "CLOCK0",
		ram.clock_enable_input_a = "BYPASS",
		ram.clock_enable_input_b = "BYPASS",
		ram.clock_enable_output_a = "BYPASS",
		ram.clock_enable_output_b = "BYPASS",
		ram.indata_reg_b = "CLOCK0",
		ram.intended_device_family = "Cyclone V",
		ram.lpm_type = "altsyncram",
		ram.operation_mode = "BIDIR_DUAL_PORT",
		ram.outdata_aclr_a = "NONE",
		ram.outdata_aclr_b = "NONE",
		ram.outdata_reg_a = "UNREGISTERED",
		ram.outdata_reg_b = "UNREGISTERED",
		ram.power_up_uninitialized = "FALSE",
		ram.ram_block_type = "M10K",
		ram.read_during_write_mode_mixed_ports = "DONT_CARE",
		ram.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		ram.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		ram.wrcontrol_wraddress_reg_b = "CLOCK0";
`endif

//----------------------------------------------------------------------------
// platform channel: one transaction at a time
//----------------------------------------------------------------------------
localparam [2:0] C_IDLE = 3'd0, C_REQ = 3'd1, C_XFER = 3'd2, C_PT = 3'd3;
reg  [2:0] cst;
reg        c_is_wr;                  // FLUSH (or passthrough write)
reg        c_pt;                     // passthrough: buses forwarded to the engine
reg  [1:0] c_slot;
reg  [7:0] c_sect;                   // store sector index (slot base + window index)
reg  [5:0] c_idx;                    // window index
reg [31:0] c_base;                   // window base this transaction was issued for
reg  [2:0] p_ack_d;
wire [2:0] p_ack_fall = p_ack_d & ~p_ack;
wire       ch_idle  = (cst == C_IDLE);
wire       ch_flush = (cst != C_IDLE) && c_is_wr && !c_pt;

// platform-side buffer bus: flush data comes from port B, passthrough from the engine
reg [15:0] pt_din;
assign p_buff_din = c_pt ? e_buff_din : q_b;

//----------------------------------------------------------------------------
// engine side
//----------------------------------------------------------------------------
localparam [3:0] E_IDLE = 4'd0, E_DECIDE = 4'd1, E_FLUSHALL = 4'd2, E_REBASE = 4'd3,
                 E_FETCH = 4'd4, E_RD_A = 4'd5, E_RD_B = 4'd6, E_WR_A = 4'd7,
                 E_WR_B = 4'd8, E_WR_C = 4'd9, E_DONE = 4'd10, E_PT = 4'd11,
                 E_RD_C = 4'd12;
reg  [3:0] est;
reg  [1:0] r_slot;
reg [31:0] r_lba;
reg        r_wr;
reg  [7:0] r_word;                   // 0..255 (bit 8 = done)
reg        r_word_done;
wire [31:0] r_off = r_lba - win_base[r_slot];
wire        r_inwin = win_ok[r_slot] && (r_off < {24'd0, slot_size(r_slot)});
wire  [5:0] r_idx = r_off[5:0];
wire        r_pt = (r_slot == 2'd2) && (r_lba[31:30] != 2'b00);   // TOC blob / CD-DA windows
wire        r_hit = r_inwin && valid[r_slot][r_idx];
wire        r_dirty_any = |dirty[r_slot];
wire        r_flushing_me = ch_flush && (c_slot == r_slot) && (c_idx == r_idx);

// demand for the channel from the engine side
reg        dem_req;                  // engine wants a platform transaction now
reg        dem_wr;                   // ...a flush-all step is a write
reg        dem_pt;
reg  [5:0] dem_idx;

// prefetch bookkeeping
reg  [1:0] pf_slot;
reg  [5:0] pf_next;
reg  [3:0] pf_left;

// flush scan
reg  [1:0] fl_slot;
reg  [5:0] fl_idx;

integer i;

always @(posedge clk) begin
	p_ack_d <= p_ack;
	we_a <= 0;
	e_buff_wr <= 0;

	//------------------------------------------------ mounts
	for (i = 0; i < 3; i = i + 1)
		if (img_mounted[i]) begin
			if (img_size != size_r[i]) begin        // a different image: forget everything
				valid[i]  <= 64'd0;
				dirty[i]  <= 64'd0;
				win_ok[i] <= 1'b0;
				size_r[i] <= img_size;
			end
		end

	//------------------------------------------------ platform channel
	case (cst)
	C_IDLE: begin
		p_rd <= 3'b000; p_wr <= 3'b000; c_pt <= 0;
		if (dem_req) begin
			dem_req <= 0;                            // accepted: drop the level
			c_slot <= r_slot; c_is_wr <= dem_wr; c_pt <= dem_pt;
			c_idx  <= dem_idx;
			c_base <= win_base[r_slot];
			c_sect <= slot_base(r_slot) + {2'd0, dem_idx};
			p_lba  <= dem_pt ? r_lba : (win_base[r_slot] + {26'd0, dem_idx});
			if (dem_wr) p_wr[r_slot] <= 1; else p_rd[r_slot] <= 1;
			cst <= C_REQ;
		end
		else if (|dirty[fl_slot]) begin              // background flush, in order
			if (dirty[fl_slot][fl_idx]) begin
				c_slot <= fl_slot; c_is_wr <= 1; c_pt <= 0;
				c_idx  <= fl_idx;
				c_base <= win_base[fl_slot];
				c_sect <= slot_base(fl_slot) + {2'd0, fl_idx};
				p_lba  <= win_base[fl_slot] + {26'd0, fl_idx};
				p_wr[fl_slot] <= 1;
				cst <= C_REQ;
			end
			else fl_idx <= fl_idx + 1'b1;            // scan on (wraps inside the window)
		end
		else if (|dirty[0] | |dirty[1] | |dirty[2]) begin
			fl_slot <= fl_slot + 1'b1;               // another slot has the dirt
			fl_idx  <= 0;
		end
		else if (pf_left != 0 && win_ok[pf_slot] && mounted[pf_slot] &&
		         ({2'd0, pf_next} < {2'd0, slot_size(pf_slot)}) && !valid[pf_slot][pf_next]) begin
			c_slot <= pf_slot; c_is_wr <= 0; c_pt <= 0;
			c_idx  <= pf_next;
			c_base <= win_base[pf_slot];
			c_sect <= slot_base(pf_slot) + {2'd0, pf_next};
			p_lba  <= win_base[pf_slot] + {26'd0, pf_next};
			p_rd[pf_slot] <= 1;
			pf_next <= pf_next + 1'b1;
			pf_left <= pf_left - 1'b1;
			cst <= C_REQ;
		end
		else if (pf_left != 0) pf_left <= 0;         // window edge or already valid: stop
	end
	C_REQ: begin
		if (p_ack[c_slot]) begin
			p_rd <= 3'b000; p_wr <= 3'b000;
			cst <= C_XFER;
		end
	end
	C_XFER: begin
		// port B (addr_b/din_b/we_b) is driven combinationally above; a fetch
		// writes the incoming word, a flush reads q_b out to p_buff_din
		if (p_ack_fall[c_slot]) begin
			if (!c_pt) begin
				if (c_is_wr) dirty[c_slot][c_idx] <= 1'b0;
				else         valid[c_slot][c_idx] <= 1'b1;
			end
			cst <= C_IDLE;
		end
	end
	default: cst <= C_IDLE;
	endcase

	//------------------------------------------------ engine side
	case (est)
	E_IDLE: begin
		e_ack <= 3'b000;
		if (e_rd[0] | e_wr[0]) begin r_slot <= 2'd0; r_wr <= e_wr[0]; r_lba <= e_lba; est <= E_DECIDE; end
		else if (e_rd[1] | e_wr[1]) begin r_slot <= 2'd1; r_wr <= e_wr[1]; r_lba <= e_lba; est <= E_DECIDE; end
		else if (e_rd[2] | e_wr[2]) begin r_slot <= 2'd2; r_wr <= e_wr[2]; r_lba <= e_lba; est <= E_DECIDE; end
	end
	E_DECIDE: begin
		if (r_pt) begin                              // uncacheable: hand the buses over
			if (!dem_req) begin
				dem_req <= 1; dem_wr <= r_wr; dem_pt <= 1; dem_idx <= 0;
				est <= E_PT;
			end
		end
		else if (!r_inwin) begin
			// outside the window: settle the dirt, then re-base on this LBA
			if (r_dirty_any) est <= E_FLUSHALL;
			else if (ch_idle) est <= E_REBASE;
		end
		else if (r_wr) begin
			if (!r_flushing_me) begin
				e_ack[r_slot] <= 1;
				r_word <= 0;
				e_buff_addr <= 13'd0;
				est <= E_WR_A;
			end
		end
		else if (r_hit) begin
			stat_hits <= stat_hits + 1'b1;
			e_ack[r_slot] <= 1;
			r_word <= 0;
			addr_a <= {slot_base(r_slot) + {2'd0, r_idx}, 8'd0};
			est <= E_RD_A;
		end
		else if (!dem_req) begin                     // miss: fetch on demand, then serve
			stat_misses <= stat_misses + 1'b1;
			dem_req <= 1; dem_wr <= 0; dem_pt <= 0; dem_idx <= r_idx;
			est <= E_FETCH;
		end
	end
	E_FLUSHALL: begin
		// the background flusher does the work; wait until this slot is clean
		if (!r_dirty_any && ch_idle) est <= E_REBASE;
	end
	E_REBASE: begin
		win_base[r_slot] <= r_lba;
		win_ok[r_slot]   <= 1'b1;
		valid[r_slot]    <= 64'd0;
		dirty[r_slot]    <= 64'd0;
		est <= E_DECIDE;
	end
	E_FETCH: begin
		// the demand fetch is a held level until the channel takes it; when the
		// sector is valid it is a hit and we serve it
		if (r_hit) est <= E_DECIDE;
	end
	// ---- read hit: three cycles per word -- port A address, the RAM's
	// registered read, then the word onto the engine's bus
	E_RD_A: begin
		addr_a <= {slot_base(r_slot) + {2'd0, r_idx}, r_word};
		est <= E_RD_B;
	end
	E_RD_B: est <= E_RD_C;
	E_RD_C: begin
		e_buff_addr <= {5'd0, r_word};
		e_buff_dout <= q_a;
		e_buff_wr   <= 1;
		if (r_word == 8'd255) est <= E_DONE;
		else begin r_word <= r_word + 1'b1; est <= E_RD_A; end
	end
	// ---- write accept: address, let the engine's registered read settle, sample
	E_WR_A: begin
		e_buff_addr <= {5'd0, r_word};
		est <= E_WR_B;
	end
	E_WR_B: est <= E_WR_C;
	E_WR_C: begin
		addr_a <= {slot_base(r_slot) + {2'd0, r_idx}, r_word};
		din_a  <= e_buff_din;
		we_a   <= 1;
		if (r_word == 8'd255) begin
			valid[r_slot][r_idx] <= 1'b1;
			dirty[r_slot][r_idx] <= 1'b1;
			est <= E_DONE;
		end
		else begin r_word <= r_word + 1'b1; est <= E_WR_A; end
	end
	E_DONE: begin
		e_ack <= 3'b000;
		if (!r_wr) begin                             // arm the prefetcher behind a read
			pf_slot <= r_slot;
			pf_next <= r_idx + 1'b1;
			pf_left <= PF_DEPTH[3:0];
		end
		est <= E_IDLE;
	end
	E_PT: begin
		// wait until the channel is actually running THIS passthrough, then
		// forward the buses; complete when its ack falls
		if ((cst == C_XFER) && c_pt) begin
			e_ack[r_slot] <= p_ack[r_slot];
			e_buff_addr   <= p_buff_addr;
			e_buff_dout   <= p_buff_dout;
			e_buff_wr     <= p_buff_wr;
			if (p_ack_fall[r_slot]) begin
				e_ack <= 3'b000;
				est <= E_IDLE;
			end
		end
	end
	default: est <= E_IDLE;
	endcase

	//------------------------------------------------ reset: engine side only
	if (!nreset) begin
		est <= E_IDLE; e_ack <= 3'b000;
		pf_left <= 0;
	end
end

// mount state and power-up values
initial begin
	cst = C_IDLE; est = E_IDLE; e_ack = 0; p_rd = 0; p_wr = 0; c_pt = 0;
	dem_req = 0; pf_left = 0; pf_slot = 0; pf_next = 0; fl_slot = 0; fl_idx = 0;
	stat_hits = 0; stat_misses = 0; mounted = 0; e_buff_wr = 0; we_a = 0;
	for (i = 0; i < 3; i = i + 1) begin
		win_base[i] = 0; win_ok[i] = 0; valid[i] = 0; dirty[i] = 0; size_r[i] = 0;
	end
end
always @(posedge clk)
	for (i = 0; i < 3; i = i + 1)
		if (img_mounted[i]) mounted[i] <= (img_size != 0);

endmodule
