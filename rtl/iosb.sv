//============================================================================
//  iosb — the Quadra 800's I/O ASIC on the machine beat port.
//
//  Stage 2 scope (MAME iosb.cpp / pseudovia.cpp as reference): VIA1 (real
//  6522 at $50000000, 512-byte register stride, byte replicated across the
//  lanes), the quadra pseudo-VIA at $50002000 (ports + IFR/IER only, no
//  timers), the IOSB config registers at $50018000, the $A55A2BAD ID at
//  $5FFF0000, and the 3-level interrupt scheme (SCC=4, VIA2=2, VIA1=1).
//  SWIM2/ASC/SCC/SCSI/SONIC decode as present-but-inert: reads 0, writes
//  discarded, always acked — the real chips arrive in later stages.
//
//  Beat slave: sel is held until the single-cycle ack; rdata valid at ack.
//============================================================================

module iosb
#(
	parameter E_HALF    = 21,       // clk per E phase: 33 MHz/21 ~ 783.4 kHz VIA timers
	parameter TICK_HALF = 274314,   // clk per CA1 half-period: 60.15 Hz tick
	// Escape hatch for a wedged pseudo-DMA beat (A_SDMA).  ce is tied high at
	// 33 MHz, so 2^18 ~ 7.9 ms: orders of magnitude longer than a legitimate
	// DRQ latency (a byte arrives in microseconds), and ~8x SHORTER than the
	// AP040 core's own 2^21 stall watchdog in wombat_cpu.sv.  That ordering is
	// the point -- the fault is reported here, with the bus released, instead
	// of surfacing as an unrecoverable core stall.  See the A_SDMA comment.
	//
	// This budget only covers IDLE waiting: the counter is frozen while a
	// platform block transfer is outstanding, because SD latency dwarfs it.
	// Do not "fix" a spurious timeout by growing this -- past 2^21 the core
	// watchdog wins and the deadlock this exists to break comes back.
	parameter SDMA_TIMEOUT_BITS = 18
)
(
	input         clk,
	input         nreset,
	input         ce,

	// beat slave (offset within $50000000-$5FFFFFFF)
	input         sel,
	input         write,
	input  [27:2] addr,
	input   [3:0] be,
	input  [31:0] wdata,
	output reg [31:0] rdata,
	output reg    ack,
	// Asserted with the ack that releases a TIMED-OUT pseudo-DMA beat, so the
	// bus adapter can turn it into a bus error instead of returning junk data.
	output reg    sdma_fault,

	// device interrupt lines (stage 3+ sources; quiet today)
	input         vbl_irq,
	input         scsi_irq,
	input         scsi_drq,
	input         asc_irq,

	// SCC (Zilog 85C30) serial pins.  The chip itself is instantiated in this
	// module.  On real hardware it is NOT inside the IOSB -- MAME wires it
	// straight into the CPU map at $5000C000 (macquadra800.cpp:163) -- but on
	// this core every $5xxxxxxx beat already lands here, so this is where the
	// bus adapter belongs.  Channel A = modem port, channel B = printer port.
	input         scc_rxd_a,
	output        scc_txd_a,
	input         scc_cts_a,
	output        scc_rts_a,
	input         scc_rxd_b,
	output        scc_txd_b,

	output  [2:0] ipl_n,           // active-low to the CPU

	output signed [15:0] audio_l,
	output signed [15:0] audio_r,

	// SCSI disk on the MiSTer block-device interface
	input         img_mounted,
	input  [63:0] img_size,
	output [31:0] io_lba,
	output  [5:0] io_blk_cnt,
	output        io_rd,
	output        io_wr,
	input         io_ack,
	input  [12:0] sd_buff_addr,
	input  [15:0] sd_buff_dout,
	output [15:0] sd_buff_din,
	input         sd_buff_wr,

	// ADB input devices
	input  [10:0] ps2_key,
	input  [24:0] ps2_mouse,

	// Unix seconds from the HPS, straight through to the RTC
	input  [32:0] timestamp
);

//----------------------------------------------------------------------------
// E-clock enables and the 60.15 Hz tick
//----------------------------------------------------------------------------
reg [$clog2(E_HALF)-1:0] ediv;
reg        ephase;
wire       e_pulse   = (ediv == E_HALF-1);
wire       e_rising  = e_pulse && !ephase;
wire       e_falling = e_pulse &&  ephase;

reg [$clog2(TICK_HALF)-1:0] tickdiv;
reg        tick_60hz;

// VIA1 CA2 = the one-second interrupt, and Mac OS needs it to advance its
// clock: without it the menu bar simply never ticks (it sat frozen through a
// whole session, first at the 1904 "Fri 12:00" and then at whatever the RTC was
// seeded with). CA2 was tied to 0 here.
//
// On a real Quadra this line comes from the RTC chip. Deriving it from 60 CA1
// periods is 0.9975 s rather than exactly 1 s, which is what MacLC_MiSTer does
// (dataController_top.sv:729) and is fine for timekeeping -- the OS re-reads the
// RTC anyway, and that is now seeded from the host clock.
reg  [5:0] tick_count;
reg        tick_60hz_d;
wire       onesec = (tick_count == 6'd59);

always @(posedge clk) begin
	if (!nreset) begin
		ediv <= 0; ephase <= 0;
		tickdiv <= 0; tick_60hz <= 0;
		tick_count <= 0; tick_60hz_d <= 0;
	end
	else begin
		// count CA1 periods for the one-second line
		tick_60hz_d <= tick_60hz;
		if (tick_60hz && !tick_60hz_d)
			tick_count <= onesec ? 6'd0 : tick_count + 1'b1;

		ediv <= e_pulse ? '0 : ediv + 1'b1;
		if (e_pulse) ephase <= ~ephase;
		if (tickdiv == TICK_HALF-1) begin
			tickdiv <= 0;
			tick_60hz <= ~tick_60hz;
		end
		else tickdiv <= tickdiv + 1'b1;
	end
end

//----------------------------------------------------------------------------
// VIA1 — machine ID $12 on port A (PA1|PA4); port B: PB0/1/2 bit-bang the
// RTC (data/clock/enable), PB3 reads the ADB interrupt (high = none)
//----------------------------------------------------------------------------
reg        via1_ren, via1_wen;
reg  [3:0] via1_addr;
reg  [7:0] via1_din;
wire [7:0] via1_dout;
wire       via1_irq;
wire [7:0] via1_pbo, via1_pbt;

// undriven VIA pins float high through the pull-ups
wire rtc_ce_n  = via1_pbt[2] ? via1_pbo[2] : 1'b1;
wire rtc_clk   = via1_pbt[1] ? via1_pbo[1] : 1'b1;
wire rtc_din   = via1_pbt[0] ? via1_pbo[0] : 1'b1;
wire rtc_dout, rtc_doe;
wire rtc_line  = rtc_doe ? rtc_dout : 1'b1;

rtc3430042 rtc (
	.clk(clk),
	.nreset(nreset),
	.timestamp(timestamp),
	.ce_n(rtc_ce_n),
	.clk_in(rtc_clk),
	.data_in(rtc_din),
	.data_out(rtc_dout),
	.data_oe(rtc_doe)
);

wire       via1_sr_active;
reg        via1_sr_ext_complete, via1_sr_ext_load;
reg  [7:0] via1_sr_ext_data;
wire       adb_int_n;

via6522 via1 (
	.clock     (clk),
	.rising    (e_rising),
	.falling   (e_falling),
	.timer_tick(e_falling),        // T1/T2 count at the 783 kHz E rate
	.reset     (!nreset),

	.addr      (via1_addr),
	.wen       (via1_wen),
	.ren       (via1_ren),
	.data_in   (via1_din),
	.data_out  (via1_dout),

	.phi2_ref  (),

	.port_a_o  (),
	.port_a_t  (),
	.port_a_i  (8'h12),
	.port_b_o  (via1_pbo),
	.port_b_t  (via1_pbt),
	.port_b_i  ({4'b0000, adb_int_n, 2'b00, rtc_line}),

	.ca1_i     (tick_60hz),
	.ca2_o     (),
	.ca2_i     (onesec),
	.ca2_t     (),
	.cb1_o     (),
	.cb1_i     (1'b0),
	.cb1_t     (),
	.cb2_o     (),
	.cb2_i     (1'b0),
	.cb2_t     (),
	.ca2_lvl_i (1'b0),
	.cb2_lvl_i (1'b0),

	.irq       (via1_irq),
	.dbg_irq_state (),
	.sr_active (via1_sr_active),

	.sr_ext_complete (via1_sr_ext_complete),
	.sr_ext_load     (via1_sr_ext_load),
	.sr_ext_data     (via1_sr_ext_data)
);

//----------------------------------------------------------------------------
// ADB modem (Mac II style): the ROM talks to it through VIA1's shift
// register (CB1/CB2) with the state bits on PB4/PB5 and the interrupt on
// PB3.  adb.sv + the Snow-style timer shim come from lbmactwo_MiSTer,
// where this exact arrangement is hardware-proven.
//----------------------------------------------------------------------------
wire ADBST0 = ~via1_pbt[4] | via1_pbo[4];
wire ADBST1 = ~via1_pbt[5] | via1_pbo[5];
wire adb_bus_idle = ADBST0 & ADBST1;
wire adb_resp_pending;
wire [7:0] adb_dout;
wire       adb_dout_strobe;
reg  [7:0] adb_din;
reg        adb_din_strobe;

// ~8 MHz enable for the transceiver's bit timing
reg [1:0] adbdiv;
wire adb_en = (adbdiv == 2'd3);
always @(posedge clk) adbdiv <= !nreset ? 2'd0 : adbdiv + 1'b1;

adb adbx (
	.clk(clk),
	.clk_en(adb_en),
	.reset(~nreset),
	.st({ADBST1, ADBST0}),
	._int(adb_int_n),
	.viaBusy(1'b0),
	.listen(),
	.adb_din(adb_din),
	.adb_din_strobe(adb_din_strobe),
	.adb_dout(adb_dout),
	.adb_dout_strobe(adb_dout_strobe),

	.ps2_mouse(ps2_mouse),
	.ps2_key(ps2_key),
	.resp_pending(adb_resp_pending),
	.dbg_adb(),
	.mouse_has_event_o()
);

// VIA1 SR shim (lbmactwo): the qualified 6522 access edge is A_VIA at
// e_falling with via1_addr/din held; SR reg $A, ACR reg $B
wire via1_access = (astate == A_VIA) && e_falling;
wire via1_sr_wr  = via1_access && via1_wen && (via1_addr == 4'hA);
wire via1_acr_wr = via1_access && via1_wen && (via1_addr == 4'hB);
wire via1_sr_rd  = via1_access && via1_ren && (via1_addr == 4'hA);

reg [2:0] via1_acr_shift_mode;
reg [7:0] via1_sr_shadow;
reg [21:0] via1_shift_timer;
reg via1_shift_dir;                // 1 = shift-out, 0 = shift-in
reg via1_sr_out_pending;
reg via1_sr_out_ack;
reg via1_kbd_to_mac_fresh;
reg [7:0] kbd_to_mac;

localparam SHIFT_DELAY = 22'd100000;    // ~3 ms at 33 MHz
localparam IDLE_DELAY  = 22'd363000;    // ~11 ms autopoll heartbeat

always @(posedge clk) begin
	if (!nreset) begin
		via1_acr_shift_mode <= 3'b000;
		via1_sr_shadow <= 8'h00;
		via1_shift_timer <= 22'd0;
		via1_shift_dir <= 1'b0;
		via1_sr_ext_complete <= 1'b0;
		via1_sr_ext_load <= 1'b0;
		via1_sr_ext_data <= 8'h00;
		via1_sr_out_pending <= 1'b0;
		via1_sr_out_ack <= 1'b0;
		via1_kbd_to_mac_fresh <= 1'b0;
		kbd_to_mac <= 8'h00;
		adb_din <= 8'h00;
		adb_din_strobe <= 1'b0;
	end
	else begin
		via1_sr_ext_complete <= 1'b0;
		via1_sr_ext_load <= 1'b0;

		// ---- ADB transceiver handshake: adb_en domain ONLY -----------------
		// adb.sv's entire body sits under `else if (clk_en)` (adb.sv:297), so
		// it samples its inputs and updates its outputs once per adb_en tick
		// (clk/4). Driving this handshake at full clk is wrong in BOTH
		// directions, and the rest of this shim genuinely does belong at full
		// clk (via1_access/e_falling are full-clk events, the timers are
		// counted in clk cycles), so only these two pieces move:
		//
		//   adb_din_strobe as a one-clk pulse is invisible to the transceiver
		//   three ticks out of four -> ADB command bytes silently dropped.
		//   Set and cleared here, it is held for a whole enable period.
		//
		//   adb_dout_strobe stays high for a whole enable period, so sampling
		//   it every clk re-latches the same response byte and re-arms
		//   via1_kbd_to_mac_fresh right after the completion below clears it
		//   -> one response byte delivered to the VIA several times.
		//
		// Either desynchronises Talk/response framing, which is how mouse
		// packet bytes end up being read as keyboard data. lbmactwo drives
		// both sides from its clk8_en_p domain (dataController_top.sv:798 for
		// the capture, and the enable-gated block at :1002 for the strobe);
		// adb.sv itself is byte-identical between the two cores, so matching
		// that gating is the whole fix.
		if (adb_en) begin
			adb_din_strobe  <= 1'b0;
			via1_sr_out_ack <= 1'b0;

			if (adb_dout_strobe) begin
				kbd_to_mac            <= adb_dout;
				via1_kbd_to_mac_fresh <= 1'b1;
			end

			// shift-out completion delivers the command byte to the modem
			if (via1_sr_out_pending && !via1_sr_out_ack) begin
				adb_din             <= via1_sr_shadow;
				adb_din_strobe      <= 1'b1;
				via1_sr_out_ack     <= 1'b1;
				via1_sr_out_pending <= 1'b0;
			end
		end

		if (via1_acr_wr) begin
			via1_acr_shift_mode <= via1_din[4:2];
			if (via1_din[4:2] == 3'b111 && via1_acr_shift_mode != 3'b111) begin
				via1_shift_timer <= SHIFT_DELAY;
				via1_shift_dir <= 1'b1;
			end
			else if (via1_din[4:2] == 3'b011 && via1_acr_shift_mode != 3'b011) begin
				via1_shift_timer <= SHIFT_DELAY;
				via1_shift_dir <= 1'b0;
			end
			else if (via1_din[4:2] == 3'b000)
				via1_shift_timer <= 22'd0;
		end

		// an SR read in shift-in mode re-arms the next shift (autopoll
		// heartbeat); fast only while a real response byte is on the way
		if (via1_sr_rd && via1_acr_shift_mode == 3'b011) begin
			via1_shift_timer <= adb_resp_pending ? SHIFT_DELAY : IDLE_DELAY;
			via1_shift_dir <= 1'b0;
		end

		if (via1_sr_wr) begin
			via1_sr_shadow <= via1_din;
			if (via1_acr_shift_mode == 3'b111) begin
				via1_shift_timer <= SHIFT_DELAY;
				via1_shift_dir <= 1'b1;
			end
			if (via1_acr_shift_mode == 3'b011) begin
				via1_shift_timer <= SHIFT_DELAY;
				via1_shift_dir <= 1'b0;
			end
		end

		if (via1_shift_timer > 22'd1)
			via1_shift_timer <= via1_shift_timer - 22'd1;

		if (via1_shift_dir) begin
			if (via1_shift_timer == 22'd1) begin
				via1_shift_timer <= 22'd0;
				via1_sr_ext_complete <= 1'b1;
				via1_sr_out_pending <= 1'b1;
			end
		end
		else begin
			// shift-in completes the instant a fresh byte exists; the timer
			// path only fires when nothing is pending (or the bus idled)
			if (via1_kbd_to_mac_fresh) begin
				via1_shift_timer <= 22'd0;
				via1_sr_ext_complete <= 1'b1;
				via1_sr_ext_load <= 1'b1;
				via1_sr_ext_data <= kbd_to_mac;
				via1_kbd_to_mac_fresh <= 1'b0;
			end
			// `via1_sr_active` is the fix: only ever complete a shift the VIA
			// actually has ARMED. Without it this branch fabricated shift
			// completions out of nothing, and via6522.sv:190 makes every
			// sr_ext_complete raise IFR bit 2 -- so the shim was firing the
			// VIA1 shift-register interrupt at the ADB driver roughly every
			// 11 ms whether or not the ROM had asked for a byte. The driver
			// consumes each one as a real device response.
			//
			// Instrumented in sim: all 338 fallback completions in a boot
			// window fired with the ADB bus IDLE (st=11) and no interrupt
			// asserted -- i.e. completions the real PIC would never have
			// clocked, because it only clocks CB1 when it has data to send.
			//
			// There is no safe byte to invent here, which is what makes the
			// completion itself the bug. Proved on hardware: delivering $FF
			// (the "no data" value QEMU and MAME use, and correct for a
			// keyboard poll) decodes in an ADB mouse Talk R0 as
			// {~button, dy} / {1, dx} with 7-bit SIGNED deltas, so $FF = -1,
			// and the injected reports became a permanently drifting cursor.
			// $00 would read as a phantom button-down instead. Both symptoms
			// are the same defect: a response the transceiver never produced.
			else if (via1_shift_timer == 22'd1 && via1_sr_active) begin
				if (!adb_resp_pending || adb_bus_idle) begin
					via1_shift_timer <= 22'd0;
					via1_sr_ext_complete <= 1'b1;
					via1_sr_ext_load <= 1'b1;
					via1_sr_ext_data <= kbd_to_mac;
				end
			end
		end
	end
end

//----------------------------------------------------------------------------
// VIA2 — quadra pseudo-VIA (MAME quadra_pseudovia_device): ports and
// IFR/IER only.  IFR bits: 0 SCSI DRQ, 1 any-slot (VBL/NuBus/SONIC via
// nubus_irqs), 3 SCSI IRQ, 4 ASC (latched).  Port A reads the active-low
// per-source slot status.
//----------------------------------------------------------------------------
reg  [7:0] via2_ifr;      // bit 7 = summary, computed below
reg  [7:0] via2_ier;
wire [7:0] nubus_irqs = {1'b1, ~vbl_irq, 6'b111111};  // bit 6 = internal video (QEMU VIA2_NUBUS_IRQ_INTVIDEO); 5:0 = slots E..9 idle
wire       slot_any   = (nubus_irqs & 8'h79) != 8'h79;

reg vbl_d, scsi_d, drq_d, asc_d, slot_d;
// The ASC interrupt: the port comes in from quadra800.sv (tied 0 there) and
// the real source is the EASC below. Without it the Sound Manager fills the
// FIFO once and is never told to refill, so a sound plays for 1024 samples
// (46 ms) and stops.
wire asc_irq_i = asc_irq | easc_irq;
wire easc_irq;
wire via2_active = |(via2_ifr[6:0] & via2_ier[6:0] & 7'h1b);
wire [7:0] via2_ifr_r = {via2_active, via2_ifr[6:0]};
wire scsi_irq_i = scsi_irq | ncr_irq;
wire scsi_drq_i = scsi_drq | ncr_drq;

//----------------------------------------------------------------------------
// IOSB config registers: 16-bit scratch at 256-byte strides, readback only
// (reg 2 also times Turbo SCSI pseudo-DMA — consumed in stage 3)
//----------------------------------------------------------------------------
reg [15:0] iosb_regs [0:31];

//----------------------------------------------------------------------------
// djMEMC memory controller registers at $5000E000 (QEMU hw/misc/djmemc.c:
// interleave, bank0-9 config, memtop, config, refresh).  Architecturally
// djMEMC's, but they live in the I/O block this module decodes.  The ROM's
// RAM sizing writes bank configurations and reads them back — scratch
// readback is what the known-good QEMU model provides.
//----------------------------------------------------------------------------
reg [31:0] djmemc_regs [0:15];

//----------------------------------------------------------------------------
// Decode (offset relative to $50000000; MAME iosb.cpp map with mirrors)
//----------------------------------------------------------------------------
wire in_low     = (addr[27:24] == 4'h0);
wire sel_via1   = in_low && (addr[17:13] == 5'b00000);
wire sel_via2   = in_low && (addr[19:13] == 7'b0000001);
wire sel_regs   = in_low && (addr[19:13] == 7'b0001100);
wire sel_djmemc = in_low && (addr[19:13] == 7'b0000111);   // $E000-$FFFF
wire sel_asc    = in_low && (addr[19:12] == 8'h14);
// I/O space repeats every $40000 (dev note: $50040000-$53FFFFFF are images),
// so bits 19:18 are don't-care here.  The ROM uses the +$40000 image of the
// PDMA window as its 32-bit bulk port ($50F50100) and the base image for
// word/byte accesses — both must decode.
wire sel_scsi   = in_low && (addr[17:8] == 10'h100);   // 53C96 regs, 16-byte strides
wire sel_sdma   = in_low && (addr[17:8] == 10'h101);   // Turbo SCSI pseudo-DMA
wire sel_id     = (addr[27:16] == 12'hFFF);
// SCC at $5000C000-$5000DFFF.  MAME maps it .mirror(0x00fc0000), i.e. bits
// 23:18 are don't-care, so this decodes on [17:13] rather than the strict
// [19:13] the VIA2/djMEMC selects use -- same reasoning as sel_scsi above.
wire sel_scc    = in_low && (addr[17:13] == 5'b00110);
wire [3:0] rsel = addr[12:9];

//----------------------------------------------------------------------------
// NCR 53C96 + Turbo SCSI pseudo-DMA
//----------------------------------------------------------------------------
wire       scsi_strobe = ce && (astate == A_IDLE) && sel && !ack && sel_scsi;
wire [7:0] ncr_rdata;
reg        sdma_rd, sdma_wr;
wire [7:0] sdma_rbyte;
reg  [7:0] sdma_wbyte;
wire       sdma_valid;
wire       ncr_irq, ncr_drq;
reg  [2:0] sdma_left;              // bytes still to move in this beat
reg [31:0] sdma_shift;
reg [SDMA_TIMEOUT_BITS-1:0] sdma_watch;   // A_SDMA hold-off watchdog

`ifdef SIMULATION
// Own cycle counter so the timeout tap can print in the same "[NCR <cycle>]"
// form as the ncr53c96 taps (ncr53c96's dbg_cyc is local to that module).
reg [63:0] iosb_dbg_cyc;
initial iosb_dbg_cyc = 0;
always @(posedge clk) if (ce) iosb_dbg_cyc <= iosb_dbg_cyc + 64'd1;
`endif

ncr53c96 #(.DISK_ID(0)) scsi (
	.clk(clk),
	.nreset(nreset),
	.ce(ce),

	.sel(scsi_strobe),
	.write(write),
	.rs(addr[7:4]),
	.wdata(wbyte),
	.rdata(ncr_rdata),

	.dma_rd(sdma_rd),
	.dma_wr(sdma_wr),
	.dma_wdata(sdma_wbyte),
	.dma_rdata(sdma_rbyte),
	.dma_valid(sdma_valid),
	.drq(ncr_drq),
	.irq(ncr_irq),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.io_lba(io_lba),
	.io_blk_cnt(io_blk_cnt),
	.io_rd(io_rd),
	.io_wr(io_wr),
	.io_ack(io_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr)
);

//----------------------------------------------------------------------------
// EASC — stereo FIFO (every Mac OS sound) plus the wavetable boot chime
//----------------------------------------------------------------------------
wire        asc_stb = ce && (astate == A_IDLE) && sel && !ack && sel_asc;
wire [31:0] asc_rdata;

easc easc (
	.clk(clk),
	.nreset(nreset),
	.ce(ce),

	.sel(asc_stb),
	.write(write),
	.a(addr[11:2]),
	.be(be),
	.wdata(wdata),
	.rdata(asc_rdata),

	.irq(easc_irq),

	.sample_l(audio_l),
	.sample_r(audio_r)
);

//----------------------------------------------------------------------------
// SCC (Zilog 85C30), channel A = modem, channel B = printer
//
// Register addressing, straight from MAME (macquadra800.cpp:97-103):
//   u16 mac_scc_r (offs)      -> (result << 8) | result   -- byte mirrored
//   void mac_scc_2_w(offs, d) -> dc_ab_w(offs, d >> 8)    -- chip on D15-D8
// The handler is 16-bit over the range, so offset = (addr - base) >> 1 and
// therefore offset[0] = A1, offset[1] = A2.  z80scc's dc_ab decode is
// bit0 = channel A/B, bit1 = data/control -- so rs = { A2, A1 }, exactly what
// the LC/IIvi cores wire as cpuAddr[2:1].
//
// On this 32-bit beat bus A1 is NOT part of `addr` (which starts at bit 2):
// it is carried by the byte enable.  Word 0 of the longword is lanes be[3:2]
// (A1=0), word 1 is lanes be[1:0] (A1=1), and the SCC byte is the UPPER byte
// of whichever word -- be[3] or be[1].  A longword access (be=1111) resolves
// to the lower address, word 0.
//
// A1 is deduced from the word, not from be[3] alone: a byte access to an odd
// address (be[2], i.e. A+1) is the D7-D0 half of word 0, which is not wired to
// the chip on real hardware.  It must still decode as word 0 -- keying on
// ~be[3] would have flipped it to the other CHANNEL, turning a stray odd-byte
// touch into an access to the wrong half of the SCC.
//----------------------------------------------------------------------------
wire       scc_word0 = be[3] | be[2];
wire       scc_a1    = ~scc_word0;
wire [1:0] scc_rs    = { addr[2], scc_a1 };
wire [7:0] scc_wbyte = scc_word0 ? wdata[31:24] : wdata[15:8];
wire [7:0] scc_rdata;
wire       _scc_irq;
wire       scc_irq   = ~_scc_irq;    // scc.v drives an active-low pin

// Register-interface clock enables, ~8.25 MHz (clk/4).  The LC and IIvi cores
// clock the same chip from 8 MHz enables; the real Quadra feeds the 85C30 a
// 7.8336 MHz PCLK.  The ratio only has to be slow enough for the two-stage
// pointer protocol to resolve and fast enough not to stall the bus.
reg [1:0] scc_clkdiv;
wire scc_cep = (scc_clkdiv == 2'd0);
wire scc_cen = (scc_clkdiv == 2'd2);
always @(posedge clk) begin
	if (!nreset)  scc_clkdiv <= 2'd0;
	else if (ce)  scc_clkdiv <= scc_clkdiv + 1'b1;
end

reg scc_cs;

scc #(.SYS_CLK_HZ(33_000_000)) scc_inst
(
	.clk       (clk),
	.cep       (scc_cep),
	.cen       (scc_cen),
	.rtxc_en   (1'b0),        // reserved in scc.v; the BRG is driven off clk
	.reset_hw  (~nreset),
	.cs        (scc_cs),
	.we        (write),
	.rs        (scc_rs),
	.wdata     (scc_wbyte),
	.rdata     (scc_rdata),
	._irq      (_scc_irq),
	.rxd       (scc_rxd_a),
	.txd       (scc_txd_a),
	.cts       (scc_cts_a),
	.rts       (scc_rts_a),
	.rxd_b     (scc_rxd_b),
	.txd_b_out (scc_txd_b),
	.dcd_a     (1'b1),        // Quadra 800 is ADB: DCD is not mouse quadrature
	.dcd_b     (1'b1),
	.wreq      ()             // W/REQ unused -- no SCC DMA on this machine
);

// write byte: highest enabled lane (VIA registers never span lanes)
wire [7:0] wbyte = be[3] ? wdata[31:24] :
                   be[2] ? wdata[23:16] :
                   be[1] ? wdata[15:8]  : wdata[7:0];

localparam A_IDLE = 3'd0, A_VIA = 3'd1, A_CAPTURE = 3'd2, A_SDMA = 3'd3,
           A_ASC = 3'd4, A_SCC_ACC = 3'd5, A_SCC_REL = 3'd6;
reg [2:0] astate;
reg [3:0] sdma_be;                 // byte lanes of the pseudo-DMA beat

always @(posedge clk) begin
	if (!nreset) begin
		astate    <= A_IDLE;
		ack       <= 0;
		rdata     <= 0;
		via1_ren  <= 0;
		via1_wen  <= 0;
		via1_addr <= 0;
		via1_din  <= 0;
		via2_ifr  <= 8'h00;
		via2_ier  <= 8'h00;
		vbl_d <= 0; scsi_d <= 0; drq_d <= 0; asc_d <= 0; slot_d <= 0;
		for (int j = 0; j < 16; j = j + 1) djmemc_regs[j] <= 32'd0;
		for (int j = 0; j < 32; j = j + 1) iosb_regs[j] <= 16'd0;
		iosb_regs[0] <= 16'd1;               // IOSB_CONFIG: BCLK 33 MHz (QEMU)
		sdma_rd <= 0; sdma_wr <= 0; sdma_left <= 0;
		sdma_shift <= 0; sdma_wbyte <= 0; sdma_be <= 0;
		sdma_watch <= 0; sdma_fault <= 0;
		scc_cs <= 0;
	end
	else if (ce) begin
		ack        <= 0;
		sdma_fault <= 0;             // one-cycle, rides with its ack

		// interrupt line edges latch into the pseudo-VIA IFR
		vbl_d <= vbl_irq; scsi_d <= scsi_irq_i; drq_d <= scsi_drq_i;
		asc_d <= asc_irq_i; slot_d <= slot_any;
		if (scsi_irq_i != scsi_d) via2_ifr[3] <= scsi_irq_i;
		if (scsi_drq_i != drq_d)  via2_ifr[0] <= scsi_drq_i;
		if (slot_any != slot_d) via2_ifr[1] <= slot_any;
		if (asc_irq_i && !asc_d) via2_ifr[4] <= 1'b1;

		case (astate)
		A_IDLE: if (sel && !ack) begin
			if (sel_via1) begin
				via1_addr <= rsel;
				via1_din  <= wbyte;
				via1_wen  <= write;
				via1_ren  <= ~write;
				astate    <= A_VIA;
			end
			else begin
				ack <= 1;
				if (sel_via2) begin
					if (write) begin
						case (rsel)
						4'd13:   via2_ifr[6:0] <= via2_ifr[6:0] & ~(wbyte[6:0] & 7'h1b);
						4'd14:   via2_ier[6:0] <= wbyte[7]
						             ? (via2_ier[6:0] |  (wbyte[6:0] & 7'h1b))
						             : (via2_ier[6:0] & ~(wbyte[6:0] & 7'h1b));
						default: ;              // ports B/A out: DFAC etc, ignored
						endcase
					end
					else begin
						case (rsel)
						4'd1, 4'd15: rdata <= {4{nubus_irqs}};
						4'd13:       rdata <= {4{via2_ifr_r}};
						4'd14:       rdata <= {4{via2_ier}};
						default:     rdata <= 32'h0;
						endcase
					end
				end
				else if (sel_regs) begin
					// one u16 reg per 256-byte stride; every word slot in the
					// block aliases it (MAME offset>>7), low slot written last
					if (write) begin
						if (be[1] | be[0]) begin
							if (be[1]) iosb_regs[addr[12:8]][15:8] <= wdata[15:8];
							if (be[0]) iosb_regs[addr[12:8]][7:0]  <= wdata[7:0];
						end
						else begin
							if (be[3]) iosb_regs[addr[12:8]][15:8] <= wdata[31:24];
							if (be[2]) iosb_regs[addr[12:8]][7:0]  <= wdata[23:16];
						end
					end
					else rdata <= {2{iosb_regs[addr[12:8]]}};
				end
				else if (sel_djmemc) begin
					if (write) djmemc_regs[addr[5:2]] <= wdata;
					else       rdata <= djmemc_regs[addr[5:2]];
				end
				else if (sel_asc) begin
					// the asc sample RAM reads back through a registered
					// block-RAM port: hold the ack one cycle so the read
					// lands (writes stay posted; asc_stb fired this cycle)
					if (!write) begin
						ack    <= 0;
						astate <= A_ASC;
					end
				end
				else if (sel_scc) begin
					// The SCC's register protocol needs the CS window to span
					// a cen pulse (that is where the access is consumed), and
					// then needs CS LOW across another cen pulse -- that is
					// where scc.v clears cs_access_done and applies the
					// deferred pointer cleanup and RX-FIFO pop.  Acking here
					// would collapse both into one beat and swallow every
					// second access, so hold the ack until A_SCC_REL.
					ack    <= 0;
					scc_cs <= 1;
					astate <= A_SCC_ACC;
				end
				else if (sel_scsi) rdata <= {4{ncr_rdata}};  // scsi_strobe fires
				else if (sel_sdma) begin
					// pseudo-DMA beat: hold off the ack until the chip has
					// moved every byte (the real IOSB holds /DTACK on !DRQ
					// and bus-errors a wedged transfer; no timeout modeled
					// yet).  Long = 4 bytes, word = 2, byte = 1; write data
					// is left-aligned so the first SCSI byte is always the
					// highest enabled lane (MAME dma16_swap order).
					ack        <= 0;
					sdma_be    <= be;
					sdma_left  <= (be == 4'b1111) ? 3'd4 :
					              (be == 4'b1100 || be == 4'b0011) ? 3'd2 : 3'd1;
					sdma_shift <= (be == 4'b1111 || be == 4'b1100 || be == 4'b1000) ? wdata :
					              (be == 4'b0100) ? {wdata[23:0], 8'h0} :
					              (be == 4'b0011 || be == 4'b0010) ? {wdata[15:0], 16'h0} :
					                                                 {wdata[7:0], 24'h0};
					sdma_wbyte <= (be == 4'b1111 || be == 4'b1100 || be == 4'b1000) ? wdata[31:24] :
					              (be == 4'b0100) ? wdata[23:16] :
					              (be == 4'b0011 || be == 4'b0010) ? wdata[15:8] :
					                                                 wdata[7:0];
					sdma_rd    <= ~write;
					sdma_wr    <= write;
					sdma_watch <= 0;
					astate     <= A_SDMA;
				end
				else if (sel_id) rdata <= 32'hA55A2BAD;
				else rdata <= 32'h0;             // inert device space
			end
		end
		A_VIA: if (e_falling) begin
			// the 6522 samples ren/wen on this qualified edge; exactly one
			via1_ren <= 0;
			via1_wen <= 0;
			astate   <= A_CAPTURE;
		end
		A_CAPTURE: begin
			rdata  <= {4{via1_dout}};
			ack    <= 1;
			astate <= A_IDLE;
		end
		A_ASC: begin
			rdata  <= asc_rdata;
			ack    <= 1;
			astate <= A_IDLE;
		end
		// SCC access, phase 1: CS is high.  scc.v consumes the access on the
		// cen pulse; rdata is combinational and valid for the whole window, and
		// the RX-FIFO pop is deferred to CS release, so sampling it on this
		// same edge captures the pre-pop byte -- which is what a real CPU
		// latching late in the cycle would see.
		A_SCC_ACC: if (scc_cen) begin
			rdata  <= {4{scc_rdata}};   // MAME mirrors the byte across the word
			scc_cs <= 0;
			astate <= A_SCC_REL;
		end
		// Phase 2: CS is low across a cen pulse, which is where scc.v clears
		// cs_access_done and applies the pointer cleanup / FIFO pop.  Only then
		// is the chip ready for the next access, so the ack goes here.
		A_SCC_REL: if (scc_cen) begin
			ack    <= 1;
			astate <= A_IDLE;
		end
		// A wedged beat used to sit here forever waiting for sdma_valid, and
		// nothing upstream could recover: no iosb_ack meant quadra800.sv stayed
		// in S_IOSB, which has no path back to S_IDLE, so the machine deadlocked
		// even though the CPU escaped via its own stall watchdog.  Release the
		// beat with a fault instead -- that is what the real IOSB does (holds
		// /DTACK on !DRQ and lets the bus-error timer fire), and it turns an
		// undiagnosable freeze into a bus error the ROM handler can act on.
		A_SDMA: if (sdma_valid) begin
			sdma_watch <= 0;
			if (sdma_left == 3'd1) begin
				sdma_rd <= 0;
				sdma_wr <= 0;
				ack     <= 1;
				rdata   <= (sdma_be == 4'b1111) ? {sdma_shift[23:0], sdma_rbyte} :
				           (sdma_be == 4'b1100) ? {sdma_shift[7:0], sdma_rbyte, 16'h0} :
				           (sdma_be == 4'b0011) ? {16'h0, sdma_shift[7:0], sdma_rbyte} :
				                                  {4{sdma_rbyte}};
				astate  <= A_IDLE;
			end
			else begin
				sdma_shift <= {sdma_shift[23:0], sdma_rbyte};
				sdma_wbyte <= sdma_shift[23:16];
				sdma_left  <= sdma_left - 1'b1;
			end
		end
		else if (&sdma_watch) begin
			sdma_rd    <= 0;
			sdma_wr    <= 0;
			ack        <= 1;         // release the bus...
			sdma_fault <= 1;         // ...but tell the adapter it failed
			rdata      <= 32'h0;
			sdma_watch <= 0;
			astate     <= A_IDLE;
`ifdef SIMULATION
			$display("[NCR %0d] SDMA TIMEOUT left=%0d be=%b rd=%b wr=%b -- releasing beat as bus error",
			         iosb_dbg_cyc, sdma_left, sdma_be, sdma_rd, sdma_wr);
`endif
		end
		// Do NOT age the watchdog while a platform block transfer is in flight.
		// The beat is not wedged then -- it is legitimately waiting for the HPS
		// to hand over or accept a sector, and SD latency on a busy card runs to
		// tens of ms, far past this 7.9 ms budget. Counting through that fired
		// the escape on a perfectly healthy transfer and bus-errored the boot:
		// Sad Mac $0000000F / $00000001 on hardware 2026-08-30, i.e. DSErrCode 1
		// = vector 2 = bus error, and it moved around between boots exactly as a
		// latency-dependent fault would. Only idle waiting counts toward the
		// timeout, which is the condition the escape was actually written for.
		else if (!io_rd && !io_wr) sdma_watch <= sdma_watch + 1'b1;
		default: astate <= A_IDLE;
		endcase
	end
end

//----------------------------------------------------------------------------
// 3-level autovector scheme: SCC=4, VIA2=2, VIA1=1
//----------------------------------------------------------------------------
assign ipl_n = scc_irq     ? 3'b011 :
               via2_active ? 3'b101 :
               via1_irq    ? 3'b110 : 3'b111;

endmodule
