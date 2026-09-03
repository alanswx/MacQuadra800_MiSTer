//============================================================================
//  ncr53c96 — the Quadra 800's SCSI controller with an integrated
//  single-disk target (SCSI ID DISK_ID, LUN 0) on the MiSTer block-device
//  interface.  Register-visible behavior follows the Quadra 800 ROM's
//  access patterns (docs/scsi/rom-driver-scsi-access-patterns.md) with
//  QEMU esp.c / MAME ncr53c90.cpp as semantic references
//  (docs/scsi/rtl-gap-analysis.md).  The bus itself is not modeled.
//
//  TWO driver dialects are served, and they select very differently
//  (verilator/tb_ncr53c96.sv exercises both):
//
//   A. the Quadra 800 ROM — DMA-form selects ($C1/$C2) with TC preloaded
//      and an EMPTY FIFO.
//   B. a Unix ncr53c9x-class driver — NetBSD's, and A/UX 3.1's `c94`
//      (scsifsm.c/scsitask.c, which reads the sequence-step register and
//      classifies interrupts exactly as NetBSD's does).  On mac68k
//      NCR_F_DMASELECT is never set, so every select is FIFO-PRELOADED
//      and the bare command byte is written: $41 SELNATN (CDB only),
//      $42 SELATN (IDENTIFY + CDB), $43 SELATNS (stop after IDENTIFY, to
//      negotiate), $46 SELATN3 (IDENTIFY + 2 tag bytes + CDB).
//      docs/scsi/netbsd-ncr53c9x-expectations.md section 2.
//
//  The contract, which this implements:
//   - $41/$42/$46 (and their DMA forms) put the chip in COMMAND phase and
//     start collecting the CDB; the select itself completes SILENTLY (the
//     ROM's poll exits on DREQ) and the CDB then arrives from the FIFO,
//     from PDMA writes, or mixed — the ROM's last CDB byte always comes
//     through the PDMA port, a Unix driver's whole CDB is preloaded.  The
//     CDB length is inferred from the opcode group; when complete the
//     command executes and I_BUS|I_FC is raised with sequence step 4 and
//     the new phase visible.  That pairing (FC and BS together) is what a
//     Unix driver requires of a completed selection.
//   - $43 SELATNS instead stops after the IDENTIFY, reporting sequence
//     step 1 with MESSAGE OUT in STATUS — anything else and the driver
//     resets the chip.  The driver's negotiation message is then drained
//     by a non-DMA TI; this target is async and narrow, so an EXTENDED
//     message is answered with MESSAGE REJECT in MESSAGE IN, after which
//     $12 resumes into COMMAND phase rather than disconnecting.
//   - data moves THROUGH the 16-byte FIFO: $90 (DMA transfer info) loads
//     TC and streams sector data into/out of the FIFO; the ROM gates its
//     16-byte bursts on STATUS.TC0 + DREQ + FIFO-flags bit 4, drains via
//     the PDMA window, then waits for INT (raised when TC==0 and the
//     FIFO has drained below 2 — QEMU esp_dma_ti_check).
//   - $11 ICCS pushes status + message(0) and raises I_FC; $12 message
//     accept raises I_DISC and clears the FIFO.
//   - TC regs write a latch (write also clears STATUS.TC0); any command
//     with the DMA bit loads the live counter (0 means 65536).
//
//  Boot-path command set: TEST UNIT READY, REQUEST SENSE, INQUIRY, MODE
//  SENSE(6), READ CAPACITY(10), READ(6/10), WRITE(6/10).  Anything else
//  returns CHECK CONDITION with ILLEGAL REQUEST sense.
//
//  Register file (16-byte strides upstream; rs = reg number):
//   r0 tcount lo   r1 tcount hi   r2 FIFO      r3 command
//   r4 status/dest-id             r5 istatus/timeout
//   r6 seq-step/sync-period      r7 fifo-flags/sync-offset
//   r8 conf1  r9 clkconv  rA test  rB conf2  rC conf3
//
//  DMA side (Turbo SCSI pseudo-DMA): dma_rd/dma_wr pull/push one byte per
//  handshake; dma_valid pulses when the byte moved.  drq gates the IOSB's
//  /DTACK holdoff and is a continuous function of FIFO occupancy.
//============================================================================

module ncr53c96
(
	input         clk,
	input         nreset,
	input         ce,

	// register byte access, one per sel pulse
	input         sel,
	input         write,
	input   [3:0] rs,
	input   [7:0] wdata,
	output  [7:0] rdata,

	// pseudo-DMA byte stream
	input         dma_rd,          // level-held until dma_valid
	input         dma_wr,
	input   [7:0] dma_wdata,
	output  [7:0] dma_rdata,
	output reg    dma_valid,
	output        drq,
	output reg    irq,

	// MiSTer block devices (512-byte blocks, 16-bit buffer bus).  Three
	// targets share one sector buffer, one nexus at a time:
	//   [0] SCSI ID 0, hard disk, hps_io slot 0
	//   [1] SCSI ID 1, hard disk, hps_io slot 1
	//   [2] SCSI ID 3, CD-ROM,    hps_io slot 4 (2048-byte logical blocks,
	//       served as four consecutive 512-byte HPS blocks)
	// img_mounted pulses one bit at a time, img_size valid for that bit.
	input   [2:0] img_mounted,
	input  [63:0] img_size,
	output [31:0] io_lba,              // for whichever io_rd/io_wr bit is up
	output  [2:0] io_rd,
	output  [2:0] io_wr,
	input   [2:0] io_ack,
	input  [12:0] sd_buff_addr,        // [7:0] = word within the 512-byte block
	input  [15:0] sd_buff_dout,
	output [15:0] sd_buff_din,
	input         sd_buff_wr,

	// CD audio PCM from the CD-ROM target's playback engine (zero when idle)
	output signed [15:0] cd_snd_l,
	output signed [15:0] cd_snd_r
);

// SCSI phases
localparam [2:0] PH_DOUT = 3'd0, PH_DIN = 3'd1, PH_CMD = 3'd2, PH_STAT = 3'd3,
                 PH_MOUT = 3'd6, PH_MIN = 3'd7;
// interrupt status bits
localparam [7:0] I_SEL = 8'h01, I_SELATN = 8'h02, I_RESEL = 8'h04,
                 I_FC = 8'h08, I_BUS = 8'h10, I_DISC = 8'h20, I_ILL = 8'h40,
                 I_RST = 8'h80;

//----------------------------------------------------------------------------
// registers
//----------------------------------------------------------------------------
reg [15:0] tc_latch;
reg [16:0] tcounter;               // 0 in the latch means 65536
reg        tc_zero;
reg  [7:0] fifo [0:15];
reg  [4:0] fifo_cnt;               // count; head is fifo[0] (shift on read)
reg  [7:0] cmd_r;
reg  [2:0] phase;
reg  [7:0] istatus;
reg  [2:0] seq_step;
reg  [3:0] dest_id;
reg  [7:0] conf1, conf2, conf3, clkconv, timeout_r, syncp, synco, testr;
reg        dma_active;             // current command carried the DMA bit

//----------------------------------------------------------------------------
// transfer engine state
//----------------------------------------------------------------------------
reg        cdb_active;             // select done, collecting CDB bytes
reg  [3:0] cdb_pos;
reg  [3:0] cdb_need;               // 0 until the opcode byte arrives
reg  [1:0] skip_cnt;               // leading message bytes to discard:
                                   // 0 for $41/$C1, 1 for $42/$C2 (IDENTIFY),
                                   // 3 for $46 (IDENTIFY + 2 tag bytes)
reg        xfer_msg_out;           // TI in MESSAGE OUT: drain the FIFO as a message
reg  [7:0] msg_first;              // first byte of the outgoing message
reg        msg_first_seen;         // msg_first is latched
reg  [7:0] msgin_byte;             // byte the next MESSAGE IN hands over
reg        msgin_reject;           // that byte is a MESSAGE REJECT, not COMMAND COMPLETE
                                   // -> $12 resumes into COMMAND, it does not disconnect
reg        exec_pending;           // CDB complete, execute next cycle
reg        xfer_in;                // DMA transfer-info, target -> initiator
reg        xfer_out;               // DMA transfer-info, initiator -> target
reg        xfer_pio_in;            // non-DMA TI: hand over one byte
reg        xfer_pio_out;           // non-DMA TI: drain FIFO to buffer
reg        chunk_irq_armed;        // raise I_BUS once per TI command

//----------------------------------------------------------------------------
// target state
//----------------------------------------------------------------------------
reg  [2:0] tgt_mounted;            // per target
reg [31:0] tgt_blocks [0:2];       // 512-byte blocks per target
reg  [1:0] cur_tgt;                // target of the current nexus
wire       is_cd       = (cur_tgt == 2'd2);
wire       mounted     = tgt_mounted[cur_tgt];
wire [31:0] disk_blocks = tgt_blocks[cur_tgt];
// selection: ID 0/1 answer only with an image mounted; the CD-ROM drive
// answers always (the AppleCD driver polls TEST UNIT READY for a disc)
wire [1:0] sel_tgt = (dest_id == 4'd0) ? 2'd0 : (dest_id == 4'd1) ? 2'd1 :
                     (dest_id == 4'd3) ? 2'd2 : 2'd3;
wire       sel_ok  = (sel_tgt == 2'd2) ? 1'b1 :
                     (sel_tgt != 2'd3) && tgt_mounted[sel_tgt];
// REQUEST SENSE state per target: latched when a command CHECKs, cleared by
// the next command that is not REQUEST SENSE (SCSI-1 semantics, scsi.v)
reg  [3:0] tgt_skey [0:2];
reg  [7:0] tgt_asc  [0:2];
reg        cd_prevent;             // PREVENT/ALLOW MEDIUM REMOVAL latch
// The CD-ROM's logical block size: 2048 (power-on default) or 512, set by
// the block descriptor of a MODE SELECT(6).  The Mac ROM's CD boot and the
// Apple CD-ROM driver switch the drive to 512-byte blocks and then read it
// like a disk; MAME's nscsi_cdrom_device::set_block_size is the model.  It
// survives a bus reset (MAME keeps bytes_per_block through device_reset).
reg        cd_blk512;
wire       cd_x4 = is_cd && !cd_blk512;   // logical block = 4 HPS blocks
reg  [7:0] cdb [0:11];
reg        io_rd_i, io_wr_i;
reg [31:0] io_lba_e;               // the engine's own block address
reg [11:0] dout_len;               // byte count of a parameter-list DATA OUT
                                   // (MODE SELECT / AUDIO CONTROL); 0 = block write
reg        msel_pend;              // a CD MODE SELECT list is in the buffer to parse
reg        io_discard;             // the block transfer in flight belongs to an
                                   // abandoned nexus: complete it silently
reg  [3:0] msel_st;
reg        msel_bd;                // the list carries an 8-byte block descriptor

// ---- CD audio / TOC engine (rtl/cd_audio.sv, ported from MacLC) ----------
// It owns the real TOC (the Main fork's MCDA blob at HPS block $7FFF0000,
// else a synthesized single data track), the AppleCD playback state and the
// CD-DA frame stream from HPS block $40000000+lba.  It borrows the CD-ROM
// target's hps_io channel whenever the engine here has no transfer of its
// own in flight: ca_io_active scopes its requests/acks out of the sector
// buffer and the engine's completion accounting.
wire        ca_io_active, ca_io_rd;
wire [31:0] ca_io_lba;
wire  [7:0] ca_ast_code, ca_cur_ctrl, ca_cur_trk;
wire  [7:0] ca_abs_m, ca_abs_s, ca_abs_f, ca_rel_m, ca_rel_s, ca_rel_f;
wire  [7:0] ca_toc_q0, ca_t43_q0, ca_t2_q0;
wire  [9:0] ca_t43_len, ca_t2_len;
wire        ca_toc_ready, ca_disc_audio;
reg         ca_cmd_stb, ca_read_stb, ca_eject_stb, ca_bus_rst;
reg   [1:0] ca_mount_d;            // the CD mount pulse, after tgt_blocks has latched
reg   [7:0] ap_ch0, ap_vol0, ap_ch1, ap_vol1;   // MODE SELECT page $0E output ports
wire  [8:0] toc_addr, t43_addr, t2_addr;        // table reads: address now, byte next cycle

assign io_rd = (io_rd_i ? (3'b001 << cur_tgt) : 3'b000) | {ca_io_rd, 2'b00};
assign io_wr = io_wr_i ? (3'b001 << cur_tgt) : 3'b000;
assign io_lba = ca_io_active ? ca_io_lba : io_lba_e;
wire   io_ack_i = io_ack[cur_tgt] && !ca_io_active;
reg [31:0] lba;
reg [31:0] blocks_left;            // read: blocks not yet fetched; write: not yet flushed
reg  [9:0] sbuf_len;               // valid bytes in sbuf
reg  [9:0] sbuf_pos;               // next byte index
reg        data_dir_in;            // 1 = target->initiator
reg  [7:0] scsi_status;            // 0 good, 2 check condition
reg        buf_valid;              // sbuf holds data ready to stream
reg        flush_pending;          // io_wr outstanding, sbuf owned by platform
reg        io_ack_d;               // for the ack falling edge = transfer done

// A block-device transfer is in flight from the io_rd/io_wr strobe until
// the cycle after io_ack falls.  The engine must not conclude anything
// about the buffer inside that window: io_ack RISING only means the
// platform accepted the command — the buffer words then stream in (load)
// or out (flush) for the whole time ack is high.  The old code published
// buf_valid at the rising edge and survived only because the bare-array
// read was asynchronous: the fill chased the load exactly one word
// behind, same-cycle writes included.  A registered read loses that race
// for the first byte (and real hps_io streams far slower than the fill
// drains, so rising-edge publication was a hardware bug waiting).
wire io_busy = io_rd_i || io_wr_i || io_ack_i || io_ack_d || ca_io_active;
// the audio engine may use the channel while nothing of the engine's is in
// flight; an active CD read's data-in serving is fine (its fetches are
// interleaved between the engine's own, which wait on ca_io_active)
wire ca_grant = tgt_mounted[2] && !io_rd_i && !io_wr_i && !io_ack_i && !io_ack_d &&
                !flush_pending && (cur_tgt != 2'd2 || !(xfer_out || xfer_pio_out));

`ifdef VERILATOR
// bring-up taps: command writes, CDB executions, interrupt edges — with
// the transfer-engine state that decides completion.  Sim-only.
reg [63:0] dbg_cyc;
reg        dbg_irq_d, dbg_iow_d, dbg_ior_d, dbg_ack_d;
initial dbg_cyc = 0;
`endif

wire byte_avail = buf_valid && (sbuf_pos < sbuf_len);
reg [7:0] dma_rlatch;
assign dma_rdata = dma_rlatch;

// DRQ: continuous function of FIFO occupancy and command state.
// CDB / data-out want bytes while TC remains and there is room (16-bit PDMA
// wants room for 2); data-in offers bytes while >= 2 are present (CONFIG3
// LBTM: the last odd byte is left for the processor).
assign drq = cdb_active ? (dma_active && !tc_zero && (fifo_cnt < 5'd15)) :
             xfer_out   ? (dma_active && !tc_zero && (fifo_cnt < 5'd15)) :
             xfer_in    ? (fifo_cnt >= 5'd2) :
             1'b0;

// register reads (side-effect-free except FIFO/istatus handled in the block)
assign rdata = (rs == 4'h0) ? tcounter[7:0]  :
               (rs == 4'h1) ? tcounter[15:8] :
               (rs == 4'h2) ? ((fifo_cnt != 0) ? fifo[0] : 8'h00) :
               (rs == 4'h3) ? cmd_r :
               (rs == 4'h4) ? {irq, 1'b0, 1'b0, tc_zero, 1'b0, phase} :   // bit7 = INT mirrors irq (QEMU esp STAT_INT)
               (rs == 4'h5) ? istatus :
               (rs == 4'h6) ? {5'd0, seq_step} :
               (rs == 4'h7) ? {seq_step, fifo_cnt} :   // top bits = seq-step (dup)
               (rs == 4'h8) ? conf1 :
               (rs == 4'h9) ? clkconv :
               (rs == 4'hA) ? testr :
               (rs == 4'hB) ? conf2 :
               (rs == 4'hC) ? conf3 : 8'h00;

// CDB length by opcode group
// CDB length by opcode group: 0 -> 6, 1/2 -> 10, 5 -> 12 (READ(12), SET CD
// SPEED), 6/7 vendor -> 10 (the Apple CD-ROM set $C0-$CE and the BlueSCSI
// Toolbox $D0-$D9 are all 10-byte CDBs)
function [3:0] group_len(input [7:0] op);
	group_len = (op[7:5] == 3'b000) ? 4'd6 :
	            (op[7:5] == 3'b101) ? 4'd12 : 4'd10;
endfunction

integer i;

// interrupt accumulator: raises collect here (blocking) and merge with the
// same-cycle interrupt-register read at the bottom of the main block, so a
// raise colliding with the ISR read-clear is never lost
/* verilator lint_off BLKSEQ */
reg [7:0] i_new;

task raise(input [7:0] bits);
	i_new = i_new | bits;
endtask
/* verilator lint_on BLKSEQ */

task fifo_push(input [7:0] b);
	if (fifo_cnt < 16) begin
		fifo[fifo_cnt] <= b;
		fifo_cnt <= fifo_cnt + 1'b1;
	end
endtask

task fifo_shift;                    // drop head
	for (i = 0; i < 15; i = i + 1) fifo[i] <= fifo[i+1];
	fifo_cnt <= fifo_cnt - 1'b1;
endtask

task dec_tc;
	tcounter <= tcounter - 1'b1;
	if (tcounter == 17'd1) tc_zero <= 1;
endtask

// one CDB byte arrived (from the FIFO drain or straight off the PDMA port)
task cdb_byte(input [7:0] b);
	if (skip_cnt != 0) skip_cnt <= skip_cnt - 1'b1;   // IDENTIFY / queue tag
	else begin
		cdb[cdb_pos] <= b;
		if (cdb_pos == 0) cdb_need <= group_len(b);
		cdb_pos <= cdb_pos + 1'b1;
	end
endtask

//----------------------------------------------------------------------------
// main
//----------------------------------------------------------------------------
wire reg_wr_cyc = ce && sel && write;
wire reg_rd_cyc = ce && sel && !write;
// cycles where the register interface itself touches the FIFO (push, pop,
// or a command that may flush/load it) — the engine chain stands down
wire fifo_ext   = (reg_wr_cyc && (rs == 4'h2 || rs == 4'h3)) ||
                  (reg_rd_cyc && rs == 4'h2);
wire isr_read   = reg_rd_cyc && (rs == 4'h5);

//----------------------------------------------------------------------------
// sector buffer — 256 x 16 block RAM (was a bare array: same-cycle
// multi-word clears in exec_cdb and two asynchronous reads kept it out
// of M10K, at 4,057 ALUTs / 4,562 registers).  Port S is the platform
// side: the sector load during io_rd service and the flush readback,
// both at sd_buff_addr.  Port E is the engine side: the synthesized-
// response writes, the data-out drain, and the data-in byte reads.
//
// The FIFO-engine arm selects are decided here, one-hot down the same
// priority chain the clocked engine executes, so the write-port mux and
// the engine cannot drift apart.
//----------------------------------------------------------------------------
wire eng_rd      = !fifo_ext && dma_rd && !dma_valid;
wire eng_wr      = !fifo_ext && dma_wr && !dma_valid;
wire arm_pop     = eng_rd && fifo_cnt != 0;
wire arm_rd_idle = !arm_pop && eng_rd && !xfer_in && !cdb_active;
wire arm_cdb_dma = !arm_pop && !arm_rd_idle && eng_wr && cdb_active &&
                   dma_active && !tc_zero;
wire arm_out_dma = !arm_pop && !arm_rd_idle && !arm_cdb_dma && eng_wr &&
                   xfer_out && dma_active && !tc_zero && fifo_cnt < 5'd16;
wire arm_swallow = !arm_pop && !arm_rd_idle && !arm_cdb_dma && !arm_out_dma &&
                   eng_wr && !cdb_active && !xfer_out;
wire no_dma_arm  = !arm_pop && !arm_rd_idle && !arm_cdb_dma && !arm_out_dma &&
                   !arm_swallow;
wire arm_cdb_ff  = !fifo_ext && no_dma_arm && cdb_active && fifo_cnt != 0;
wire arm_drain   = !fifo_ext && no_dma_arm && !arm_cdb_ff &&
                   (xfer_out || xfer_pio_out) && fifo_cnt != 0 &&
                   !flush_pending && sbuf_pos < 10'd512;
wire arm_fill    = !fifo_ext && no_dma_arm && !arm_cdb_ff && !arm_drain &&
                   xfer_in && dma_active && !tc_zero && fifo_cnt < 5'd16 &&
                   byte_avail && sbuf_rd_ok;
wire arm_pio_in  = !fifo_ext && no_dma_arm && !arm_cdb_ff && !arm_drain &&
                   !arm_fill && xfer_pio_in && byte_avail && fifo_cnt == 0 &&
                   sbuf_rd_ok;
wire arm_msg_out = !fifo_ext && no_dma_arm && !arm_cdb_ff && !arm_drain &&
                   !arm_fill && !arm_pio_in && xfer_msg_out && fifo_cnt != 0;

// Synthesized-response sequencer: exec_cdb can no longer clear and fill
// 18 words in one cycle, so it records what to build and this machine
// streams one byte per clock into port E, publishing buf_valid with the
// last byte.  The ROM is still waiting on the select interrupt / phase
// when it lands, so the extra cycles are invisible.
localparam [3:0] SY_SENSE = 4'd0, SY_INQ = 4'd1, SY_MODE = 4'd2, SY_CAP = 4'd3,
                 SY_CDINQ = 4'd4, SY_CDMODE = 4'd5, SY_TOC43 = 4'd6,
                 SY_TOC43F2 = 4'd7, SY_TOC43F1 = 4'd8, SY_TOCC1 = 4'd9,
                 SY_SUBQ = 4'd10, SY_ASTAT = 4'd11, SY_SUBCH = 4'd12,
                 SY_HDR = 4'd13, SY_HDMODE = 4'd14;
reg  [3:0] synth_kind;
reg  [9:0] synth_idx;
reg  [9:0] synth_len;               // != 0 while synthesizing
reg  [7:0] sense_r;                 // sense key latched at exec (it clears)
reg  [7:0] asc_r;                   // additional sense code, same
reg [31:0] cap_r;                   // last LBA latched at exec
reg        cap_cd;                  // READ CAPACITY block length 2048, not 512
reg  [5:0] cd_page;                 // MODE SENSE page requested
reg [31:0] hdr_lba;                 // READ HEADER echo
wire       synth_on = synth_len != 0;

// AppleCD identity, byte-exact from MAME nscsi_cdrom_apple_device (via
// MacLC scsi.v): the stock Apple CD-ROM extension binds only to known
// Apple-shipped drives, so SONY CD-ROM CDU-8004 is required, not cosmetic.
function [7:0] cd_inq_byte(input [5:0] i);
	case (i)
	6'd0:  cd_inq_byte = 8'h05;  6'd1:  cd_inq_byte = 8'h80;
	6'd2:  cd_inq_byte = 8'h02;  6'd3:  cd_inq_byte = 8'h02;
	6'd4:  cd_inq_byte = 8'h31;
	6'd8:  cd_inq_byte = "S";  6'd9:  cd_inq_byte = "O";
	6'd10: cd_inq_byte = "N";  6'd11: cd_inq_byte = "Y";
	6'd16: cd_inq_byte = "C";  6'd17: cd_inq_byte = "D";
	6'd18: cd_inq_byte = "-";  6'd19: cd_inq_byte = "R";
	6'd20: cd_inq_byte = "O";  6'd21: cd_inq_byte = "M";
	6'd23: cd_inq_byte = "C";  6'd24: cd_inq_byte = "D";
	6'd25: cd_inq_byte = "U";  6'd26: cd_inq_byte = "-";
	6'd27: cd_inq_byte = "8";  6'd28: cd_inq_byte = "0";
	6'd29: cd_inq_byte = "0";  6'd30: cd_inq_byte = "4";
	6'd32: cd_inq_byte = "1";  6'd33: cd_inq_byte = ".";
	6'd34: cd_inq_byte = "9";  6'd35: cd_inq_byte = "a";
	6'd39: cd_inq_byte = 8'hd0; 6'd40: cd_inq_byte = 8'h90;
	6'd41: cd_inq_byte = 8'h27; 6'd42: cd_inq_byte = 8'h3e;
	6'd43: cd_inq_byte = 8'h01; 6'd44: cd_inq_byte = 8'h04;
	6'd45: cd_inq_byte = 8'h91; 6'd47: cd_inq_byte = 8'h18;
	6'd48: cd_inq_byte = 8'h06; 6'd49: cd_inq_byte = 8'hf0;
	6'd50: cd_inq_byte = 8'hfe;
	6'd12, 6'd13, 6'd14, 6'd15, 6'd22, 6'd31: cd_inq_byte = " ";
	default: cd_inq_byte = 8'h00;
	endcase
endfunction

// CD MODE SENSE(6): 12-byte header + block descriptor (WP, 2048-byte
// blocks, capacity), then the page: $30 Apple magic (24), $0E audio
// control (16, default ports), $2A capabilities (26); other pages
// header+descriptor only.  Lengths: 36 / 28 / 38 / 12.
function [7:0] cd_mode_byte(input [5:0] pg, input [5:0] i);
	if (i < 6'd12) begin
		case (i)
		6'd0:  cd_mode_byte = (pg == 6'h30) ? 8'd35 : (pg == 6'h0E) ? 8'd27 :
		                      (pg == 6'h2A) ? 8'd37 : 8'd11;
		6'd2:  cd_mode_byte = 8'h80;
		6'd3:  cd_mode_byte = 8'd8;
		6'd5:  cd_mode_byte = cap_r[23:16];
		6'd6:  cd_mode_byte = cap_r[15:8];
		6'd7:  cd_mode_byte = cap_r[7:0];
		6'd10: cd_mode_byte = cd_blk512 ? 8'h02 : 8'h08;
		default: cd_mode_byte = 8'h00;
		endcase
	end
	else if (pg == 6'h30) begin
		case (i)
		6'd12: cd_mode_byte = 8'h30;
		6'd14: cd_mode_byte = "A"; 6'd15: cd_mode_byte = "P"; 6'd16: cd_mode_byte = "P";
		6'd17: cd_mode_byte = "L"; 6'd18: cd_mode_byte = "E"; 6'd19: cd_mode_byte = " ";
		6'd20: cd_mode_byte = "C"; 6'd21: cd_mode_byte = "O"; 6'd22: cd_mode_byte = "M";
		6'd23: cd_mode_byte = "P"; 6'd24: cd_mode_byte = "U"; 6'd25: cd_mode_byte = "T";
		6'd26: cd_mode_byte = "E"; 6'd27: cd_mode_byte = "R"; 6'd28: cd_mode_byte = ",";
		6'd29: cd_mode_byte = " "; 6'd30: cd_mode_byte = "I"; 6'd31: cd_mode_byte = "N";
		6'd32: cd_mode_byte = "C"; 6'd33, 6'd34, 6'd35: cd_mode_byte = " ";
		default: cd_mode_byte = 8'h00;
		endcase
	end
	else if (pg == 6'h0E) begin
		case (i)
		6'd12: cd_mode_byte = 8'h0E; 6'd13: cd_mode_byte = 8'h0E;
		6'd14: cd_mode_byte = 8'h04;
		6'd18, 6'd19: cd_mode_byte = 8'd75;
		6'd20: cd_mode_byte = ap_ch0; 6'd21: cd_mode_byte = ap_vol0;   // the AppleCD
		6'd22: cd_mode_byte = ap_ch1; 6'd23: cd_mode_byte = ap_vol1;   // player's slider
		default: cd_mode_byte = 8'h00;
		endcase
	end
	else if (pg == 6'h2A) begin
		case (i)
		6'd12: cd_mode_byte = 8'h2A; 6'd13: cd_mode_byte = 8'h18;
		6'd16: cd_mode_byte = 8'h71; 6'd18: cd_mode_byte = 8'h28;
		6'd19: cd_mode_byte = 8'h03; 6'd22: cd_mode_byte = 8'h01;
		default: cd_mode_byte = 8'h00;
		endcase
	end
	else cd_mode_byte = 8'h00;
endfunction

// ---- table-sourced responses (cd_audio's RAMs).  Each table is a pair of
// byte planes addressed so that after a read at address x the planes hold
// bytes x and x+1, and the q0 output is muxed by the CURRENT address's low
// bit -- for a sequential serve that is a zero-latency read of the current
// byte.  So the sequencer presents the index it is writing now (byte 0 is
// presented while exec_cdb's cycle still has synth_len == 0).
wire [9:0] nxt_idx = synth_on ? synth_idx : 10'd0;
// Apple $C1: [0..3] header, [4..7] lead-out, [8+4k..] track k+1; the
// control byte picks the base, cdb[5] (BCD) the first track; reads past the
// 99 descriptors clamp to the last one (MAME "keep returning the last track").
function [7:0] bcd2bin8(input [7:0] b);
	bcd2bin8 = {4'd0, b[7:4]} * 8'd10 + {4'd0, b[3:0]};
endfunction
function [7:0] bin2bcd8(input [7:0] v);          // 0..99
	bin2bcd8 = {(v / 8'd10), 4'd0} | (v % 8'd10);
endfunction
wire [7:0] c1_trk_bin = bcd2bin8(cdb[5]);
wire [8:0] c1_trk_k   = (c1_trk_bin == 8'd0) ? 9'd0 : (c1_trk_bin > 8'd99) ? 9'd98 : {1'b0, c1_trk_bin} - 9'd1;
wire [8:0] c1_base    = (cdb[9][7:6] == 2'b01) ? 9'd4 :
                        (cdb[9][7:6] == 2'b10) ? (9'd8 + {c1_trk_k[6:0], 2'b00}) : 9'd0;
wire [8:0] c1_raw     = c1_base + nxt_idx[8:0];
assign toc_addr = (c1_raw < 9'd404) ? c1_raw : (9'd400 + {7'd0, c1_raw[1:0]});
// standard $43 format 0: the table is full from track 1; serve from the
// requested start track (cdb[6]; $AA = lead-out row only) with the u16be
// length rewritten, zero past the filtered payload
wire [6:0] t43_nreal = (ca_t43_len >= 10'd14) ? ((ca_t43_len - 10'd14) >> 3) + 7'd1 : 7'd1;
wire [6:0] t43_soff  = (cdb[6] == 8'h00 || cdb[6] == 8'h01) ? 7'd0 :
                       (cdb[6] == 8'hAA) ? t43_nreal :
                       (cdb[6] > {1'b0, t43_nreal}) ? t43_nreal : cdb[6][6:0] - 7'd1;
wire [9:0] t43_flen  = {(7'd1 + t43_nreal - t43_soff), 3'b000} + 10'd2;
wire [9:0] t43_tot   = t43_flen + 10'd2;
assign t43_addr = (nxt_idx < 10'd4) ? nxt_idx[8:0] : (9'd4 + {t43_soff, 3'b000} + (nxt_idx[8:0] - 9'd4));
// format 2 (full TOC) is the table image from 0; format 1 (session) at 496
assign t2_addr = ((synth_kind == SY_TOC43F1) ? 9'd496 : 9'd0) + nxt_idx[8:0];
// standard audio-status codes for $42: $11 play, $12 paused, $13 stopped
wire [7:0] ca_ast_std = (ca_ast_code == 8'd0) ? 8'h11 : (ca_ast_code == 8'd1) ? 8'h12 : 8'h13;

function [7:0] synth_byte(input [3:0] kind, input [9:0] idx);
	case (kind)
	SY_SENSE: synth_byte = (idx == 0) ? 8'h70 :
	                       (idx == 2) ? sense_r :
	                       (idx == 7) ? 8'h0A :
	                       (idx == 12) ? asc_r : 8'h00;
	SY_CDINQ:   synth_byte = cd_inq_byte(idx[5:0]);
	SY_CDMODE:  synth_byte = cd_mode_byte(cd_page, idx[5:0]);
	SY_TOCC1:   synth_byte = ca_toc_ready ? ca_toc_q0 : 8'h00;
	SY_TOC43:   synth_byte = !ca_toc_ready ? 8'h00 :
	                         (idx >= t43_tot) ? 8'h00 :
	                         (idx == 0) ? {6'd0, t43_flen[9:8]} :
	                         (idx == 1) ? t43_flen[7:0] : ca_t43_q0;
	SY_TOC43F2: synth_byte = (ca_toc_ready && idx < ca_t2_len) ? ca_t2_q0 : 8'h00;
	SY_TOC43F1: synth_byte = (ca_toc_ready && idx < 10'd12) ? ca_t2_q0 : 8'h00;
	// Apple READ Q SUBCODE (9): {ctrl, trk, idx=1, rel M,S,F, abs M,S,F} BCD
	SY_SUBQ:    synth_byte = (idx == 0) ? ca_cur_ctrl :
	                         (idx == 1) ? bin2bcd8(ca_cur_trk) : (idx == 2) ? 8'h01 :
	                         (idx == 3) ? bin2bcd8(ca_rel_m) : (idx == 4) ? bin2bcd8(ca_rel_s) :
	                         (idx == 5) ? bin2bcd8(ca_rel_f) : (idx == 6) ? bin2bcd8(ca_abs_m) :
	                         (idx == 7) ? bin2bcd8(ca_abs_s) : (idx == 8) ? bin2bcd8(ca_abs_f) : 8'h00;
	// Apple AUDIO STATUS (6): {status, 0, ctrl, abs M,S,F}; type 1 = volumes
	SY_ASTAT:   synth_byte = (idx == 0) ? ((cdb[3] == 8'd1) ? 8'hFF : ca_ast_code) :
	                         (idx == 1) ? ((cdb[3] == 8'd1) ? 8'hFF : 8'h00) :
	                         (idx == 2) ? ca_cur_ctrl :
	                         (idx == 3) ? bin2bcd8(ca_abs_m) : (idx == 4) ? bin2bcd8(ca_abs_s) :
	                         (idx == 5) ? bin2bcd8(ca_abs_f) : 8'h00;
	// standard READ SUB-CHANNEL: format 1 position (binary MSF); formats 2/3
	// (MCN/ISRC) answer honestly with VALID=0
	SY_SUBCH:   synth_byte = (cdb[3] == 8'h02) ? ((idx == 1) ? ca_ast_std : (idx == 3) ? 8'd20 : (idx == 4) ? 8'h02 : 8'h00) :
	                         (cdb[3] == 8'h03) ? ((idx == 1) ? ca_ast_std : (idx == 3) ? 8'd20 : (idx == 4) ? 8'h03 : (idx == 6) ? cdb[6] : 8'h00) :
	                         (idx == 1) ? ca_ast_std : (idx == 3) ? 8'd12 : (idx == 4) ? 8'h01 :
	                         (idx == 5) ? ca_cur_ctrl : (idx == 6) ? ca_cur_trk : (idx == 7) ? 8'h01 :
	                         (idx == 9) ? ca_abs_m : (idx == 10) ? ca_abs_s : (idx == 11) ? ca_abs_f :
	                         (idx == 13) ? ca_rel_m : (idx == 14) ? ca_rel_s : (idx == 15) ? ca_rel_f : 8'h00;
	SY_HDR:     synth_byte = (idx == 0) ? (ca_disc_audio ? 8'h00 : 8'h01) : (idx == 4) ? hdr_lba[31:24] :
	                         (idx == 5) ? hdr_lba[23:16] : (idx == 6) ? hdr_lba[15:8] :
	                         (idx == 7) ? hdr_lba[7:0] : 8'h00;
	SY_INQ:   case (idx[5:0])                  // bytes not listed: $20,
	          6'd0, 6'd1: synth_byte = 8'h00;  // the old $2020 preset
	          6'd2, 6'd3: synth_byte = 8'h02;  // SCSI-2
	          6'd4:  synth_byte = 8'd31;
	          6'd8:  synth_byte = "W"; 6'd9:  synth_byte = "O";
	          6'd10: synth_byte = "M"; 6'd11: synth_byte = "B";
	          6'd12: synth_byte = "A"; 6'd13: synth_byte = "T";
	          6'd14: synth_byte = "3"; 6'd15: synth_byte = "3";
	          default: synth_byte = 8'h20;
	          endcase
	SY_MODE:  synth_byte = (idx == 0) ? 8'h03 : 8'h00;
	// disk MODE SENSE page $30, the Apple firmware ID page: Apple HD SC
	// Setup / Drive Setup and the Mac OS installer's driver update accept a
	// drive only if this page carries "APPLE COMPUTER, INC" (MAME
	// nscsi_harddisk_device, QEMU q800's quirk_mode_page_apple_vendor).
	// 4-byte header, 8-byte descriptor (512-byte blocks, not write
	// protected), page $B0 (PS set) of 22 bytes = the CD's page $30 text.
	SY_HDMODE: synth_byte = (idx == 0)  ? 8'd35 :
	                        (idx == 2)  ? 8'h00 :
	                        (idx == 3)  ? 8'd8 :
	                        (idx == 5)  ? cap_r[23:16] :
	                        (idx == 6)  ? cap_r[15:8] :
	                        (idx == 7)  ? cap_r[7:0] :
	                        (idx == 10) ? 8'h02 :
	                        (idx == 12) ? 8'hB0 :
	                        (idx == 13) ? 8'h16 :
	                        (idx >= 14 && idx < 36) ? cd_mode_byte(6'h30, idx[5:0]) : 8'h00;
	default:  case (idx[5:0])                  // SY_CAP: 512 / 2048-byte blocks
	          6'd0: synth_byte = cap_r[31:24];
	          6'd1: synth_byte = cap_r[23:16];
	          6'd2: synth_byte = cap_r[15:8];
	          6'd3: synth_byte = cap_r[7:0];
	          6'd6: synth_byte = cap_cd ? 8'h08 : 8'd2;
	          default: synth_byte = 8'h00;
	          endcase
	endcase
endfunction

// Port E: synth and drain writes own the address; otherwise it reads
// ahead of the data-in stream at sbuf_pos.  sbuf_rd_ok covers the one
// cycle after the read address moved (or a write stole the port) while
// the registered q_e still shows the previous word — the fill arms wait
// it out (a stall only on word crossings; within a word the address is
// unchanged).  Completion logic keeps the pure byte_avail.
wire        we_e    = synth_on || arm_drain;
wire  [7:0] addr_e  = synth_on ? synth_idx[8:1] :
                      (msel_st != 0) ? msel_addr : sbuf_pos[8:1];
wire  [7:0] wbyte_e = synth_on ? synth_byte(synth_kind, synth_idx) : fifo[0];
// MODE SELECT parse: word 1 (block descriptor length), word 5 (block
// length), then the page at word 2 or 6 -- its code, and the $0E output
// ports four and five words further on
wire  [7:0] msel_base = msel_bd ? 8'd6 : 8'd2;
wire  [7:0] msel_addr = (msel_st == 4'd1 || msel_st == 4'd2) ? 8'd1 :
                        (msel_st == 4'd3 || msel_st == 4'd4) ? 8'd5 :
                        (msel_st == 4'd5 || msel_st == 4'd6) ? msel_base :
                        (msel_st == 4'd7 || msel_st == 4'd8) ? msel_base + 8'd4 :
                                                               msel_base + 8'd5;
wire        wodd_e  = synth_on ? synth_idx[0] : sbuf_pos[0];
wire [15:0] q_e, q_s;

ncr_sbuf sbuf
(
	.clk    (clk),
	.addr_e (addr_e),
	.din_e  ({2{wbyte_e}}),
	.be_e   (wodd_e ? 2'b01 : 2'b10),
	.we_e   (we_e),
	.q_e    (q_e),
	.addr_s (sd_buff_addr[7:0]),
	.din_s  (plat_din_s),
	.we_s   (sd_buff_wr && !ca_io_active),   // the audio engine's transfers are its own
	.q_s    (q_s)
);

// Platform byte packing for the 16-bit HPS sector buffer.  sbuf is kept
// big-endian internally (disk byte 0 in the HIGH half) because that is
// what sbuf_byte, set_byte and the synth sequencer all assume, so the
// swap happens here at the boundary:
//
//   * the real MiSTer HPS packs WIDE words LITTLE-endian: disk byte 0
//     arrives in sd_buff_dout[7:0].
//   * verilator/sim/sim_blkdevice.cpp packs them BIG-endian: it does
//     `(byte1 << 8) | byte2`, putting disk byte 0 in [15:8].
//
// Getting this wrong swaps every byte PAIR on the disk, so the driver
// descriptor's 'ER' signature reads as 'RE' and no volume is bootable —
// invisible in sim, fatal on hardware.  MacLC_MiSTer hit exactly this and
// confirmed the packing with a JTAG probe (rtl/scsi.v, "HPS sector-buffer
// byte order"); this mirrors their resolution.
`ifdef VERILATOR
wire [15:0] plat_din_s = sd_buff_dout;
assign sd_buff_din = q_s;
`else
wire [15:0] plat_din_s = {sd_buff_dout[7:0], sd_buff_dout[15:8]};
assign sd_buff_din = {q_s[7:0], q_s[15:8]};
`endif

// platform readback (write flush): hps_io and the sim both sample a
// held address many cycles after driving it, so the registered read is
// transparent to them.  The lane mapping is applied above.

reg  [7:0] eq_addr;                // address q_e currently reflects
reg        eq_wr;
always @(posedge clk) begin
	eq_addr <= addr_e;
	eq_wr   <= we_e;
end
wire       sbuf_rd_ok = (eq_addr == sbuf_pos[8:1]) && !eq_wr;
wire [7:0] sbuf_byte  = sbuf_pos[0] ? q_e[7:0] : q_e[15:8];

always @(posedge clk) begin
	if (!nreset) begin
		i_new = 8'h00;
		tc_latch <= 0; tcounter <= 0; tc_zero <= 0;
		fifo_cnt <= 0; cmd_r <= 0; phase <= PH_DOUT;
		istatus <= 0; seq_step <= 0; dest_id <= 0;
		conf1 <= 0; conf2 <= 0; conf3 <= 0; clkconv <= 0;
		timeout_r <= 0; syncp <= 0; synco <= 0; testr <= 0;
		irq <= 0; dma_valid <= 0; dma_rlatch <= 0;
		tgt_mounted <= 0;
		tgt_blocks[0] <= 0; tgt_blocks[1] <= 0; tgt_blocks[2] <= 0;
		tgt_skey[0] <= 0; tgt_skey[1] <= 0; tgt_skey[2] <= 0;
		tgt_asc[0] <= 0; tgt_asc[1] <= 0; tgt_asc[2] <= 0;
		cur_tgt <= 0; cd_prevent <= 0; cd_blk512 <= 0; dout_len <= 0;
		msel_pend <= 0; msel_st <= 0; msel_bd <= 0; io_discard <= 0;
		ca_cmd_stb <= 0; ca_read_stb <= 0; ca_eject_stb <= 0; ca_bus_rst <= 0; ca_mount_d <= 0;
		ap_ch0 <= 8'h01; ap_vol0 <= 8'hFF; ap_ch1 <= 8'h02; ap_vol1 <= 8'hFF;
		io_lba_e <= 0; io_rd_i <= 0; io_wr_i <= 0;
		dma_active <= 0;
		cdb_active <= 0; cdb_pos <= 0; cdb_need <= 0; skip_cnt <= 0;
		exec_pending <= 0;
		xfer_msg_out <= 0; msg_first <= 0; msg_first_seen <= 0;
		msgin_byte <= 0; msgin_reject <= 0;
		xfer_in <= 0; xfer_out <= 0; xfer_pio_in <= 0; xfer_pio_out <= 0;
		chunk_irq_armed <= 0;
		lba <= 0; blocks_left <= 0;
		sbuf_len <= 0; sbuf_pos <= 0; buf_valid <= 0; flush_pending <= 0;
		io_ack_d <= 0;
		data_dir_in <= 0; scsi_status <= 0;
		synth_kind <= 0; synth_idx <= 0; synth_len <= 0;
		sense_r <= 0; asc_r <= 0; cap_r <= 0; cap_cd <= 0;
		cd_page <= 0; hdr_lba <= 0;
	end
	else begin
		i_new = 8'h00;
		dma_valid <= 0;
		ca_cmd_stb <= 0; ca_read_stb <= 0; ca_eject_stb <= 0; ca_bus_rst <= 0;
		ca_mount_d <= {ca_mount_d[0], img_mounted[2]};

`ifdef VERILATOR
		dbg_cyc <= dbg_cyc + 64'd1;
		if (ce && sel && write && rs == 4'h3)
			$display("[NCR %0d] cmd=%02X ph=%0d tc=%0d tz=%b ff=%0d bl=%0d sp=%0d xi=%b xo=%b fp=%b ca=%b",
			         dbg_cyc, wdata, phase, tcounter, tc_zero, fifo_cnt,
			         blocks_left, sbuf_pos, xfer_in, xfer_out, flush_pending,
			         cdb_active);
		if (exec_pending)
			$display("[NCR %0d] cdb %02X %02X %02X %02X %02X %02X %02X %02X %02X %02X",
			         dbg_cyc, cdb[0], cdb[1], cdb[2], cdb[3], cdb[4],
			         cdb[5], cdb[6], cdb[7], cdb[8], cdb[9]);
		dbg_irq_d <= irq;
		if (irq && !dbg_irq_d)
			$display("[NCR %0d] INT+ ist=%02X ph=%0d", dbg_cyc, istatus, phase);
		if (io_wr_i && !dbg_iow_d)
			$display("[NCR %0d] io_wr+ t%0d lba=%0d fp=%b", dbg_cyc, cur_tgt, io_lba_e, flush_pending);
		if (io_rd_i && !dbg_ior_d)
			$display("[NCR %0d] io_rd+ t%0d lba=%0d", dbg_cyc, cur_tgt, io_lba_e);
		if (io_ack_i && !dbg_ack_d)
			$display("[NCR %0d] io_ack+ rd=%b wr=%b ff=%0d sp=%0d po=%b",
			         dbg_cyc, io_rd_i, io_wr_i, fifo_cnt, sbuf_pos, xfer_pio_out);
		if (!io_ack_i && dbg_ack_d)
			$display("[NCR %0d] io_ack- fp=%b ff=%0d sp=%0d po=%b",
			         dbg_cyc, flush_pending, fifo_cnt, sbuf_pos, xfer_pio_out);
		dbg_iow_d <= io_wr_i;
		dbg_ior_d <= io_rd_i;
		dbg_ack_d <= io_ack_i;
`endif

		for (i = 0; i < 3; i = i + 1)
			if (img_mounted[i]) begin
				tgt_mounted[i] <= (img_size != 0);
				tgt_blocks[i]  <= img_size[40:9];
			end
		// (the sector arriving from the platform during io_rd service
		// lands through the RAM's port S above)
		//
		// ack rising = command accepted: drop the request strobes.
		// ack falling = transfer complete: only now publish a loaded
		// sector / release a flushed buffer (see io_busy above).
		io_ack_d <= io_ack_i;
		if (io_ack_i) begin
			io_rd_i <= 0;
			io_wr_i <= 0;
		end
		if (io_ack_d && !io_ack_i) begin
			if (!flush_pending && !io_discard) begin
				buf_valid <= 1;
				sbuf_len <= 10'd512;
				sbuf_pos <= 0;
			end
			flush_pending <= 0;
			io_discard <= 0;
		end

		//---------------------------------------------------- block prefetch
		// data-in: fetch the next sector whenever the current one is spent
		if (phase == PH_DIN && data_dir_in && blocks_left != 0 &&
		    !io_busy && (!buf_valid || sbuf_pos >= sbuf_len)) begin
			buf_valid <= 0;
			io_lba_e <= lba;
			lba <= lba + 1'b1;
			blocks_left <= blocks_left - 1'b1;
			io_rd_i <= 1;
		end

		//---------------------------------------------------- FIFO engine
		// exactly one FIFO action per cycle; the register interface (push,
		// pop, flush) preempts the chain on its own cycles (fifo_ext).
		// The arm predicates live with the sector-buffer port mux above.
		if (arm_pop) begin
			// PDMA read: pop the head
			dma_rlatch <= fifo[0];
			fifo_shift;
			dma_valid <= 1;
		end
		else if (arm_rd_idle) begin
			// PDMA read with nothing pending: don't wedge the bus
			dma_rlatch <= 8'hFF;
			dma_valid <= 1;
		end
		else if (arm_cdb_dma) begin
			// PDMA write during CDB collection (the ROM's last CDB byte)
			cdb_byte(dma_wdata);
			dec_tc;
			dma_valid <= 1;
		end
		else if (arm_out_dma) begin
			// PDMA write, data-out: into the FIFO; TC counts the DACK
			fifo_push(dma_wdata);
			dec_tc;
			dma_valid <= 1;
		end
		else if (arm_swallow) begin
			// stray PDMA write: swallow it rather than wedging the bus
			dma_valid <= 1;
		end
		else if (arm_cdb_ff) begin
			// CDB bytes preloaded/pushed into the FIFO drain into cdb[]
			cdb_byte(fifo[0]);
			fifo_shift;
		end
		else if (arm_drain) begin
			// data-out: FIFO head into the sector buffer (the write
			// itself runs on port E above)
			sbuf_pos <= sbuf_pos + 1'b1;
			fifo_shift;
		end
		else if (arm_fill) begin
			// data-in: sector buffer fills the FIFO; TC counts here
			fifo_push(sbuf_byte);
			sbuf_pos <= sbuf_pos + 1'b1;
			dec_tc;
		end
		else if (arm_pio_in) begin
			// non-DMA TI data-in: exactly one byte, then bus service.  When
			// that byte is the target's last, the phase changes on this very
			// handshake -- the byte is read out of the FIFO with STATUS
			// already showing (QEMU leaves the last PIO byte in the FIFO for
			// exactly this reason, esp.c "Non-DMA transfers from the target
			// will leave the last byte in the FIFO").  A driver that ends
			// its byte loop by count and then polls for the phase change
			// (the ROM's original-API SCSIComplete) hangs otherwise.
			fifo_push(sbuf_byte);
			sbuf_pos <= sbuf_pos + 1'b1;
			xfer_pio_in <= 0;
			if (sbuf_pos == sbuf_len - 1'b1 && blocks_left == 0 && !io_busy)
				phase <= PH_STAT;
			raise(I_BUS);
		end
		else if (arm_msg_out) begin
			// MESSAGE OUT: the message the driver preloaded leaves the
			// FIFO a byte at a time.  Only its first byte decides what
			// the target does next, so that is all we keep.
			if (!msg_first_seen) begin
				msg_first      <= fifo[0];
				msg_first_seen <= 1;
			end
			fifo_shift;
		end

		// synthesized responses stream one byte per clock through port E;
		// the last byte publishes the buffer.  A new exec_cdb below
		// overrides these assignments (its arms run later in this block)
		if (synth_on) begin
			synth_idx <= synth_idx + 1'b1;
			if (synth_idx == synth_len - 1'b1) begin
				synth_len <= 0;
				buf_valid <= 1;
			end
		end

		//---------------------------------------------------- CDB completion
		if (cdb_active && cdb_need != 0 && cdb_pos == cdb_need) begin
			cdb_active <= 0;
			exec_pending <= 1;
		end
		if (exec_pending) begin
			exec_pending <= 0;
			exec_cdb;
		end

		//---------------------------------------------------- transfer ends
		// data-in chunk complete: TC expired and the host drained the FIFO.
		// This is the ONLY data-in completion the ROM SCSI Manager and A/UX's
		// c94 ever produce: QEMU esp_do_dma always drains the whole chunk on
		// DRQ (lower_drq at fifo<2) BEFORE raising the completion interrupt,
		// so the completion never arrives with data still in the FIFO -- a
		// full 512-byte block is two TC=256 $90 chunks, each drained then BS,
		// the last one flipping to STATUS (qemu-esp-behavior.md, and the
		// master trace of this exact ROM+disk).  "Source exhausted" also
		// requires the synthesized-response sequencer to be idle: while
		// synth_on streams a response into the buffer the data is in flight,
		// not absent -- exactly like io_busy for a sector.  (A driver fast
		// enough to issue TI within a few cycles of the select interrupt --
		// the tb is -- would otherwise see the phase close before the data
		// exists.)
		if (xfer_in && chunk_irq_armed && tc_zero && fifo_cnt < 5'd2) begin
			chunk_irq_armed <= 0;
			xfer_in <= 0;
			if (!byte_avail && blocks_left == 0 && !io_busy && !synth_on)
				phase <= PH_STAT;
			raise(I_BUS);
		end
		// data-in underflow: source exhausted before TC — go to status
		if (xfer_in && chunk_irq_armed && !tc_zero && !byte_avail &&
		    blocks_left == 0 && !io_busy && !synth_on) begin
			chunk_irq_armed <= 0;
			xfer_in <= 0;
			phase <= PH_STAT;
			raise(I_BUS);
		end
		// data-out: full sector in the buffer -> flush it.  When this
		// flush exhausts the CDB's block count the transfer is over:
		// flip to STATUS so the ROM's write loop (which polls the phase
		// bits to know when to stop feeding bytes) terminates — without
		// this a PIO write streams forever, lba marching off the file.
		if ((xfer_out || xfer_pio_out) && sbuf_pos == 10'd512 &&
		    dout_len == 0 && !flush_pending && !io_busy) begin
			io_lba_e <= lba;
			lba <= lba + 1'b1;
			if (blocks_left != 0) begin
				blocks_left <= blocks_left - 1'b1;
				if (blocks_left == 32'd1 && !data_dir_in) phase <= PH_STAT;
			end
			io_wr_i <= 1;
			flush_pending <= 1;
			sbuf_pos <= 0;
		end
		// parameter-list DATA OUT (MODE SELECT, AUDIO CONTROL): the bytes
		// land in the sector buffer and are not written anywhere; the phase
		// ends when the CDB's parameter length has arrived.  The DMA chunk
		// arm below ends it too (blocks_left is 0); this covers the PIO form
		// and a TC longer than the list.
		if ((xfer_out || xfer_pio_out) && dout_len != 0 && sbuf_pos >= dout_len) begin
			xfer_out <= 0; xfer_pio_out <= 0; chunk_irq_armed <= 0;
			phase <= PH_STAT;
			raise(I_BUS);
			if (msel_pend) msel_st <= 4'd1;
		end
		// CD MODE SELECT(6) parameter list: 4-byte header, an optional
		// 8-byte block descriptor (byte 3 = its length; bytes 9..11 the
		// block length, 512 or 2048), then the page.  Page $0E carries the
		// AppleCD player's volume slider as {channel, volume} for output
		// ports 0 and 1 at page bytes 8..11.  The buffer is read through
		// port E (registered): one state addresses, the next consumes.
		case (msel_st)
		4'd1: msel_st <= 4'd2;                              // word 1 addressed
		4'd2: begin                                         // byte 3: descriptor length
			msel_bd <= (q_e[7:0] == 8'd8);
			msel_st <= (q_e[7:0] == 8'd8) ? 4'd3 : 4'd5;
		end
		4'd3: msel_st <= 4'd4;                              // word 5 addressed
		4'd4: begin                                         // bytes 10,11: block length
			if (q_e == 16'h0200) cd_blk512 <= 1;
			else if (q_e == 16'h0800) cd_blk512 <= 0;
			msel_st <= 4'd5;
		end
		4'd5: msel_st <= 4'd6;                              // page word addressed
		4'd6: begin                                         // page code
			if (q_e[15:8] != 8'h0E) begin msel_st <= 0; msel_pend <= 0; end
			else msel_st <= 4'd7;
		end
		4'd7: msel_st <= 4'd8;                              // page word 4 addressed
		4'd8: begin ap_ch0 <= q_e[15:8]; ap_vol0 <= q_e[7:0]; msel_st <= 4'd9; end
		4'd9: msel_st <= 4'd10;                             // page word 5 addressed
		4'd10: begin ap_ch1 <= q_e[15:8]; ap_vol1 <= q_e[7:0]; msel_st <= 0; msel_pend <= 0; end
		default: ;
		endcase
		// data-out chunk complete: TC expired and the FIFO drained.  A TC
		// expiry with a part-filled sector buffer is NOT the end of the
		// nexus: the ROM/saio splits one WRITE into many $90 TIs of
		// TC=256 (QEMU master esp trace of this ROM+disk: fsck's 2KB
		// superblock write-back is 8 x TC=256, its 8KB cg writes are
		// 32 x TC=256), so the next chunk continues into the same sector.
		// Flushing the partial buffer here wrote 256 real bytes plus a
		// stale upper half per chunk, burned one block of the CDB count
		// per chunk, and flipped to STATUS halfway through the data --
		// fsck's superblock landed smeared at 256 bytes/sector with the
		// magic number in the void ("BAD SUPER BLOCK: MAGIC NUMBER
		// WRONG").  A real target keeps DATA OUT until it holds the whole
		// block: complete the TI, leave sbuf_pos accumulating, and let
		// the pos==512 flush above do all the writing.  A block write's
		// initiator sends exactly blocks x 512 bytes, so a genuine
		// trailing partial sector cannot exist.
		if (xfer_out && chunk_irq_armed && tc_zero && fifo_cnt == 0 &&
		    !flush_pending && !io_busy) begin
			chunk_irq_armed <= 0;
			xfer_out <= 0;
			if (blocks_left == 0) phase <= PH_STAT;
			raise(I_BUS);
		end
		// non-DMA data-out: FIFO drained -> bus service
		if (xfer_pio_out && fifo_cnt == 0) begin
			xfer_pio_out <= 0;
			raise(I_BUS);
		end
		// MESSAGE OUT complete: the whole message left the FIFO.  What the
		// target does next is decided by the message it just received:
		//
		//   * an EXTENDED message ($01 — SDTR or WDTR, the only reason a
		//     Unix driver issues $43 SELATNS at all) must be answered.  This
		//     target is asynchronous and narrow, and SCSI-2 says a target
		//     that does not implement a negotiation replies MESSAGE REJECT,
		//     which ncr53c9x-class drivers read as "stay asynchronous" and
		//     carry on.  So: phase MESSAGE IN with $07 queued.
		//   * anything else (IDENTIFY, ABORT, a re-sent tag) — go take the
		//     command, which is what the driver sends next.
		//
		// Either way this is a phase change, i.e. a bus-service interrupt.
		if (xfer_msg_out && fifo_cnt == 0) begin
			xfer_msg_out <= 0;
			if (msg_first == 8'h01) begin
				phase        <= PH_MIN;
				msgin_byte   <= 8'h07;          // MESSAGE REJECT
				msgin_reject <= 1;
			end
			else begin
				phase      <= PH_CMD;
				cdb_active <= 1;
				cdb_pos    <= 0;
				cdb_need   <= 0;
				skip_cnt   <= 0;
			end
			raise(I_BUS);
		end
		// non-DMA data-in underflow: the source is exhausted, so the byte this
		// TI is waiting to hand over will NEVER arrive -- arm_pio_in gates on
		// byte_avail, so xfer_pio_in would stay armed forever with no I_BUS and
		// no phase change, and the driver polls for an interrupt that never
		// comes.  Real silicon ends the data phase when the target runs out of
		// data.  This mirrors the DMA-side "data-in underflow" arm above; only
		// the PIO side was missing it.
		//
		// Found on hardware 2026-08-29 (Mac OS boot froze at "Starting Up...")
		// and reproduced in the Verilator sim: an INQUIRY with a 36-byte
		// allocation length transfers all 36 bytes -- the last four one at a
		// time via non-DMA TI -- and then the chip sits in DATA-IN forever.
		//
		// QEMU does the same thing and for the same reason (esp.c:667-671,
		// "If the guest underflows TC then terminate SCSI request" ->
		// esp_command_complete(), phase STATUS, INTR_BS).  Its commit
		// 02a3ce56a7 notes that this is precisely what makes EMILE boot on
		// m68k -- i.e. a Mac bootloader hitting the identical stall.
		// docs/scsi/qemu-esp-behavior.md:357-369.
		if (xfer_pio_in && !byte_avail && blocks_left == 0 && !io_busy &&
		    !synth_on) begin
			xfer_pio_in <= 0;
			phase <= PH_STAT;
			raise(I_BUS);
		end

		//---------------------------------------------------- registers
		if (ce && sel) begin
			if (write) begin
				case (rs)
				4'h0: begin tc_latch[7:0]  <= wdata; tc_zero <= 0; end
				4'h1: begin tc_latch[15:8] <= wdata; tc_zero <= 0; end
				4'h2: fifo_push(wdata);
				4'h3: begin
					cmd_r <= wdata;
					exec_command(wdata);
				end
				4'h4: dest_id  <= wdata[3:0];
				4'h5: timeout_r <= wdata;
				4'h6: syncp <= wdata;
				4'h7: synco <= wdata;
				4'h8: conf1 <= wdata;
				4'h9: clkconv <= wdata;
				4'hA: testr <= wdata;
				4'hB: conf2 <= wdata;
				4'hC: conf3 <= wdata;
				default: ;
				endcase
			end
			else begin
				case (rs)
				4'h2: if (fifo_cnt != 0) fifo_shift;
				default: ;                      // reg 5 handled below
				endcase
			end
		end

		//---------------------------------------------------- interrupt merge
		// reading the interrupt register clears it (and seq-step); a raise
		// arriving on the very same cycle survives instead of being lost
		if (isr_read) begin
			istatus  <= i_new;
			irq      <= (i_new != 8'h00);
			seq_step <= 0;
		end
		else if (i_new != 8'h00) begin
			istatus <= istatus | i_new;
			irq <= 1;
		end
	end
end

//----------------------------------------------------------------------------
// command execution (invoked on command-register writes)
//----------------------------------------------------------------------------
task exec_command(input [7:0] c);
	reg [6:0] op;
	reg       dma;
	begin
		op  = c[6:0];
		dma = c[7];
		dma_active <= dma;
		if (dma) begin
			// any DMA-bit command loads the live counter from the latch
			tcounter <= (tc_latch == 16'd0) ? 17'h10000 : {1'b0, tc_latch};
			tc_zero  <= 0;
		end
		case (op)
		7'h00: ;                                       // NOP
		7'h01: fifo_cnt <= 0;                          // flush FIFO
		7'h02: begin                                   // reset chip
			fifo_cnt <= 0; istatus <= 0; irq <= 0;
			phase <= PH_DOUT; seq_step <= 0;
			cdb_active <= 0; exec_pending <= 0; skip_cnt <= 0;
			xfer_in <= 0; xfer_out <= 0;
			xfer_pio_in <= 0; xfer_pio_out <= 0;
			xfer_msg_out <= 0; msg_first_seen <= 0;
			msgin_byte <= 0; msgin_reject <= 0;
			chunk_irq_armed <= 0;
			dma_active <= 0; tc_zero <= 0;
		end
		7'h03: begin                                   // reset SCSI bus
			if (!conf1[6]) raise(I_RST);               // CONFIG1 DISR gates INT
			ca_bus_rst <= 1;                           // stops playback; TOC survives
			abort_nexus;                               // every target goes bus free
			phase <= PH_DOUT;
		end
		// All four select forms.  Two dialects arrive here:
		//
		//   * the Quadra 800 ROM writes the DMA form ($C1/$C2) with TC
		//     preloaded and an EMPTY FIFO; the CDB follows afterwards as
		//     FIFO writes plus PDMA bytes.  The select completes silently
		//     (the ROM's poll exits on DREQ) and the interrupt is deferred
		//     until the command has run — QEMU does the same.
		//   * a Unix ncr53c9x-class driver (NetBSD's, and A/UX's c94)
		//     never sets NCR_F_DMASELECT, so it PRELOADS the FIFO and
		//     writes the bare command.  Same code path: the FIFO drain
		//     feeds cdb_byte, skip_cnt eats the leading message bytes.
		//
		// The dma bit is masked off by `op`, so $C1/$41 and $C2/$42 are the
		// same case; only the byte counts differ.
		7'h41, 7'h42, 7'h46: begin
			if (sel_ok) begin
				abort_nexus;                       // whatever the last nexus left
				cur_tgt <= sel_tgt;
				phase <= PH_CMD;
				cdb_active <= 1;
				cdb_pos <= 0;
				cdb_need <= 0;
				// $41 SELNATN: CDB only.  $42 SELATN: IDENTIFY + CDB.
				// $46 SELATN3: IDENTIFY + 2 tag bytes + CDB.
				skip_cnt <= (op == 7'h46) ? 2'd3 :
				            (op == 7'h42) ? 2'd1 : 2'd0;
				seq_step <= 3'd4;                  // all bytes went out
			end
			else begin
				// Selection timeout.  The bytes the driver preloaded
				// STAY IN THE FIFO — nothing went out, because nothing
				// answered.  Do not flush them: a Unix driver reads the
				// FIFO count right here to tell the two cases apart.
				//
				// A/UX's c94 driver records how many bytes it pushed
				// (IDENTIFY + CDB) and, on the disconnect interrupt,
				// compares it against FIFO-flags & $1F:
				//     equal -> "Cannot select SCSI device"   (benign;
				//              this is what probing an empty ID means)
				//     short -> "Protocol Error Processing SCSI request"
				//              (the target answered and then vanished
				//              mid-command — a real bus fault)
				// Clearing the count made EVERY empty SCSI ID look like
				// the second case, so the bus scan reported a protocol
				// error on six of seven targets and A/UX condemned the
				// whole bus.  NetBSD leans on the same FIFO count at
				// select step 3 (netbsd-ncr53c9x-expectations.md 2.4:
				// "the arbiter of did the CDB actually go out is the
				// FIFO count").  The ROM is unaffected — its DMA-form
				// select starts from an empty FIFO either way.
				seq_step <= 3'd0;
				raise(I_DISC);
			end
		end
		7'h43: begin                                   // SELATNS
			// "Arbitrate, select and stop after IDENTIFY message" — the
			// form a driver uses when it has something to negotiate.  The
			// IDENTIFY byte leaves the FIFO; the CDB the driver preloaded
			// behind it stays there, and the driver flushes it before
			// building the message (NetBSD ncr53c9x, section 3.1).
			// Sequence step 1 with MESSAGE OUT visible in STATUS is what
			// the driver demands here — anything else and it resets the
			// chip (section 2.3 case 1).
			if (sel_ok) begin
				abort_nexus;
				cur_tgt <= sel_tgt;
				if (fifo_cnt != 0) fifo_shift;     // the IDENTIFY goes out
				phase          <= PH_MOUT;
				seq_step       <= 3'd1;
				cdb_active     <= 0;
				xfer_msg_out   <= 0;
				msg_first_seen <= 0;
				raise(I_BUS | I_FC);
			end
			else begin
				seq_step <= 3'd0;
				fifo_cnt <= 0;
				raise(I_DISC);
			end
		end
		7'h44, 7'h45: ;                                // en/dis selection
		7'h10: begin                                   // information transfer
			if (phase == PH_DIN) begin
				if (dma) begin
					xfer_in <= 1;
					chunk_irq_armed <= 1;
				end
				else if (fifo_cnt != 0) raise(I_BUS);  // byte already waiting
				else xfer_pio_in <= 1;
			end
			else if (phase == PH_DOUT) begin
				if (dma) begin
					xfer_out <= 1;
					chunk_irq_armed <= 1;
				end
				else xfer_pio_out <= 1;
			end
			else if (phase == PH_CMD) begin
				// TI while the CDB is still being collected: the ROM's
				// SCSICmd issues $90 here before pushing the bytes —
				// the DMA/TC latch above re-arms it; nothing else to do
			end
			else if (phase == PH_STAT) begin
				// treated like ICCS by some drivers
				fifo[0] <= scsi_status;
				fifo[1] <= 8'h00;
				fifo_cnt <= 5'd2;
				phase <= PH_MIN;
				raise(I_FC);
			end
			else if (phase == PH_MIN) begin
				// one message byte per TI, completing with FC (NetBSD
				// section 3.3): whatever the target has queued — $00
				// COMMAND COMPLETE after ICCS, $07 MESSAGE REJECT when a
				// negotiation was turned down.
				fifo[0] <= msgin_byte;
				fifo_cnt <= 5'd1;
				raise(I_FC);
			end
			else if (phase == PH_MOUT) begin
				// the driver preloaded a message; drain it and decide what
				// the target does next when the FIFO empties (above).
				// msg_first is cleared too, so a TI issued with an empty
				// FIFO completes as a zero-length message (-> COMMAND)
				// instead of re-deciding on the previous one.
				xfer_msg_out   <= 1;
				msg_first_seen <= 0;
				msg_first      <= 8'h00;
			end
			else raise(I_ILL);
		end
		7'h11: begin                                   // initiator cmd complete
			fifo[0] <= scsi_status;
			fifo[1] <= 8'h00;                          // command complete msg
			fifo_cnt <= 5'd2;
			phase <= PH_MIN;
			msgin_byte <= 8'h00;
			msgin_reject <= 0;
			raise(I_FC);
		end
		7'h12: begin                                   // message accept
			seq_step <= 3'd0;
			fifo_cnt <= 0;
			if (msgin_reject) begin
				// the message just acked was our MESSAGE REJECT, not a
				// COMMAND COMPLETE: the target stays connected and now
				// wants the command it was selected for.
				msgin_reject <= 0;
				msgin_byte   <= 8'h00;
				phase        <= PH_CMD;
				cdb_active   <= 1;
				cdb_pos      <= 0;
				cdb_need     <= 0;
				skip_cnt     <= 0;
				raise(I_BUS);
			end
			else begin
				phase <= PH_DOUT;
				raise(I_DISC);
			end
		end
		7'h18: begin                                   // transfer pad
			xfer_in <= 0; xfer_out <= 0;
			tc_zero <= 1;
			raise(I_BUS);
		end
		7'h1A, 7'h1B: ;                                // set/reset ATN
		default: raise(I_ILL);
		endcase
	end
endtask

//----------------------------------------------------------------------------
// CDB execution against the target — runs one cycle after the last CDB
// byte landed, so cdb[] is settled
//----------------------------------------------------------------------------
task exec_cdb;
	reg [7:0]  alloc;                 // 6-byte CDB allocation length
	reg [15:0] alloc16;               // 10-byte CDB allocation length
	begin
		scsi_status <= 8'h00;
		buf_valid <= 0;
		sbuf_pos <= 0;
		blocks_left <= 0;
		data_dir_in <= 1;
		dout_len <= 0;
		// deferred select interrupt: BS|FC with the command's phase visible
		raise(I_BUS | I_FC);
		alloc   = cdb[4];
		alloc16 = {cdb[7], cdb[8]};
		// the sense of the previous command clears on any command but
		// REQUEST SENSE (SCSI-1 semantics); a CHECK below re-latches it
		if (cdb[0] != 8'h03) begin
			tgt_skey[cur_tgt] <= 0;
			tgt_asc[cur_tgt]  <= 0;
		end

		msel_pend <= 0;
		if (is_cd && !mounted && cd_needs_media(cdb[0]))
			// AppleCD no-disc answer (MAME return_no_cd): NOT READY with the
			// vendor ASC $B0.  $3A here makes Mac OS nag to format the disc.
			check(4'h2, 8'hB0);
		else if (is_cd && ca_disc_audio && (cdb[0] == 8'h08 || cdb[0] == 8'h28 || cdb[0] == 8'hA8))
			// no data track: the Audio CD Access extension relies on this
			// failure to classify the disc (serving audio as data bombs the
			// Finder) -- ILLEGAL REQUEST, "illegal mode for this track"
			check(4'h5, 8'h64);
		else case (cdb[0])
		8'h00: begin                                   // TEST UNIT READY
			phase <= PH_STAT;
		end
		8'h03: begin                                   // REQUEST SENSE
			sense_r <= {4'd0, tgt_skey[cur_tgt]};
			asc_r   <= tgt_asc[cur_tgt];
			tgt_skey[cur_tgt] <= 0;
			tgt_asc[cur_tgt]  <= 0;
			synth(SY_SENSE, is_cd ? clamp(10'd18, alloc) : 10'd18);
		end
		8'h12: begin                                   // INQUIRY
			if (is_cd) synth(SY_CDINQ, clamp(10'd54, alloc));
			else       synth(SY_INQ, 10'd36);
		end
		8'h1A: begin                                   // MODE SENSE(6)
			if (is_cd) begin
				cd_page <= cdb[2][5:0];
				cap_r   <= (cd_blk512 ? disk_blocks : {2'b00, disk_blocks[31:2]}) - 32'd1;
				synth(SY_CDMODE, clamp((cdb[2][5:0] == 6'h30) ? 10'd36 :
				                       (cdb[2][5:0] == 6'h0E) ? 10'd28 :
				                       (cdb[2][5:0] == 6'h2A) ? 10'd38 : 10'd12, alloc));
			end
			else if (cdb[2][5:0] == 6'h30) begin       // Apple firmware ID page
				cap_r <= disk_blocks - 32'd1;
				synth(SY_HDMODE, clamp(10'd36, alloc));
			end
			else synth(SY_MODE, 10'd4);
		end
		8'h15: begin                                   // MODE SELECT(6)
			if (is_cd) begin
				param_out({4'd0, alloc});
				msel_pend <= (alloc >= 8'd12);             // header + descriptor at least
			end
			else check(4'h5, 8'h20);
		end
		8'h25: begin                                   // READ CAPACITY(10)
			cap_cd <= cd_x4;
			cap_r  <= cd_x4 ? ({2'b00, disk_blocks[31:2]} - 32'd1) : (disk_blocks - 32'd1);
			synth(SY_CAP, 10'd8);
		end
		8'h08: begin                                   // READ(6)
			read_blocks({11'd0, cdb[1][4:0], cdb[2], cdb[3]},
			            (cdb[4] == 0) ? 32'd256 : {24'd0, cdb[4]});
		end
		8'h28: begin                                   // READ(10)
			read_blocks({cdb[2], cdb[3], cdb[4], cdb[5]}, {16'd0, cdb[7], cdb[8]});
		end
		8'hA8: begin                                   // READ(12)
			if (is_cd) read_blocks({cdb[2], cdb[3], cdb[4], cdb[5]},
			                       {cdb[6], cdb[7], cdb[8], cdb[9]});
			else check(4'h5, 8'h20);
		end
		8'h0A: begin                                   // WRITE(6)
			if (is_cd) check(4'h7, 8'h27);             // DATA PROTECT, write protected
			else begin
				lba <= {11'd0, cdb[1][4:0], cdb[2], cdb[3]};
				blocks_left <= (cdb[4] == 0) ? 32'd256 : {24'd0, cdb[4]};
				data_dir_in <= 0;
				phase <= PH_DOUT;
			end
		end
		8'h2A: begin                                   // WRITE(10)
			if (is_cd) check(4'h7, 8'h27);
			else begin
				lba <= {cdb[2], cdb[3], cdb[4], cdb[5]};
				blocks_left <= {16'd0, cdb[7], cdb[8]};
				data_dir_in <= 0;
				phase <= PH_DOUT;
			end
		end
		8'h1B: begin                                   // START/STOP UNIT
			// LoEj=1 Start=0 is the eject the System 7 / 8 AppleCD driver
			// actually issues (Put Away); Apple's own $C0 does the same.
			if (is_cd && cdb[4][1] && !cdb[4][0]) eject;
			else phase <= PH_STAT;
		end
		8'hC0: begin                                   // Apple EJECT
			if (is_cd) eject; else check(4'h5, 8'h20);
		end
		8'h1E: begin                                   // PREVENT/ALLOW MEDIUM REMOVAL
			if (is_cd) cd_prevent <= cdb[4][0];
			phase <= PH_STAT;
		end
		8'hBB: begin                                   // SET CD SPEED: advisory
			if (is_cd) phase <= PH_STAT; else check(4'h5, 8'h20);
		end
		// READ TOC / READ SUB-CHANNEL serve EXACTLY the allocation length,
		// zero-filled past the payload: the Mac's blind transfer arms the
		// whole allocation and a target that stops early leaves it waiting
		// (MacLC scsi.v, the 2026-07-19 boot wedge).  Caps: 512 = the table.
		8'h43: begin                                   // READ TOC
			if (!is_cd) check(4'h5, 8'h20);
			else if (cdb[9][7:6] == 2'b10) synth(SY_TOC43F2, clamp(10'd512, alloc16));
			else if (cdb[9][7:6] == 2'b01) synth(SY_TOC43F1, clamp(10'd512, alloc16));
			else                            synth(SY_TOC43, clamp(10'd512, alloc16));
		end
		8'hC1: begin                                   // Apple READ TOC
			// header / lead-out: 4 bytes (MAME); descriptors: the allocation,
			// whole descriptors
			if (!is_cd) check(4'h5, 8'h20);
			else if (cdb[9][7]) synth(SY_TOCC1, clamp(10'd400, {alloc16[15:2], 2'b00}));
			else                synth(SY_TOCC1, clamp(10'd4, alloc16));
		end
		8'hC2: begin                                   // Apple READ Q SUBCODE
			if (is_cd) synth(SY_SUBQ, 10'd9); else check(4'h5, 8'h20);
		end
		8'hCC: begin                                   // Apple AUDIO STATUS
			if (is_cd) synth(SY_ASTAT, 10'd6); else check(4'h5, 8'h20);
		end
		8'h42: begin                                   // READ SUB-CHANNEL
			if (is_cd) synth(SY_SUBCH, clamp(10'd64, alloc16)); else check(4'h5, 8'h20);
		end
		8'h44: begin                                   // READ HEADER (LBA form)
			if (!is_cd) check(4'h5, 8'h20);
			else if (cdb[1][1]) check(4'h5, 8'h24);    // MSF form: invalid field
			else begin
				hdr_lba <= {cdb[2], cdb[3], cdb[4], cdb[5]};
				synth(SY_HDR, clamp(10'd16, alloc16));
			end
		end
		8'hCE: begin                                   // Apple AUDIO CONTROL: discard
			if (is_cd) param_out({4'd0, cdb[8]}); else check(4'h5, 8'h20);
		end
		// audio transport, accepted as no-ops until the audio engine lands:
		// Apple $C8-$CB/$CD, standard PLAY/PAUSE/STOP forms, REZERO/SEEK
		8'hC8, 8'hC9, 8'hCA, 8'hCB, 8'hCD,
		8'h45, 8'h47, 8'h48, 8'h4B, 8'h4E, 8'hA5,
		8'h01, 8'h0B, 8'h2B: begin
			if (is_cd) begin ca_cmd_stb <= 1; phase <= PH_STAT; end
			else check(4'h5, 8'h20);
		end
		default: check(4'h5, 8'h20);                   // ILLEGAL REQUEST, opcode
		endcase
	end
endtask

// commands that need a disc in the drive (CD-ROM target)
function cd_needs_media(input [7:0] op);
	case (op)
	8'h00, 8'h08, 8'h28, 8'hA8, 8'h25, 8'h43, 8'hC1, 8'hC2, 8'hCC, 8'hCE,
	8'h42, 8'h44, 8'hC8, 8'hC9, 8'hCA, 8'hCB, 8'hCD, 8'h45, 8'h47, 8'h48,
	8'h4B, 8'h4E, 8'hA5, 8'h01, 8'h0B, 8'h2B: cd_needs_media = 1'b1;
	default: cd_needs_media = 1'b0;
	endcase
endfunction

// the smaller of a natural response length and the CDB's allocation
function [9:0] clamp(input [9:0] natural, input [15:0] alloc_len);
	clamp = (alloc_len < {6'd0, natural}) ? alloc_len[9:0] : natural;
endfunction

// queue a synthesized DATA IN response (0 bytes: straight to STATUS)
task synth(input [3:0] kind, input [9:0] len);
	if (len == 0) phase <= PH_STAT;
	else begin
		synth_kind <= kind; synth_idx <= 0; synth_len <= len;
		sbuf_len <= len;
		phase <= PH_DIN;
	end
endtask

// a parameter-list DATA OUT of n bytes, absorbed into the sector buffer
task param_out(input [11:0] n);
	if (n == 0) phase <= PH_STAT;
	else begin
		dout_len <= n;
		data_dir_in <= 0;
		phase <= PH_DOUT;
	end
endtask

// Drop the current nexus: the target goes bus free and forgets any
// transfer in progress.  A SCSI bus reset does this to every target, and a
// new selection does it to whatever the previous nexus left behind -- the
// ROM's boot scan reads block 0 of the CD-ROM with a 512-byte request,
// gets a 2048-byte block, times out waiting for STATUS, resets the bus and
// moves on; without this the stale DATA IN state met its next command.
task abort_nexus;
	cdb_active <= 0; exec_pending <= 0; skip_cnt <= 0;
	xfer_in <= 0; xfer_out <= 0; xfer_pio_in <= 0; xfer_pio_out <= 0;
	xfer_msg_out <= 0; msg_first_seen <= 0; msgin_reject <= 0;
	chunk_irq_armed <= 0;
	buf_valid <= 0; sbuf_pos <= 0; blocks_left <= 0; dout_len <= 0;
	synth_len <= 0; msel_pend <= 0; msel_st <= 0; msel_bd <= 0;
	if (io_busy && !flush_pending) io_discard <= 1;
endtask

// CHECK CONDITION with the sense the next REQUEST SENSE will report
task check(input [3:0] key, input [7:0] asc);
	tgt_skey[cur_tgt] <= key;
	tgt_asc[cur_tgt]  <= asc;
	scsi_status <= 8'h02;
	phase <= PH_STAT;
endtask

// a READ: CD-ROM logical blocks are 2048 bytes = four HPS blocks, unless a
// MODE SELECT put the drive in 512-byte blocks
task read_blocks(input [31:0] l, input [31:0] n);
	lba <= cd_x4 ? {l[29:0], 2'b00} : l;
	blocks_left <= cd_x4 ? {n[29:0], 2'b00} : n;
	if (is_cd) ca_read_stb <= 1;                       // a data read stops playback
	phase <= PH_DIN;
endtask

// eject the disc: GOOD, media gone, the sense a later ask will see
task eject;
	if (cd_prevent) check(4'h5, 8'h80);
	else begin
		tgt_mounted[2] <= 0;
		tgt_skey[2] <= 4'h2;
		tgt_asc[2]  <= 8'h3A;                          // medium not present
		ca_eject_stb <= 1;
		phase <= PH_STAT;
	end
endtask

//----------------------------------------------------------------------------
// the CD-ROM target's TOC / audio engine
//----------------------------------------------------------------------------
cd_audio #(.CLK_HZ(32'd33_000_000)) cd_audio_i (
	.clk(clk), .rst(!nreset), .bus_rst(ca_bus_rst),
	.mounted(tgt_mounted[2]), .img_mounted(ca_mount_d[1]), .img_blocks(tgt_blocks[2]),
	.cmd_stb(ca_cmd_stb), .cmd_op(cdb[0]),
	.cdb1(cdb[1]), .cdb2(cdb[2]), .cdb3(cdb[3]), .cdb4(cdb[4]),
	.cdb5(cdb[5]), .cdb6(cdb[6]), .cdb7(cdb[7]), .cdb8(cdb[8]), .cdb9(cdb[9]),
	.read_stb(ca_read_stb), .eject_stb(ca_eject_stb),
	.ap_ch0(ap_ch0), .ap_vol0(ap_vol0), .ap_ch1(ap_ch1), .ap_vol1(ap_vol1),
	.ch_grant(ca_grant),
	.ca_io_active(ca_io_active), .ca_io_rd(ca_io_rd), .ca_io_lba(ca_io_lba),
	.io_ack(io_ack[2]),
	.sd_buff_addr(sd_buff_addr[7:0]), .sd_buff_addr_hi(sd_buff_addr[12:8]),
	.sd_buff_dout(sd_buff_dout), .sd_buff_wr(sd_buff_wr),
	.ast_code(ca_ast_code), .cur_ctrl(ca_cur_ctrl), .cur_trk(ca_cur_trk),
	.abs_m(ca_abs_m), .abs_s(ca_abs_s), .abs_f(ca_abs_f),
	.rel_m(ca_rel_m), .rel_s(ca_rel_s), .rel_f(ca_rel_f),
	.toc_base(toc_addr), .toc_q0(ca_toc_q0), .toc_q1(), .toc_q2(), .toc_q3(),
	.toc_ready(ca_toc_ready),
	.toc43_base(t43_addr), .toc43_q0(ca_t43_q0), .toc43_q1(), .toc43_q2(), .toc43_q3(),
	.toc43_len(ca_t43_len),
	.toc2_base(t2_addr), .toc2_q0(ca_t2_q0), .toc2_q1(), .toc2_q2(), .toc2_q3(),
	.toc2_len(ca_t2_len),
	.disc_audio(ca_disc_audio),
	.snd_l(cd_snd_l), .snd_r(cd_snd_r),
	.dbg_cda0(), .dbg_cdur()
);

endmodule

//============================================================================
//  ncr_sbuf — the 53c96 target's sector buffer as 256 x 16 block RAM.
//  Port E: engine side, byte-lane writes (be_e[1] = high byte = even
//  byte address).  Port S: platform side, full-word writes.  Both reads
//  registered (M10K semantics).  The two ports never write the same
//  word in the same cycle (loads run only during io_rd service of read
//  commands; drain and synth writes only outside them), and mixed-port
//  read-during-write collisions are excluded by buf_valid/flush_pending
//  gating in the engine — DONT_CARE on hardware, old-data in the sim
//  branch, neither reachable.
//============================================================================
module ncr_sbuf
(
	input         clk,
	input   [7:0] addr_e,
	input  [15:0] din_e,
	input   [1:0] be_e,
	input         we_e,
	output [15:0] q_e,
	input   [7:0] addr_s,
	input  [15:0] din_s,
	input         we_s,
	output [15:0] q_s
);

`ifdef VERILATOR

	reg [15:0] mem [0:255];
	reg [15:0] q_e_r, q_s_r;
	always @(posedge clk) begin
		if (we_e) begin
			if (be_e[1]) mem[addr_e][15:8] <= din_e[15:8];
			if (be_e[0]) mem[addr_e][7:0]  <= din_e[7:0];
		end
		if (we_s) mem[addr_s] <= din_s;
		q_e_r <= mem[addr_e];
		q_s_r <= mem[addr_s];
	end
	assign q_e = q_e_r;
	assign q_s = q_s_r;

`else

	altsyncram ram
	(
		.clock0    (clk),
		.address_a (addr_e),
		.data_a    (din_e),
		.wren_a    (we_e),
		.byteena_a (be_e),
		.q_a       (q_e),

		.address_b (addr_s),
		.data_b    (din_s),
		.wren_b    (we_s),
		.q_b       (q_s),

		.aclr0(1'b0),
		.aclr1(1'b0),
		.addressstall_a(1'b0),
		.addressstall_b(1'b0),
		.byteena_b(1'b1),
		.clock1(1'b1),
		.clocken0(1'b1),
		.clocken1(1'b1),
		.clocken2(1'b1),
		.clocken3(1'b1),
		.eccstatus(),
		.rden_a(1'b1),
		.rden_b(1'b1)
	);
	defparam
		ram.numwords_a = 256,
		ram.widthad_a  = 8,
		ram.width_a    = 16,
		ram.width_byteena_a = 2,
		ram.numwords_b = 256,
		ram.widthad_b  = 8,
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

endmodule
