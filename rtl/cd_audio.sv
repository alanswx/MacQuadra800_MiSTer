// cd_audio.sv - AppleCD audio playback engine for the SCSI CD-ROM target.
//
// Instantiated INSIDE scsi.v (CDROM instance only) so it shares the target's
// HPS io channel; the only signals leaving the SCSI hierarchy are the two
// sound outputs. Byte behavior follows MAME's nscsi_cdrom_apple_device
// (../mame src/devices/bus/nscsi/cd.cpp) — the same oracle the target's
// INQUIRY / 0xC1 TOC / sense already match. The HPS side of the contract
// (TOC blob + raw-audio block windows) is documented in
// Main_MiSTer/support/maclc/maclc_cd.h and docs/plan_cd_audio_rtl.md.
//
// Structure (strict single-driver: each always block owns its registers):
//   MAIN FSM  - TOC blob fetch + parse (MCDA magic, else synthesized
//               single-track fallback: stock Main / Verilator / flat image),
//               0xC1 response precompute (99 descriptors, last repeated, per
//               MAME), command execution (SEARCH/PLAY/PAUSE/STOP/SCAN),
//               periodic track/MSF refresh for AUDIO STATUS / READ Q SUBCODE,
//               and the playhead bookkeeping.
//   FETCH FSM - streams 2352-byte frames (5 blocks) from the audio window
//               into a 2-frame ping-pong buffer while playing.
//   SAMPLE    - 44.1 kHz fractional cadence, 16-bit LE stereo, one frame
//               consumed per 588 stereo samples.
//
// Channel sharing: scsi.v raises ch_grant only while the target is bus-idle
// with no data io pending; the MAIN FSM has priority over FETCH via fr_ok.
// A data READ stops playback outright (oracle behavior), so contention is
// self-limiting.

module cd_audio #(
	parameter CLK_HZ = 32'd32_500_000   // clk rate, for the 44.1 kHz cadence
)(
	input             clk,
	input             rst,       // SYSTEM reset only (survives SCSI bus resets)
	input             bus_rst,   // SCSI bus reset: stops playback, TOC/engine state SURVIVES

	input             mounted,
	input             img_mounted,      // mount pulse: (re)acquire the TOC
	input      [31:0] img_blocks,       // 512-byte blocks of the data region

	// audio-family CDB, latched by scsi.v (status GOOD already returned)
	input             cmd_stb,
	input       [7:0] cmd_op,
	input       [7:0] cdb1, cdb2, cdb3, cdb4, cdb5, cdb6, cdb7, cdb8, cdb9,
	input             read_stb,         // data READ latched: stop playback
	input             eject_stb,

	// CD Audio Control page 0x0E output ports 0/1 (MODE SELECT-writable in
	// scsi.v — the AppleCD player's volume slider). channel: 0x01 = left
	// source, 0x02 = right, anything else mutes the port (Snow
	// make_out_sample); volume: linear 0..255 PCM scale.
	input       [7:0] ap_ch0, ap_vol0,
	input       [7:0] ap_ch1, ap_vol1,

	// shared HPS io channel
	input             ch_grant,
	output            ca_io_active,     // owns the channel (request/ack window)
	output            ca_io_rd,
	output     [31:0] ca_io_lba,
	input             io_ack,
	input       [7:0] sd_buff_addr,
	input       [4:0] sd_buff_addr_hi,  // hps_io addr[12:8]: whole-frame bursts
	input      [15:0] sd_buff_dout,
	input             sd_buff_wr,

	// live registers for AUDIO STATUS (0xCC) / READ Q SUBCODE (0xC2)
	output reg  [7:0] ast_code,         // 0 play, 1 paused, 3 end, 5 idle
	output reg  [7:0] cur_ctrl,
	output reg  [7:0] cur_trk,               // BINARY, 1-based (dialect switch:
	                                         // vendor 0xC2/0xCC serve bin2bcd()
	                                         // of these at the scsi.v mux; the
	                                         // standard 0x42 serves them raw)
	output reg  [7:0] abs_m, abs_s, abs_f,   // BINARY, no +150
	output reg  [7:0] rel_m, rel_s, rel_f,

	// the blob header has been parsed since the last mount pulse (the
	// response tables the RTL used to build from it now come from Main)
	output reg        toc_ready,

	// 1 = the mounted disc has NO data track (every track's control bit 2
	// clear). Data READs against such a disc must CHECK with ILLEGAL
	// REQUEST/0x64 "illegal mode for this track" (BlueSCSI/Snow oracles) —
	// the Audio CD Access extension RELIES on that failure to classify the
	// disc; serving audio bytes as data bombs the Finder (2026-07-20,
	// system error 10 during the Audio CD desktop mount).
	output reg        disc_audio,

	output reg signed [15:0] snd_l,
	output reg signed [15:0] snd_r,

	// JTAG probe feed (CDA0): TOC/engine state, composed here so the whole
	// hierarchy passes one opaque word.
	//   [0]=mounted [1]=toc_ready [2]=toc_valid [9:3]=n_tracks
	//   [14:10]=mst [16:15]=pstate [18:17]=fst
	//   [26:19]=toc_fetch_cnt (M_ACQ_REQ fires, wraps)
	//   [31:27]=frame_fetch_cnt[4:0] (F_REQ fires, wraps)
	output     [31:0] dbg_cda0,

	// Underrun probe word (JTAG CDUR): [31:16]=starvation entries (wraps),
	// [15:0]=starved clk/256 (7.9 us units at 32.5 MHz clk).
	output     [31:0] dbg_cdur
);

// HPS window contract (Main_MiSTer support/maclc/maclc_cd.h)
// Disc LBAs are 20 bits: 99:59:74 is 449,999 sectors, a 700 MB data disc
// 358,400 blocks.  Only the two platform-window addresses (TOC_BLK /
// AUDIO_BLK + lba) are 32 bits.  Thirteen 32-bit registers and their input
// muxes were the second-largest LUT cost of this module (2026-09-08).
localparam integer LBW = 20;
localparam [31:0] TOC_BLK   = 32'h7FFF_0000;
localparam [31:0] AUDIO_BLK = 32'h4000_0000;

// ============================================================================
// RAMs (proven scsi_dpram primitive from scsi.v)
// ============================================================================
// raw MCDA blob: 1 KB as 512 x 16 (port a = HPS stream, port b = FSM reads)
reg          blob_cap;
reg          blob_blk;
reg  [8:0]   blob_ra;
wire [15:0]  blob_q_ram;
cd_sdp #(.DW(16), .AW(9)) blob_ram (
	.clock(clk),
	.waddr({blob_blk, sd_buff_addr}), .wdata(sd_buff_dout),
	.wr(blob_cap && sd_buff_wr),
	.raddr(blob_ra), .q(blob_q_ram)
);
// cd_sdp is a ONE-cycle-read RAM (raddr in cycle N -> q in cycle N+1) and
// every blob reader is aligned to that: M_TRK_RD / M_CTRK_RD / M_REF_SCAN
// were 1-cycle-correct as written, and M_HDR_RD is aligned below (HW
// 2026-07-17: it was the one reader coded for a 2-cycle pipeline, so the
// MCDA magic compared against word 1 and toc_valid could never set. An
// interim global +1 register stage fixed the header but skewed the three
// track readers — garbage start LBAs ground the MSF divider for seconds
// per track and toc_ready never rose. One uniform 1-cycle contract now.)
wire [15:0] blob_q = blob_q_ram;
wire [7:0] blob_b0 = blob_q[7:0];      // even byte (LE lane order on FPGA)
wire [7:0] blob_b1 = blob_q[15:8];

// frame ping-pong: 2 x 2048 x 16 (1176 words = one 2352 B frame per half).
// Each half is filled by ONE whole-frame HPS transaction (Main forces
// blksz=2352 for the AUDIO window, PSX-style): a single sd_ack window with
// sd_buff_addr streaming 0..1175 continuously — the wide address bits come
// in via sd_buff_addr_hi. The old 5x512 view cost five ~2.8 ms round-trips
// per 13.3 ms frame = chronic ~4.5% starvation (CDUR-measured 2026-07-28).
reg         fr_cap;
reg         fr_half_w;
reg [11:0]  frame_ra;
wire [15:0] frame_q;
wire [10:0] fr_wword = {sd_buff_addr_hi[2:0], sd_buff_addr};
cd_sdp #(.DW(16), .AW(12)) frame_ram (
	.clock(clk),
	.waddr({fr_half_w, fr_wword}), .wdata(sd_buff_dout),
	.wr(fr_cap && sd_buff_wr),
	.raddr(frame_ra), .q(frame_q)
);

// ============================================================================
// helpers
// ============================================================================
function [7:0] bcd2bin;
	input [7:0] b;
	bcd2bin = {4'd0, b[7:4]} * 8'd10 + {4'd0, b[3:0]};
endfunction
function [31:0] msf2lba;               // BCD M/S/F -> LBA
	input [7:0] m, s, f;
	msf2lba = {24'd0, bcd2bin(m)} * 32'd4500
	        + {24'd0, bcd2bin(s)} * 32'd75
	        + {24'd0, bcd2bin(f)};
endfunction
function [31:0] msf2lba_std;           // BINARY M/S/F (+150 space) -> disc LBA
	input [7:0] m, s, f;
	reg [31:0] v;
	begin
		v = {24'd0, m} * 32'd4500 + {24'd0, s} * 32'd75 + {24'd0, f};
		msf2lba_std = (v >= 32'd150) ? v - 32'd150 : 32'd0;
	end
endfunction

// ============================================================================
// io-channel request mux (each FSM owns its own request registers)
// ============================================================================
reg         toc_rd, toc_act;
reg  [31:0] toc_lba;
reg         fr_rd, fr_act;
reg  [31:0] fr_lba;
assign ca_io_rd     = toc_rd | fr_rd;
assign ca_io_lba    = toc_act ? toc_lba : fr_lba;
assign ca_io_active = toc_act | fr_act;

reg old_ack;
always @(posedge clk) old_ack <= io_ack;
wire ack_fall = old_ack & ~io_ack;

// ============================================================================
// playback state (owned by MAIN FSM) + sample-engine handshake wires
// ============================================================================
localparam ST_IDLE = 2'd0, ST_PLAY = 2'd1, ST_PAUSE = 2'd2, ST_END = 2'd3;
reg  [1:0]  pstate;
reg [LBW-1:0]  cur_lba, stop_lba;
reg         flush;                     // 1-clk: position changed, requeue audio
wire        frame_done;                // sample engine finished a frame

always @(*) begin
	case (pstate)
	ST_PLAY:  ast_code = 8'h00;
	ST_PAUSE: ast_code = 8'h01;
	ST_END:   ast_code = 8'h03;
	default:  ast_code = 8'h05;
	endcase
end

// ============================================================================
// MAIN FSM
// ============================================================================
localparam [4:0]
	M_IDLE     = 5'd0,
	M_ACQ_REQ  = 5'd1,  M_ACQ_WAIT = 5'd2,
	M_HDR_RD   = 5'd3,                      // stream words 0..6 into hdr regs
	M_CMD      = 5'd11,                     // decode a pending command
	M_CTRK_RD  = 5'd12,                     // track-mode: read start(k), start(k+1)
	M_APPLY    = 5'd13,
	M_REF_SCAN = 5'd14,                     // find track containing cur_lba
	M_REF_DIVA = 5'd15, M_REF_DIVR = 5'd16,
	M_SCAN_GO  = 5'd28;                     // 0xCD standard-form audio scan
reg [4:0] mst;

// 0xCD AUDIO SCAN (AppleCD player FF/RW, standard-driver form: cdb1
// 0x00=FF / 0x10=RW, MSF hex in cdb3-5 — BlueSCSI documents the format
// but leaves it unimplemented; the dynamics here are ours). While
// scan_x: the playhead advances ±8 sectors per consumed frame (chirping
// ~8x scan). Cleared by ANY other transport command, playback stop, or
// reaching an end. Mishandling this (vendor LBA-form decode → pause)
// wedged the PLAYER's state machine: it waits for position movement
// that never comes and stops issuing commands (watch capture run 2).
reg        scan_x;
reg        scan_dir;                        // 1 = rewind

reg  [2:0] step;                        // word-stream step within a state
reg [LBW-1:0] div_v;                       // shared iterative M/S/F divider
reg  [6:0] div_m, div_s;
// One step of the LBA -> M/S/F divider, computed ONCE: every state that
// divides loads div_v/div_m/div_s, then repeats "if (!div_done) step" until
// done.  The step used to be written out in six states, which synthesised
// six pairs of 32-bit comparators and subtractors (2026-09-08).
wire        div_ge4500 = (div_v >= 32'd4500) && (div_m != 7'd99);
wire        div_ge75   = (div_v >= 32'd75);
wire        div_done   = !div_ge4500 && !div_ge75;
wire [LBW-1:0] div_v_next = div_ge4500 ? div_v - 32'd4500 : div_v - 32'd75;
wire  [6:0] div_m_next = div_m + {6'd0, div_ge4500};
wire  [6:0] div_s_next = div_s + {6'd0, !div_ge4500};

reg        toc_valid;
reg  [7:0] blob_ver;           // blob byte 4: 2 carries the has-data flag at byte 12
reg  [6:0] n_tracks;

// probe counters (CDA0): how many blob-block fetches / audio-frame fetches
// actually fired — distinguishes "fetch never ran" from "ran, parse failed".
reg  [7:0] dbg_toc_fetch_cnt = 8'd0;
reg  [4:0] dbg_fr_fetch_cnt  = 5'd0;
reg [LBW-1:0] leadout_lba;

reg  [7:0] c_op, c_1, c_2, c_3, c_4, c_5, c_6, c_7, c_8, c_9;
reg        cmd_pend;
reg [LBW-1:0] c_addr;                      // resolved target address
// the CDB's 32-bit LBA form, clamped: anything past 20 bits is beyond any
// disc, and lands in the beyond-lead-out handling like a real drive's
wire [LBW-1:0] cdb_lba = (|{c_2, c_3[7:4]}) ? {LBW{1'b1}} : {c_3[3:0], c_4, c_5};
reg [LBW-1:0] c_next;                      // start of following track (track mode)
// PLAY AUDIO(10)/(12) "from current position" sentinel (BlueSCSI 2551)
wire       play_lba_ff = (c_2 == 8'hFF) && (c_3 == 8'hFF) &&
                         (c_4 == 8'hFF) && (c_5 == 8'hFF);
reg  [6:0] c_trk;                       // 0-based requested track
reg  [6:0] c_trk2;                      // 0-based index whose START bounds the play
                                        // (vendor: c_trk+1; 0x48: end-track+1)

reg [LBW-1:0] ref_abs, ref_rel;
reg [LBW-1:0] scan_start;
reg  [6:0] scan_idx, scan_best_trk;
reg  [7:0] scan_ctrl_c, scan_best_ctrl;
reg [LBW-1:0] scan_best_start;
reg  [6:0] refm_hold, refs_hold;
reg [15:0] ref_cnt;


always @(posedge clk) begin
	if (rst) begin
		mst <= M_IDLE; step <= 0;
		disc_audio <= 0; blob_ver <= 0;
		blob_cap <= 0; blob_blk <= 0; blob_ra <= 0;
		toc_rd <= 0; toc_act <= 0; toc_lba <= 0;
		toc_valid <= 0; toc_ready <= 0; n_tracks <= 7'd1; leadout_lba <= 0;
		cmd_pend <= 0; pstate <= ST_IDLE; cur_lba <= 0; stop_lba <= 0; flush <= 0;
		cur_ctrl <= 8'h14; cur_trk <= 8'h01;
		scan_x <= 1'b0; scan_dir <= 1'b0;
		abs_m <= 0; abs_s <= 0; abs_f <= 0; rel_m <= 0; rel_s <= 0; rel_f <= 0;
		ref_cnt <= 0;
	end else begin
		flush   <= 1'b0;

		// command capture: never lost, executed from M_IDLE
		if (cmd_stb) begin
			c_op <= cmd_op; c_1 <= cdb1; c_2 <= cdb2; c_3 <= cdb3; c_4 <= cdb4;
			c_5 <= cdb5; c_6 <= cdb6; c_7 <= cdb7; c_8 <= cdb8; c_9 <= cdb9;
			cmd_pend <= 1'b1;
		end
		// oracle: a data READ (or eject / unmount) stops playback
		if ((read_stb || eject_stb || bus_rst || !mounted) && pstate != ST_IDLE) begin
			pstate <= ST_IDLE;
			scan_x <= 1'b0;
		end

		// playhead advance, one frame at a time (±8 while 0xCD scanning)
		if (frame_done) begin
			if (scan_x && scan_dir) begin
				// rewind: clamp at disc start, keep scanning in place
				cur_lba <= (cur_lba > 32'd8) ? cur_lba - 32'd8 : 32'd0;
			end
			else if (cur_lba + (scan_x ? 32'd8 : 32'd1) >= stop_lba) begin
				cur_lba <= stop_lba;
				pstate  <= ST_END;
				scan_x  <= 1'b0;
			end
			else cur_lba <= cur_lba + (scan_x ? 32'd8 : 32'd1);
		end

		case (mst)
		// -------------------------------------------------- idle / dispatch
		M_IDLE: begin
			blob_cap <= 1'b0;
			if (img_mounted && mounted) begin
				toc_ready <= 1'b0; toc_valid <= 1'b0; blob_blk <= 1'b0;
				pstate <= ST_IDLE;
				mst <= M_ACQ_REQ;
			end
			else if (mounted && !toc_ready) begin
				// Need-driven (re)acquisition — HW root cause 2026-07-17, probe
				// CDA0 showed mounted=1/toc_ready=0/toc_fetches=1/mst=IDLE: the
				// PRAM late-load AUTO-RESTART resets this FSM mid-acquisition;
				// the scsi.v mounted latch survives the restart but the
				// img_mounted PULSE never repeats, so the pulse-driven trigger
				// above never re-fires and every 0xC1 serves a zeroed TOC ("one
				// track", PLAY rejected). Also covers the first-mount ordering
				// fragility (pulse vs latch update). Terminates: acquisition
				// always ends in toc_ready=1 (real blob or synthesized).
				toc_valid <= 1'b0; blob_blk <= 1'b0;
				mst <= M_ACQ_REQ;
			end
			else if (cmd_pend) begin
				cmd_pend <= 1'b0;
				mst <= M_CMD;
			end
			else begin
				ref_cnt <= ref_cnt + 16'd1;
				if ((&ref_cnt) && toc_ready && mounted) begin
					ref_abs <= cur_lba;
					scan_idx <= 0; scan_best_trk <= 0;
					scan_best_start <= 0; scan_best_ctrl <= 8'h14;
					step <= 0;
					mst <= toc_valid ? M_REF_SCAN : M_REF_DIVA;
				end
			end
		end

		// -------------------------------------------------- TOC blob fetch
		M_ACQ_REQ:
			// unmount escape: ca_grant requires mounted, so an eject here would
			// park the engine forever (HW 2026-07-17: guest 0xC0 mid-session).
			if (!mounted) mst <= M_IDLE;
			else if (ch_grant && !fr_act) begin
			toc_lba  <= TOC_BLK + {31'd0, blob_blk};
			toc_rd   <= 1'b1;
			toc_act  <= 1'b1;
			blob_cap <= 1'b1;
			dbg_toc_fetch_cnt <= dbg_toc_fetch_cnt + 8'd1;
			mst <= M_ACQ_WAIT;
		end
		M_ACQ_WAIT: begin
			if (!mounted && !toc_act) begin toc_rd <= 1'b0; blob_cap <= 1'b0; mst <= M_IDLE; end
			if (io_ack) toc_rd <= 1'b0;
			if (ack_fall && toc_act) begin
				toc_act  <= 1'b0;
				blob_cap <= 1'b0;
				if (!blob_blk) begin blob_blk <= 1'b1; mst <= M_ACQ_REQ; end
				else begin blob_ra <= 9'd0; step <= 0; mst <= M_HDR_RD; end
			end
		end

		// ------------------------------------------ header words 0..5 stream
		// 1-cycle RAM: ra=0 presented on entry, so word k is in blob_q at
		// step k+1 (ra advances every cycle). Same contract as M_TRK_RD.
		M_HDR_RD: begin
			blob_ra <= blob_ra + 9'd1;
			step <= step + 3'd1;
			case (step)
			3'd1: toc_valid <= (blob_b0 == "M") && (blob_b1 == "C");       // word0
			3'd2: if (!((blob_b0 == "D") && (blob_b1 == "A"))) toc_valid <= 1'b0; // word1
			3'd3: blob_ver <= blob_b0;                                     // word2: version/first
			3'd4: begin                                                    // word3: {data_trk, last}
				if (toc_valid)
					n_tracks <= (blob_b0 == 8'd0) ? 7'd1 :
					            (blob_b0 > 8'd99) ? 7'd99 : blob_b0[6:0];
			end
			3'd5: if (toc_valid) leadout_lba[15:0]  <= blob_q;             // word4
			3'd6: begin                                                    // word5
				if (toc_valid) leadout_lba[LBW-1:16] <= blob_q[LBW-17:0];
				else begin
					n_tracks    <= 7'd1;
					leadout_lba <= img_blocks[LBW+1:2];                    // 2048-blocks
				end
			end
			default: begin                                                 // word6: blob v2 flags
				// bit 0 = the disc has a data track; a v1 blob (no flag) can
				// only come from a Main the ncr53c96 probe has already refused
				disc_audio <= toc_valid && (blob_ver >= 8'd2) && !blob_b0[0];
				toc_ready  <= 1'b1;
				step <= 0;
				mst <= M_IDLE;
			end
			endcase
		end

		// -------------------------------------------------- command execute
		M_CMD: begin
			mst <= M_IDLE;   // default; overridden below
			// any transport command other than the scan itself ends a scan
			if (c_op != 8'hcd) scan_x <= 1'b0;
			case (c_op)
			8'hca: begin                                   // AUDIO PAUSE
				if (c_1 == 8'h10) begin
					if (pstate == ST_PLAY) pstate <= ST_PAUSE;
				end else if (pstate == ST_PAUSE) pstate <= ST_PLAY;
			end
			8'hcd: begin                                   // AUDIO SCAN (FF/RW)
				// STANDARD decode ONLY (Snow/[PIONEER]: form in cdb9[7:6],
				// LBA=cdb2-5 / MSF binary=cdb3-5 / track=cdb5; direction
				// cdb1: 0x00=FF, 0x10=RW per the observed driver+BlueSCSI).
				// The 8004-identity driver sends nothing else; routing this
				// into the vendor arm read BCD MSF from bytes 5-7 — track
				// 4's scan {MSF 18,14,19}@3-5 became BCD 19:00:00@5-7 =
				// seek into track 2 = the "random track" FF/RW (run 4).
				case (c_9[7:6])
				2'b00:   c_addr <= cdb_lba;       // LBA form
				2'b01:   c_addr <= msf2lba_std(c_3, c_4, c_5); // MSF form
				default: c_addr <= cur_lba;  // track form unobserved: v1 =
				                             // scan from current position
				endcase
				mst <= M_SCAN_GO;
			end
			8'hc8, 8'hc9, 8'hcb: begin                     // vendor SEARCH/PLAY/STOP
				case (c_9[7:6])
				2'b01: begin                               // MSF (C9: bytes 3..5, else 5..7)
					c_addr <= (c_op == 8'hc9) ? msf2lba(c_3, c_4, c_5)
					                          : msf2lba(c_5, c_6, c_7);
					mst <= M_APPLY;
				end
				2'b10: begin                               // track number (BCD byte 5)
					if (bcd2bin(c_5) == 8'd0) begin
						// track 0: stop (oracle: PLAY/SEARCH track 0 stops)
						if (c_op != 8'hcb) pstate <= ST_IDLE;
					end else begin
						c_trk <= (bcd2bin(c_5) - 8'd1 < 8'd99) ? bcd2bin(c_5) - 8'd1 : 7'd98;
						c_trk2 <= (bcd2bin(c_5) < 8'd99) ? bcd2bin(c_5) : 7'd99;
						step  <= 0;
						mst   <= toc_valid ? M_CTRK_RD : M_APPLY;
						if (!toc_valid) begin c_addr <= 32'd0; c_next <= leadout_lba; end
					end
				end
				default: begin                             // LBA (big-endian 2..5)
					c_addr <= cdb_lba;
					mst <= M_APPLY;
				end
				endcase
			end
			// ---- standard SCSI-2 audio set (dialect switch 2026-07-19) ----
			8'h47: begin                                   // PLAY AUDIO MSF (hex, +150)
				// start FF:FF:FF = play from CURRENT position (SCSI-2;
				// BlueSCSI doPlayAudio lba==0xFFFFFFFF). The AppleCD driver
				// resumes from pause this way (watch capture 2026-07-20).
				c_addr <= (c_3 == 8'hFF && c_4 == 8'hFF && c_5 == 8'hFF)
				          ? cur_lba : msf2lba_std(c_3, c_4, c_5);
				c_next <= msf2lba_std(c_6, c_7, c_8);
				mst <= M_APPLY;
			end
			8'h48: begin                                   // PLAY AUDIO TRACK/INDEX (binary)
				if (c_4 == 8'd0) pstate <= ST_IDLE;
				else begin
					c_trk  <= (c_4 - 8'd1 < 8'd99) ? c_4 - 8'd1 : 7'd98;
					c_trk2 <= (c_7 < 8'd99) ? c_7[6:0] : 7'd99;   // stop at start of end+1
					step   <= 0;
					mst    <= toc_valid ? M_CTRK_RD : M_APPLY;
					if (!toc_valid) begin c_addr <= 32'd0; c_next <= leadout_lba; end
				end
			end
			8'h45, 8'ha5: begin                            // PLAY AUDIO(10)/(12), LBA form
				// Gap pass 2026-07-29; oracle BlueSCSI doPlayAudio (2379/2393):
				// LBA 0xFFFFFFFF = play from CURRENT position (resolved before
				// anything else, 2551); length 0 = seek-only, which falls into
				// the 47/48 zero-length arm below via c_addr == c_next. Length
				// is in frames: (10) = cdb7..8, (12) = cdb6..9. The LBA is
				// already in the engine's sector domain (same as cur_lba).
				c_addr <= play_lba_ff ? cur_lba : cdb_lba;
				c_next <= (play_lba_ff ? cur_lba : cdb_lba) +
				          ((c_op == 8'h45) ? {16'd0, c_7, c_8}
				                           : {c_6, c_7, c_8, c_9});
				mst <= M_APPLY;
			end
			8'h4b:                                         // PAUSE/RESUME (cdb8 bit0 = resume)
				if (c_8[0]) begin
					if (pstate == ST_PAUSE) pstate <= ST_PLAY;
				end else if (pstate == ST_PLAY) pstate <= ST_PAUSE;
			8'h4e:                                         // STOP PLAY
				if (pstate != ST_IDLE) pstate <= ST_IDLE;
			8'h01, 8'h0b, 8'h2b:                           // REZERO (player STOP) / SEEK(6/10)
				if (pstate != ST_IDLE) pstate <= ST_IDLE;  // Annex-C stop-audio (BlueSCSI)
			default: ;                                     // 0xCE handled in scsi.v
			endcase
		end
		// track mode: read start(k) then start(k+1) (or leadout when last).
		// Address stream one word per cycle; data arrives two states later
		// (same convention as M_HDR_RD/M_TRK_RD).
		M_CTRK_RD: begin
			step <= step + 3'd1;
			case (step)
			3'd0: blob_ra <= 9'd9 + {(c_trk < n_tracks ? c_trk : n_tracks - 7'd1), 2'b00};
			3'd1: blob_ra <= blob_ra + 9'd1;
			3'd2: begin
				c_addr[15:0] <= blob_q;                    // start(k) lo
				blob_ra <= 9'd9 + {(c_trk2 < n_tracks ? c_trk2 : n_tracks - 7'd1), 2'b00};
			end
			3'd3: begin
				c_addr[LBW-1:16] <= blob_q[LBW-17:0];                   // start(k) hi
				blob_ra <= blob_ra + 9'd1;
			end
			3'd4: c_next[15:0] <= blob_q;                  // start(k+1) lo
			default: begin
				c_next[LBW-1:16] <= blob_q[LBW-17:0];                   // start(k+1) hi
				if (c_trk2 >= n_tracks) c_next <= leadout_lba;
				step <= 0;
				mst <= M_APPLY;
			end
			endcase
		end
		M_SCAN_GO: begin
			cur_lba  <= c_addr;
			flush    <= 1'b1;
			scan_x   <= 1'b1;
			scan_dir <= c_1[4];
			// FF needs headroom past a stale stop position
			if (!c_1[4] && stop_lba <= c_addr) stop_lba <= leadout_lba;
			pstate   <= ST_PLAY;
			mst <= M_IDLE;
		end
		M_APPLY: begin
			mst <= M_IDLE;
			case (c_op)
			8'hcb: begin                                   // STOP: set stop position
				stop_lba <= (c_9[7:6] == 2'b10) ? c_next : c_addr;
				if ((pstate == ST_PLAY || pstate == ST_PAUSE) &&
				    (cur_lba >= ((c_9[7:6] == 2'b10) ? c_next : c_addr)))
					pstate <= ST_IDLE;
			end
			8'hc9: begin                                   // PLAY
				if (c_1[4]) begin
					// address is the END; start stays at current position
					stop_lba <= c_addr;
					if (cur_lba < c_addr) pstate <= ST_PLAY;
				end else begin
					cur_lba <= c_addr;
					flush   <= 1'b1;
					pstate  <= ST_PLAY;
					if (c_9[7:6] == 2'b10) stop_lba <= leadout_lba;
					else if (stop_lba <= c_addr) stop_lba <= leadout_lba;
				end
			end
			8'h47, 8'h48, 8'h45, 8'ha5: begin              // standard range play
				if (c_addr == c_next) begin
					// Zero-length play = SEEK-ONLY per SCSI-2 (BlueSCSI
					// doPlayAudio length==0: "update the position without
					// starting playback"). The driver's Next/Prev/Stop all
					// park the pickup this way after a pause and expect the
					// drive to HOLD state at the new position — reporting
					// idle/"completed" here made the player abandon every
					// skip (2026-07-20 watch capture). pstate unchanged.
					cur_lba <= c_addr;
					flush   <= 1'b1;
				end else begin
					cur_lba  <= c_addr;
					stop_lba <= c_next;
					flush    <= 1'b1;
					pstate   <= (c_addr < c_next) ? ST_PLAY : ST_IDLE;
				end
			end
			default: begin                                 // SEARCH (0xC8) / SCAN (0xCD, v1 = seek)
				cur_lba <= c_addr;
				flush   <= 1'b1;
				if (c_9[7:6] == 2'b10) stop_lba <= c_next;
				else if (stop_lba <= c_addr) stop_lba <= leadout_lba;
				pstate  <= c_1[4] ? ST_PLAY : ST_PAUSE;
			end
			endcase
		end

		// -------------------------------- status refresh (track + abs/rel MSF)
		M_REF_SCAN: begin
			step <= step + 3'd1;
			case (step)
			3'd0: blob_ra <= 9'd8 + {scan_idx, 2'b00};
			3'd1: blob_ra <= blob_ra + 9'd1;
			3'd2: begin scan_ctrl_c <= blob_b0; blob_ra <= blob_ra + 9'd1; end
			3'd3: scan_start[15:0] <= blob_q;
			default: begin
				if ({blob_q[LBW-17:0], scan_start[15:0]} <= ref_abs) begin
					scan_best_start <= {blob_q[LBW-17:0], scan_start[15:0]};
					scan_best_trk   <= scan_idx;
					scan_best_ctrl  <= scan_ctrl_c;
				end
				step <= 0;
				if ((scan_idx + 7'd1) < n_tracks) scan_idx <= scan_idx + 7'd1;
				else begin
					div_v <= ref_abs; div_m <= 0; div_s <= 0;
					mst <= M_REF_DIVA;
				end
			end
			endcase
		end
		M_REF_DIVA: begin
			if (!toc_valid && step == 3'd0) begin
				// fallback path enters here directly: single data track at 0
				scan_best_start <= 32'd0; scan_best_trk <= 7'd0; scan_best_ctrl <= 8'h14;
				div_v <= ref_abs; div_m <= 0; div_s <= 0;
				step <= 3'd1;
			end
			else if (!div_done) begin
				div_v <= div_v_next; div_m <= div_m_next; div_s <= div_s_next;
			end
			else begin
				refm_hold <= div_m; refs_hold <= div_s;
				abs_f <= div_v[7:0];
				ref_rel <= ref_abs - scan_best_start;
				div_v <= ref_abs - scan_best_start; div_m <= 0; div_s <= 0;
				step <= 0;
				mst <= M_REF_DIVR;
			end
		end
		M_REF_DIVR: begin
			if (!div_done) begin
				div_v <= div_v_next; div_m <= div_m_next; div_s <= div_s_next;
			end
			else begin
				abs_m <= {1'b0, refm_hold};
				abs_s <= {1'b0, refs_hold};
				rel_m <= {1'b0, div_m};
				rel_s <= {1'b0, div_s};
				rel_f <= div_v[7:0];
				cur_ctrl    <= scan_best_ctrl;
				cur_trk <= {1'b0, scan_best_trk} + 8'd1;
				mst <= M_IDLE;
			end
		end
		default: mst <= M_IDLE;
		endcase
	end
end

// ============================================================================
// FETCH FSM: fill the free frame half while playing
// ============================================================================
reg  [1:0] fr_valid;
reg        fr_half_r;                  // half being played (owned by sample engine? no: here)
reg  [1:0] fst;

// CDA0 probe word (all fields declared above by here; layout in the port list)
assign dbg_cda0 = { dbg_fr_fetch_cnt, dbg_toc_fetch_cnt,
                    fst, pstate, mst, n_tracks, toc_valid, toc_ready, mounted };
reg [LBW-1:0] fetch_lba;
reg        fetch_sync;                 // reload fetch_lba from cur_lba
localparam F_IDLE = 2'd0, F_REQ = 2'd1, F_WAIT = 2'd2;

// sample engine tells us when it consumed a frame / which half it reads
wire       sample_consume;             // = frame_done
wire       sample_half = fr_half_r;

always @(posedge clk) begin
	if (rst) begin
		fst <= F_IDLE; fr_cap <= 0; fr_valid <= 2'b00; fr_half_w <= 0;
		fr_rd <= 0; fr_act <= 0; fr_lba <= 0; fetch_lba <= 0; fetch_sync <= 1'b1;
	end else begin
		// Free the half that FINISHED. sample_half (= fr_half_r) has already
		// flipped by the clock this block observes frame_done, so indexing by
		// it freed the half that had just STARTED — the ping-pong degenerated
		// into fetch-on-demand at every boundary and playback froze for one
		// fetch duration (~0.5-4 ms, HPS-load dependent) 75x/s: THE original
		// "not CD quality" graininess (CDUR: 71 starves/s, one per half).
		if (flush) begin fr_valid <= 2'b00; fetch_sync <= 1'b1; end
		else if (frame_done) fr_valid[frame_done_half_r] <= 1'b0;

		case (fst)
		F_IDLE: begin
			fr_cap <= 1'b0;
			if (fetch_sync) begin fetch_lba <= cur_lba; fetch_sync <= 1'b0; end
			else if ((pstate == ST_PLAY) && mounted && toc_ready &&
			         !(&fr_valid) && (fetch_lba < stop_lba)) begin
				fr_half_w <= fr_valid[0] ? 1'b1 : 1'b0;
				fst <= F_REQ;
			end
		end
		F_REQ: begin
			if (flush) fst <= F_IDLE;
			else if (ch_grant && !toc_act && !toc_rd && !fr_rd && (mst == M_IDLE)) begin
				// lba = AUDIO window + disc LBA: ONE 2352-byte transaction
				// fills the whole half (Main keys blksz on this window)
				fr_lba <= AUDIO_BLK + fetch_lba;
				fr_rd  <= 1'b1;
				fr_act <= 1'b1;
				fr_cap <= 1'b1;
				dbg_fr_fetch_cnt <= dbg_fr_fetch_cnt + 5'd1;
				fst <= F_WAIT;
			end
		end
		F_WAIT: begin
			if (io_ack) fr_rd <= 1'b0;
			if (ack_fall && fr_act) begin
				fr_act <= 1'b0;
				fr_cap <= 1'b0;
				fr_valid[fr_half_w] <= 1'b1;
				fetch_lba <= fetch_lba + 32'd1;
				fst <= F_IDLE;
			end
		end
		default: fst <= F_IDLE;
		endcase
	end
end

// ============================================================================
// SAMPLE engine: 44.1 kHz cadence; a frame = 588 stereo samples = 1176 words
// ============================================================================
reg [31:0] acc;
reg [10:0] widx;
reg  [1:0] sph;
reg        frame_done_r;
reg        frame_done_half_r;   // WHICH half just finished (captured pre-flip)
assign frame_done = frame_done_r;

// The 44.1 kHz targets are linearly interpolated on the way out (below):
// sys/audio_out.sv picks AUDIO_L/R up with a free-running 48 kHz zero-order
// hold, and feeding it the raw stair-step adds audible imaging ("not CD
// quality" report, 07-28). Interpolating continuously in the 32.5 MHz domain
// means whatever instant the framework samples, it sees a point on the
// segment between the previous and current cadence targets — no knowledge of
// the 48 kHz phase needed. frac16 is a Q16 approximation of the segment
// phase (increment 89 ~= 65536*44100/32.5MHz per clk, saturating; reset at
// each pair commit). Interpolation never leaves the [prev,target] range, so
// the 16-bit output cannot overflow.
reg signed [15:0] snd_l_t, snd_r_t;   // cadence-tick targets (was snd_l/r)
reg signed [15:0] snd_l_p, snd_r_p;   // previous targets (segment start)
reg        [16:0] frac16;             // Q16 segment phase, saturating at 1.0

always @(posedge clk) begin
	if (rst) begin
		acc <= 0; widx <= 0; sph <= 0; frame_done_r <= 0; frame_done_half_r <= 0;
		snd_l_t <= 0; snd_r_t <= 0; snd_l_p <= 0; snd_r_p <= 0;
		frac16 <= 0; fr_half_r <= 0; frame_ra <= 0;
	end else begin
		frame_done_r <= 1'b0;
		if (!frac16[16]) frac16 <= frac16 + 17'd89;
		if (flush) begin
			widx <= 0; acc <= 0; sph <= 0; fr_half_r <= 1'b0;
		end
		else if (pstate == ST_PLAY && fr_valid[fr_half_r]) begin
			if (sph == 2'd0) begin
				acc <= acc + 32'd44_100;
				if (acc >= (CLK_HZ - 32'd44_100)) begin
					acc <= acc + 32'd44_100 - CLK_HZ;
					frame_ra <= {fr_half_r, widx};      // 1 + 11 = 12 bits
					sph <= 2'd1;
				end
			end else begin
				sph <= sph + 2'd1;
				case (sph)
				2'd1: frame_ra <= {fr_half_r, widx + 11'd1};
				2'd2: begin snd_l_p <= snd_l_t; snd_l_t <= frame_q; end
				default: begin
					snd_r_p <= snd_r_t; snd_r_t <= frame_q;
					frac16 <= 0; sph <= 2'd0;
					if (widx == 11'd1174) begin
						widx <= 0;
						fr_half_r <= ~fr_half_r;
						frame_done_r <= 1'b1;
						// nonblocking: captures the PRE-flip half — the one
						// that just finished playing
						frame_done_half_r <= fr_half_r;
					end else widx <= widx + 11'd2;
				end
				endcase
			end
		end
		else begin
			if (pstate != ST_PLAY) begin
				snd_l_t <= 0; snd_r_t <= 0; snd_l_p <= 0; snd_r_p <= 0;
			end
			// underrun (half not ready): hold position, emit silence
			if (pstate != ST_PLAY) acc <= 0;
		end
	end
end

// Interpolated output stage — the only driver of snd_l/snd_r.
// The output register commits only every 8th clk (246 ns hold, ~92 points
// per 44.1 kHz sample): sys/audio_out.sv's clk_audio pickup is a STABILITY
// FILTER — two consecutive 24.576 MHz captures must be EQUAL before a value
// is accepted (audio_out.sv "if(cl2 == cl1)") — so a bus that moves every
// clk_sys is rejected outright: the framework freezes through any fast
// segment and jumps where the ramp flattens (= the "scratchy, sometimes
// muffled" report on the every-clk version of this stage, 07-28 evening).
// The 8-clk hold spans ~6 clk_audio captures, so every step is accepted,
// while the stair-step imaging the interpolation exists to kill stays gone.
wire        [15:0] seg_f  = frac16[16] ? 16'hFFFF : frac16[15:0];
wire signed [16:0] seg_dl = {snd_l_t[15], snd_l_t} - {snd_l_p[15], snd_l_p};
wire signed [16:0] seg_dr = {snd_r_t[15], snd_r_t} - {snd_r_p[15], snd_r_p};
wire signed [33:0] seg_ml = seg_dl * $signed({1'b0, seg_f});
wire signed [33:0] seg_mr = seg_dr * $signed({1'b0, seg_f});
wire signed [16:0] sum_l  = {snd_l_p[15], snd_l_p} + $signed(seg_ml[32:16]);
wire signed [16:0] sum_r  = {snd_r_p[15], snd_r_p} + $signed(seg_mr[32:16]);
// CD Audio Control page 0x0E port scaling (2026-07-29 — the volume slider).
// Source routing per port channel byte (0x01 = left, 0x02 = right, other =
// mute; Snow make_out_sample), then the hardware volume law: a Q15 gain from
// cd_vol_lut.vh, gain = (vol/255)^5, so 255 is exact unity and 0 exact mute.
//
// The law was MEASURED, not assumed (docs/cd_volume_law_2026-07-30.md): a
// linear (s*vol)>>8 — what MAME, Snow and BlueSCSI all do — compresses the
// AppleCD player's whole 16-step ladder into 5.85 dB with 0.10 dB steps at
// the top, while a real Quadra 800 + AppleCD drive spans 28.0 dB with even
// ~2.00 dB steps. Fit over the bytes the player actually sends gives an
// exponent of 5.
//
// Applied to the interpolated value BEFORE the 8-clk commit register, so the
// framework's stability-filter contract (output holds ≥8 clk_sys) is
// untouched.
wire signed [15:0] ap_src_l = (ap_ch0 == 8'h01) ? sum_l[15:0] :
                              (ap_ch0 == 8'h02) ? sum_r[15:0] : 16'sd0;
wire signed [15:0] ap_src_r = (ap_ch1 == 8'h02) ? sum_r[15:0] :
                              (ap_ch1 == 8'h01) ? sum_l[15:0] : 16'sd0;
`include "cd_vol_lut.vh"
// One instance of the 256-entry volume law serves both channels on
// alternate clocks (the gains change only on a MODE SELECT); it was two
// LUT-built ROMs (2026-09-08).
reg         vol_sel = 1'b0;
reg  [15:0] ap_gain_l = 16'h8000, ap_gain_r = 16'h8000;
wire [15:0] vol_gain  = cd_vol_gain(vol_sel ? ap_vol1 : ap_vol0);
always @(posedge clk) begin
	vol_sel <= ~vol_sel;
	if (vol_sel) ap_gain_r <= vol_gain; else ap_gain_l <= vol_gain;
end
wire signed [31:0] ap_scl_l = ap_src_l * $signed({1'b0, ap_gain_l});
wire signed [31:0] ap_scl_r = ap_src_r * $signed({1'b0, ap_gain_r});
reg  [2:0] odiv;
always @(posedge clk) begin
	if (rst || pstate != ST_PLAY) begin
		snd_l <= 0; snd_r <= 0; odiv <= 0;
	end else begin
		odiv <= odiv + 3'd1;
		if (odiv == 3'd0) begin
			snd_l <= ap_scl_l[30:15];
			snd_r <= ap_scl_r[30:15];
		end
	end
end

// Starvation forensics (CDUR): playing, but the half-frame the sample engine
// needs has not been delivered, so the output freezes at its last value.
// HDMI-capture forensics of the 07-20 build measured ~5% of music time in
// 0.4-4 ms freezes — exactly this condition (the 2-half ping-pong affords
// 13.3 ms of slack and HPS serving intermittently exceeds it), and it also
// accounts for the CDS meter's 41.8k changes/s (44.1k x 0.95). Counters
// wrap; readers diff two snapshots over a known interval.
reg [15:0] ur_cnt  = 16'd0;
reg [23:0] ur_clks = 24'd0;
reg        ur_d    = 1'b0;
wire       ur_now  = (pstate == ST_PLAY) && !fr_valid[fr_half_r];
always @(posedge clk) begin
	ur_d <= ur_now;
	if (ur_now && !ur_d) ur_cnt  <= ur_cnt  + 16'd1;
	if (ur_now)          ur_clks <= ur_clks + 24'd1;
end
assign dbg_cdur = {ur_cnt, ur_clks[23:8]};

endmodule

// Minimal simple-dual-port RAM (one write, one registered read) for the
// single-reader buffers above — scsi_dpram would burn two unused mirror
// arrays per instance (the map.rpt M10K check applies here; see the
// 2026-07-07 BRAM-inference lesson: exactly one write statement per array).
module cd_sdp #(parameter DW = 16, AW = 12)
(
	input           clock,
	input  [AW-1:0] waddr,
	input  [DW-1:0] wdata,
	input           wr,
	input  [AW-1:0] raddr,
	output reg [DW-1:0] q
);
// vram_bram's hardware-proven inference recipe (see rtl/vram_bram.sv):
// forced "M10K" (overrides the small-RAM heuristic that silently turned the
// 2 Kbit response planes into ~2000 registers each — fit attempts #1-#3 of
// this file) + no_rw_check, with write and read in SEPARATE always blocks.
(* ramstyle = "M10K,no_rw_check" *) reg [DW-1:0] ram [0:(1<<AW)-1];
always @(posedge clock) if (wr) ram[waddr] <= wdata;
always @(posedge clock) q <= ram[raddr];
endmodule
