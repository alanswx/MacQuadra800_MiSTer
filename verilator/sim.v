`timescale 1ns / 1ps
//============================================================================
//  wombat33 — Verilator simulation wrapper
//
//  `emu` here is the SIMULATION top — the sim-friendly port surface the
//  framework's sim_main.cpp drives.  Stage 1 of the machine bring-up: the
//  quadra800 machine (AP68040 + overlay + decode) with RAM/ROM/VRAM as
//  plain arrays behind the platform beat port.  The ROM image loads from
//  +rom=<hexfile> (default quadra800.rom.hex, built by the Makefile from
//  releases/quadra800.rom).  The template pattern core still paints the
//  VGA window and paces frames until DAFB lands in stage 2.
//============================================================================

module emu
(
	input         clk_sys,
	input         reset,

	// Template option bits (stand-ins for the MiSTer status word):
	//   sim_status[2]   TV mode (0 NTSC, 1 PAL)
	//   sim_status[4:3] Noise colour (0 white, 1 red, 2 green, 3 blue)
	input  [31:0] sim_status,

	// PS2 keyboard/mouse (unused by the template; wired for the machine)
	input  [10:0] ps2_key,
	input  [24:0] ps2_mouse,
	input  [51:0] adb_joy,

	// VGA output
	output [7:0]  VGA_R,
	output [7:0]  VGA_G,
	output [7:0]  VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_HB,
	output        VGA_VB,
	output        CE_PIXEL,

	// Audio output
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,

	// ROM/disk loading interface (ioctl) — the MiSTer quadra800.rom path;
	// the sim loads the ROM by $readmemh instead
	input         ioctl_download,
	input         ioctl_wr,
	input  [24:0] ioctl_addr,
	input  [15:0] ioctl_dout,
	input  [7:0]  ioctl_index,
	output reg    ioctl_wait = 1'b0,

	// SCSI targets: MiSTer block-device surface for sim_blkdevice.cpp.
	// Bit 0 = SCSI ID 0 disk, bit 1 = ID 1 disk, bit 2 = ID 3 CD-ROM; one
	// lba / data bus is shared (one nexus at a time).
	output [31:0] sd_lba0,
	output  [2:0] sd_rd,
	output  [2:0] sd_wr,
	output  [5:0] sd_blk_cnt,   // hps_io sd_blk_cnt: sectors - 1 in this transaction (the block cache moves 8-sector groups)
	input   [2:0] sd_ack,
	input  [12:0] sd_buff_addr,  // 13 bits like hps_io: a group is 2048 words
	input  [15:0] sd_buff_dout,
	output [15:0] sd_buff_din0,
	input         sd_buff_wr,
	input   [2:0] img_mounted,
	input         img_readonly,
	input  [63:0] img_size,

	// CPU debug taps
	output [31:0] debug_pc,        // fetch pointer (debug_status pc)
	output [15:0] debug_opcode,    // current IR
	output        debug_fetch_valid,
	output [31:0] debug_data_addr, // last bus-error address
	output        debug_berr,      // machine bus-error pulse
	output        debug_overlay,
	output        debug_cpu_fault,
	output        debug_cpu_halted,
	output [15:0] debug_sr,
	output [31:0] debug_a7
);


//----------------------------------------------------------------------------
// The machine
//----------------------------------------------------------------------------
localparam RAM_ADDR_BITS = 27;                 // ceiling: 128 MB
// +ram=0|1|2 selects 32/64/128 MB, matching the OSD option on hardware
reg [1:0] ram_cfg = 2'd0;
initial if (!$value$plusargs("ram=%d", ram_cfg)) ram_cfg = 2'd0;
// +monitor=N picks the DAFB monitor (dafb.sv mon_sel): 0 13" 640x480,
// 1 12" 512x384, 2 16" 832x624, 3 21" 1152x870.  sim_main.cpp reads the same
// plusarg to size its frame capture.
reg [1:0] mon_sel = 2'd0;
initial if (!$value$plusargs("monitor=%d", mon_sel)) mon_sel = 2'd0;
localparam RAM_WORDS  = 1 << (RAM_ADDR_BITS-2);
localparam ROM_WORDS  = 262144;                // 1 MB
// VRAM is the flat 1 MB framebuffer MacQuadra800.sv keeps in DDR3
// (rtl/vram_ddr3.sv): no fold, no compaction.  The 308 KB block-RAM mapper
// with its 204 KB fold that this model mirrored until 2026-10-27 is gone
// from the hardware, and with it here the 832x624 and 1152x870 monitors
// wrapped a third of the way down the screen (the whole megabyte is needed).
localparam VRAM_WORDS = 262144;                // 1 MB

wire        mem_req, mem_write;
wire [31:2] mem_addr;
wire  [3:0] mem_be;
wire [31:0] mem_wdata;
wire  [1:0] mem_memsel;
wire        mem_wp_valid;
wire [31:2] mem_wp_addr;
wire  [3:0] mem_wp_be;
wire [31:0] mem_wp_data;
wire        mem_vram_wp;
reg [127:0] rom_line;                        // the ROM's retained line
reg  [19:4] rom_line_tag;
reg         rom_line_valid = 1'b0;
// Optional abstract SDRAM-line timing model. Off retains the original
// one-clock beat-port behavior. Delays count clk_sys rising edges and are
// intended for calibration against the integrated cache/SDRAM bench.
reg ram_line_model = 1'b0;
integer ram_first_latency = 1;
integer ram_line_publish_delay = 0;
initial begin
	if ($test$plusargs("ram_line_model")) ram_line_model = 1'b1;
	if ($value$plusargs("ram_first_latency=%d", ram_first_latency)) begin end
	if ($value$plusargs("ram_line_publish_delay=%d", ram_line_publish_delay)) begin end
	if (ram_first_latency < 1) ram_first_latency = 1;
	if (ram_line_publish_delay < 0) ram_line_publish_delay = 0;
	if (ram_line_model)
		$display("[RAM-LINE-MODEL] abstract first_latency=%0d publish_delay=%0d clk_sys edges",
		         ram_first_latency, ram_line_publish_delay);
end
reg [127:0] ram_line;
reg  [26:4] ram_line_tag;
reg         ram_line_valid = 1'b0;
reg         ram_line_pending = 1'b0;
reg         ram_line_publish_armed = 1'b0;
integer     ram_line_publish_count = 0;
reg         ram_model_busy = 1'b0;
reg         ram_model_ack_sent = 1'b0;
reg         ram_model_poisoned = 1'b0;
integer     ram_model_wait_count = 0;
reg  [31:2] ram_model_addr;
reg         ram_model_write;
reg   [3:0] ram_model_be;
reg  [31:0] ram_model_wdata;
wire [31:0] mem_rdata;
wire        mem_ack;
reg  [31:0] mem_rdata_r;
reg         mem_ack_r;

wire [21:2] vid_addr;
wire [13:0] vid_stride;
reg  [31:0] vid_rdata;

wire [255:0] m_debug_status;
wire [127:0] m_debug_status2;

// The sim runs the scanout on clk_sys, as MacLC's does: the dedicated pixel
// clock only matters to the HDMI scaler on real hardware, and using it here
// would change every frame count in the existing sim regressions for no
// benefit. Frame rate in sim is therefore 78.6 Hz, not the hardware's 59.94.
// SONIC=0: the Ethernet front-end talks to the ARM through a DDR3 window this top
// does not model; its own bench is tb_sonic_mbx.
quadra800 #(.RAM_ADDR_BITS(RAM_ADDR_BITS), .SONIC(0)) machine (
	.clk(clk_sys),
	.clk_vid(clk_sys),
	.nreset_vid(~reset),
	.ram_cfg(ram_cfg),
	.mon_sel(mon_sel),                   // +monitor=N, default the 13" 640x480 shape
	.nreset(~reset),
	.ce(1'b1),

	.mem_req(mem_req),
	.mem_write(mem_write),
	.mem_addr(mem_addr),
	.mem_be(mem_be),
	.mem_wdata(mem_wdata),
	.mem_memsel(mem_memsel),
	.mem_rdata(mem_rdata),
	.mem_ack(mem_ack),
	.mem_wp_valid(mem_wp_valid),
	.mem_wp_addr(mem_wp_addr),
	.mem_wp_be(mem_wp_be),
	.mem_wp_data(mem_wp_data),
	.mem_wq_room(1'b1),
	.mem_vram_wq_room(vram_wq_room),
	.mem_line_valid(ram_line_model && ram_line_valid),
	.mem_line_tag(ram_line_tag),
	.mem_line_data(ram_line),
	.mem_line_pending(ram_line_model && ram_line_pending),
	.mem_line_pending_tag(ram_line_tag),
	.mem_rom_line_valid(rom_line_valid),
	.mem_rom_line_tag(rom_line_tag),
	.mem_rom_line_data(rom_line),
	.mem_vram_wp(mem_vram_wp),

	.vid_addr(vid_addr),
	.vid_stride(vid_stride),
	.vid_rdata(vid_rdata),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_HS(VGA_HS),
	.VGA_VS(VGA_VS),
	.VGA_HB(VGA_HB),
	.VGA_VB(VGA_VB),
	.CE_PIXEL(CE_PIXEL),

	.AUDIO_L(AUDIO_L),
	.AUDIO_R(AUDIO_R),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.adb_joy(adb_joy),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.io_lba(sd_lba0),
	.io_rd(sd_rd),
	.io_wr(sd_wr),
	.io_ack(sd_ack),
	.io_blk_cnt(sd_blk_cnt),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din0),
	.sd_buff_wr(sd_buff_wr),

	// SCC serial.  Both RX lines idle high (nothing attached); TX is left
	// open — the boot path only needs the chip to answer the ROM's InitSCC
	// and selftest, which is exactly what this sim is for.
	.scc_rxd_a(1'b1),
	.scc_txd_a(),
	.scc_cts_a(1'b1),
	.scc_rts_a(),
	.scc_rxd_b(1'b1),
	.scc_txd_b(),

	.dbg_berr(debug_berr),
	.dbg_berr_addr(debug_data_addr),
	.dbg_overlay(debug_overlay),
	.debug_status(m_debug_status),
	.debug_status2(m_debug_status2),
	.debug_fault(debug_cpu_fault),
	.debug_halted(debug_cpu_halted),
	.eth_ena(1'b0),
	.dbg_sw(3'd0),
	.eth_mem_addr(),
	.eth_mem_rd(),
	.eth_mem_we(),
	.eth_mem_wdata(),
	.eth_mem_accept(1'b0),
	.eth_mem_rvalid(1'b0),
	.eth_mem_rdata(64'd0)
);

assign debug_pc          = m_debug_status[31:0];
assign debug_opcode      = m_debug_status[63:48];
assign debug_sr          = m_debug_status[47:32];
assign debug_a7          = m_debug_status[95:64];
assign debug_fetch_valid = ~reset;

//----------------------------------------------------------------------------
// Platform memory: plain arrays behind the beat port (see quadra800.sv for
// the contract).  ROM writes are acked and discarded, as djMEMC does.
//----------------------------------------------------------------------------
reg [31:0] ram  [0:RAM_WORDS-1]  /*verilator public*/;
reg [31:0] rom  [0:ROM_WORDS-1]  /*verilator public*/;
reg [31:0] vram [0:VRAM_WORDS-1] /*verilator public*/;

reg [1023:0] rom_file;
initial begin
	if (!$value$plusargs("rom=%s", rom_file))
		rom_file = "quadra800.rom.hex";
	$readmemh(rom_file, rom);
	// +warmstart seeds the low-memory WarmStart cookie, NOT the RAM-test
	// gate. For a sim-only RAM-test skip, see docs/quadra800-ram-test.md.
	if ($test$plusargs("warmstart")) ram['h33F] = "WLSC";
end

wire [RAM_ADDR_BITS-3:0] ram_idx  = mem_addr[RAM_ADDR_BITS-1:2];
wire [17:0]              rom_idx  = mem_addr[19:2];

// the 1 MB window ($F9000000, mirrored across $F9000000-$F91FFFFF)
wire [17:0]              vram_idx = mem_addr[19:2];

// DAFB scanout port: registered read, 1-cycle latency
always @(posedge clk_sys) vid_rdata <= vram[vid_addr[19:2]];

// posted RAM writes pushed past the beat port (quadra800 DIRECT_WRITES)
wire [RAM_ADDR_BITS-3:0] wp_idx = mem_wp_addr[RAM_ADDR_BITS-1:2];
always @(posedge clk_sys) if (mem_wp_valid) begin
	if (mem_wp_be[3]) ram[wp_idx][31:24] <= mem_wp_data[31:24];
	if (mem_wp_be[2]) ram[wp_idx][23:16] <= mem_wp_data[23:16];
	if (mem_wp_be[1]) ram[wp_idx][15:8]  <= mem_wp_data[15:8];
	if (mem_wp_be[0]) ram[wp_idx][7:0]   <= mem_wp_data[7:0];
end

// VRAM as MacQuadra800.sv serves it: the block RAM's registered read, a
// beat's capture clock (which also writes) and its combinational ack in the
// second clock; a direct write (mem_vram_wp) is a pulse with mem_req low.
wire        mem_is_vram = (mem_memsel != 2'd0) && (mem_memsel != 2'd1);
reg  [31:0] vram_qa;
reg         vram_ph = 1'b0;
wire        mem_port_available = !ram_line_model || !ram_model_busy;
//----------------------------------------------------------------------------
// Optional DDR3 timing model (+ddr3_model), an abstraction of the DDR3-VRAM
// branch's vram_ddr3.sv and rom_cache_128k.sv on top of the ideal arrays:
//   +vram_wr_drain=N  cycles per queued VRAM write beat drained to DDR3
//                     (16-entry queue; the direct write path closes below 12)
//   +vram_rd_miss=N   cycles a VRAM read waits when it misses the 4 x 32-byte
//                     read line cache (a hit keeps the ideal two-clock path)
//   +rom_cache_kb=N   external direct-mapped ROM cache, 16-byte lines (0: none)
//   +rom_miss=N       cycles a ROM line fill waits when it misses that cache
// Off (the default) nothing here changes the ideal behaviour.
//----------------------------------------------------------------------------
// All five are public read/write: the control stream's "model KEY VALUE"
// command (sim_main.cpp) changes them at run time, so a run boots with the
// ideal memory and switches the model on just before the profiled bracket.
reg     ddr3_model    /*verilator public_flat_rw*/ = 1'b0;
integer vram_wr_drain /*verilator public_flat_rw*/ = 3;
integer vram_rd_miss  /*verilator public_flat_rw*/ = 18;
integer rom_cache_kb  /*verilator public_flat_rw*/ = 128;
integer rom_miss      /*verilator public_flat_rw*/ = 40;
initial begin
	if ($test$plusargs("ddr3_model")) ddr3_model = 1'b1;
	if ($value$plusargs("vram_wr_drain=%d", vram_wr_drain)) begin end
	if ($value$plusargs("vram_rd_miss=%d", vram_rd_miss)) begin end
	if ($value$plusargs("rom_cache_kb=%d", rom_cache_kb)) begin end
	if ($value$plusargs("rom_miss=%d", rom_miss)) begin end
	if (vram_wr_drain < 1) vram_wr_drain = 1;
	if (ddr3_model)
		$display("[DDR3-MODEL] vram_wr_drain=%0d vram_rd_miss=%0d rom_cache_kb=%0d rom_miss=%0d",
		         vram_wr_drain, vram_rd_miss, rom_cache_kb, rom_miss);
end

// VRAM write queue: one beat per write landing in the array, drained at a
// fixed rate.  The machine's direct VRAM write path needs wq_room.
reg   [5:0] wq_count = 6'd0;
integer     wq_drain_cnt = 0;
wire        vram_wq_room = !ddr3_model || (wq_count < 6'd12);
wire        wq_push;
wire        wq_pop = ddr3_model && (wq_count != 6'd0) && (wq_drain_cnt == 0);
always @(posedge clk_sys) begin
	if (ddr3_model) begin
		// one beat leaves, then the next can leave vram_wr_drain clocks later
		if (wq_pop) wq_drain_cnt <= vram_wr_drain - 1;
		else if (wq_drain_cnt != 0) wq_drain_cnt <= wq_drain_cnt - 1;
		wq_count <= wq_count + (wq_push ? 6'd1 : 6'd0) - (wq_pop ? 6'd1 : 6'd0);
	end
end

// VRAM read line cache: 4 x 32-byte lines, round-robin victim, a write to a
// held line drops it (conservative).  A miss holds the read for vram_rd_miss
// clocks before the ideal path answers it.
reg  [15:0] rdc_tag [0:3];
reg   [3:0] rdc_val = 4'd0;
reg   [1:0] rdc_victim = 2'd0;
wire [15:0] rd_line = mem_addr[20:5];
wire        rdc_hit = (rdc_val[0] && rdc_tag[0] == rd_line) || (rdc_val[1] && rdc_tag[1] == rd_line) ||
                      (rdc_val[2] && rdc_tag[2] == rd_line) || (rdc_val[3] && rdc_tag[3] == rd_line);
reg         vram_rd_wait = 1'b0;
reg         vram_rd_served = 1'b0;      // this request already paid its miss
integer     vram_rd_cnt = 0;
wire        vram_rd_req = mem_req && mem_is_vram && !mem_write;
wire        vram_rd_miss_start = ddr3_model && vram_rd_req && !vram_rd_wait && !rdc_hit && !vram_rd_served;
// a read waits for its miss; a queued (adapter-path) write waits for queue space
wire        vram_gate = !ddr3_model ||
                        (mem_write ? (wq_count < 6'd16)
                                   : (!vram_rd_req || vram_rd_served || (rdc_hit && !vram_rd_wait)));
integer     rdc_i;
always @(posedge clk_sys) begin
	if (vram_rd_miss_start) begin
		vram_rd_wait <= 1'b1;
		vram_rd_cnt  <= vram_rd_miss;
		rdc_tag[rdc_victim] <= rd_line;
		rdc_val[rdc_victim] <= 1'b1;
		rdc_victim <= rdc_victim + 2'd1;
	end
	else if (vram_rd_wait) begin
		if (vram_rd_cnt <= 1) begin vram_rd_wait <= 1'b0; vram_rd_served <= 1'b1; end
		else vram_rd_cnt <= vram_rd_cnt - 1;
	end
	if (vram_rd_served && !vram_rd_req) vram_rd_served <= 1'b0;
	if (ddr3_model && wq_push)
		for (rdc_i = 0; rdc_i < 4; rdc_i = rdc_i + 1)
			if (rdc_tag[rdc_i] == rd_line) rdc_val[rdc_i] <= 1'b0;
end

// External ROM cache: direct-mapped, 16-byte lines, sized by rom_cache_kb.
// A ROM line read that misses waits rom_miss clocks before the ideal ack.
reg  [15:0] romc_tag [0:65535];
reg         romc_val [0:65535];
initial begin
	for (rdc_i = 0; rdc_i < 65536; rdc_i = rdc_i + 1) romc_val[rdc_i] = 1'b0;
end
wire        romc_on    = (rom_cache_kb != 0);
// lines = kb * 64; 1024 KB wraps the 16-bit product to 0 and the mask to all ones
wire [15:0] romc_mask  = rom_cache_kb[15:0] * 16'd64 - 16'd1;
wire [15:0] rom_line_a = mem_addr[19:4];
wire [15:0] romc_idx   = rom_line_a & romc_mask;
wire        romc_hit   = romc_on && romc_val[romc_idx] && (romc_tag[romc_idx] == rom_line_a);
wire        rom_rd_req = mem_req && !mem_is_vram && (mem_memsel != 2'd0) && !mem_write;
reg         rom_wait = 1'b0, rom_served = 1'b0;
integer     rom_cnt = 0;
wire        rom_miss_start = ddr3_model && rom_rd_req && !rom_wait && !romc_hit && !rom_served && !mem_ack_r;
wire        rom_gate = !ddr3_model || !rom_rd_req || rom_served || (romc_hit && !rom_wait);
always @(posedge clk_sys) begin
	if (rom_miss_start) begin
		rom_wait <= 1'b1;
		rom_cnt  <= rom_miss;
		if (romc_on) begin
			romc_tag[romc_idx] <= rom_line_a;
			romc_val[romc_idx] <= 1'b1;
		end
	end
	else if (rom_wait) begin
		if (rom_cnt <= 1) begin rom_wait <= 1'b0; rom_served <= 1'b1; end
		else rom_cnt <= rom_cnt - 1;
	end
	if (rom_served && !rom_rd_req) rom_served <= 1'b0;
end

wire        vram_ack = mem_req && mem_is_vram && vram_ph && mem_port_available && vram_gate;
wire        va_we = (mem_req && mem_is_vram && mem_write && !vram_ph && mem_port_available && vram_gate) || mem_vram_wp;
assign      wq_push = va_we;
assign mem_ack   = mem_ack_r | vram_ack;
assign mem_rdata = mem_is_vram ? vram_qa : mem_rdata_r;

always @(posedge clk_sys) begin
	vram_qa <= vram[vram_idx];
	if (va_we) begin
		if (mem_be[3]) vram[vram_idx][31:24] <= mem_wdata[31:24];
		if (mem_be[2]) vram[vram_idx][23:16] <= mem_wdata[23:16];
		if (mem_be[1]) vram[vram_idx][15:8]  <= mem_wdata[15:8];
		if (mem_be[0]) vram[vram_idx][7:0]   <= mem_wdata[7:0];
	end
	if (mem_req && mem_is_vram && mem_port_available && vram_gate) vram_ph <= !vram_ph;
end

wire ram_model_accept = ram_line_model && !reset && !ram_model_busy &&
	mem_req && !mem_ack_r && !mem_is_vram && (mem_memsel == 2'd0) && !mem_wp_valid;
wire ram_model_complete = (ram_model_accept && (mem_write || ram_first_latency == 1)) ||
	(ram_line_model && ram_model_busy && !ram_model_ack_sent &&
	 (ram_model_wait_count <= 1) && !mem_wp_valid);
wire [31:2] ram_service_addr = ram_model_accept ? mem_addr : ram_model_addr;
wire ram_service_write = ram_model_accept ? mem_write : ram_model_write;
wire [3:0] ram_service_be = ram_model_accept ? mem_be : ram_model_be;
wire [31:0] ram_service_wdata = ram_model_accept ? mem_wdata : ram_model_wdata;
wire [RAM_ADDR_BITS-3:0] ram_service_idx = ram_service_addr[RAM_ADDR_BITS-1:2];
wire [RAM_ADDR_BITS-3:0] ram_line_base = {ram_service_addr[RAM_ADDR_BITS-1:4], 2'b00};

always @(posedge clk_sys) begin
	mem_ack_r <= 0;
	if (!ram_line_model && mem_req && !mem_ack_r && !mem_is_vram && rom_gate) begin
		mem_ack_r <= 1;
		case (mem_memsel)
		2'd0: begin
			mem_rdata_r <= ram[ram_idx];
			if (mem_write) begin
				if (mem_be[3]) ram[ram_idx][31:24] <= mem_wdata[31:24];
				if (mem_be[2]) ram[ram_idx][23:16] <= mem_wdata[23:16];
				if (mem_be[1]) ram[ram_idx][15:8]  <= mem_wdata[15:8];
				if (mem_be[0]) ram[ram_idx][7:0]   <= mem_wdata[7:0];
			end
		end
		default: begin
			mem_rdata_r <= rom[rom_idx];
			// the emu's ROM read fetches the whole line (MacQuadra800.sv)
			if (!mem_write) begin
				rom_line       <= {rom[{rom_idx[17:2], 2'd0}], rom[{rom_idx[17:2], 2'd1}],
				                   rom[{rom_idx[17:2], 2'd2}], rom[{rom_idx[17:2], 2'd3}]};
				rom_line_tag   <= mem_addr[19:4];
				rom_line_valid <= 1'b1;
			end
		end
		endcase
	end
	if (ram_line_model) begin
		if (reset) begin
			ram_line_valid <= 0;
			ram_line_pending <= 0;
			ram_line_publish_armed <= 0;
			ram_model_busy <= 0;
			ram_model_ack_sent <= 0;
			ram_model_poisoned <= 0;
		end
		else begin
			// A pending line is visible to the machine until all four words
			// are published together. The original read still gets its ack.
			if (ram_line_publish_armed) begin
				if (ram_line_publish_count <= 1) begin
					ram_line_valid <= 1;
					ram_line_pending <= 0;
					ram_line_publish_armed <= 0;
				end
				else ram_line_publish_count <= ram_line_publish_count - 1;
			end
			if (ram_model_accept) begin
				ram_model_busy <= 1;
				ram_model_ack_sent <= 0;
				ram_model_addr <= mem_addr;
				ram_model_write <= mem_write;
				ram_model_be <= mem_be;
				ram_model_wdata <= mem_wdata;
				ram_model_wait_count <= mem_write ? 0 : ram_first_latency - 1;
				ram_model_poisoned <= 0;
				if (!mem_write) begin
					ram_line_tag <= mem_addr[26:4];
					ram_line_valid <= 0;
					ram_line_pending <= 1;
					ram_line_publish_armed <= 0;
				end
			end
			else if (ram_model_busy && !ram_model_ack_sent && !ram_model_complete &&
			         ram_model_wait_count > 1)
				ram_model_wait_count <= ram_model_wait_count - 1;
			if (ram_model_complete) begin
				mem_ack_r <= 1;
				ram_model_ack_sent <= 1;
				if (ram_service_write) begin
					mem_rdata_r <= ram[ram_service_idx];
					if (ram_service_be[3]) ram[ram_service_idx][31:24] <= ram_service_wdata[31:24];
					if (ram_service_be[2]) ram[ram_service_idx][23:16] <= ram_service_wdata[23:16];
					if (ram_service_be[1]) ram[ram_service_idx][15:8]  <= ram_service_wdata[15:8];
					if (ram_service_be[0]) ram[ram_service_idx][7:0]   <= ram_service_wdata[7:0];
				end
				else begin
					mem_rdata_r <= ram[ram_service_idx];
					if (ram_model_accept || !ram_model_poisoned) begin
						ram_line <= {ram[ram_line_base], ram[ram_line_base + 1'b1],
						             ram[ram_line_base + 2'd2], ram[ram_line_base + 2'd3]};
						if (ram_line_publish_delay == 0) begin
							ram_line_valid <= 1;
							ram_line_pending <= 0;
						end
						else begin
							ram_line_publish_count <= ram_line_publish_delay;
							ram_line_publish_armed <= 1;
						end
					end
					else ram_line_pending <= 0;
				end
			end
			if (ram_model_busy && ram_model_ack_sent && !mem_req && !ram_line_pending)
				ram_model_busy <= 0;
			if (!ram_model_busy && mem_req && !mem_ack_r && !mem_is_vram && rom_gate &&
			    mem_memsel != 2'd0) begin
				// ROM retains its original one-edge response in modeled mode.
				mem_ack_r <= 1;
				mem_rdata_r <= rom[rom_idx];
				if (!mem_write) begin
					rom_line       <= {rom[{rom_idx[17:2], 2'd0}], rom[{rom_idx[17:2], 2'd1}],
					                   rom[{rom_idx[17:2], 2'd2}], rom[{rom_idx[17:2], 2'd3}]};
					rom_line_tag   <= mem_addr[19:4];
					rom_line_valid <= 1'b1;
				end
			end
			// A posted write can land while the retained line is still
			// pending. It poisons publication but never cancels the read ack.
			if (mem_wp_valid || (ram_model_complete && ram_service_write)) begin
				ram_line_valid <= 0;
				ram_line_pending <= 0;
				ram_line_publish_armed <= 0;
				if (mem_wp_valid && ram_model_busy && !ram_model_ack_sent)
					ram_model_poisoned <= 1;
			end
		end
	end
end

`ifdef CPU_AP68040
//----------------------------------------------------------------------------
// Profiler probes for sim_main's dual-core bracket (sim_prof040.h): read-only
// cross-module references into the machine, public so the C++ side can
// sample them after each rising-edge eval.
//----------------------------------------------------------------------------
wire        prof_retire     /*verilator public_flat_rd*/;
wire        prof_retire2    /*verilator public_flat_rd*/;
wire [31:0] prof_retired_pc /*verilator public_flat_rd*/;
wire        prof_c_req      /*verilator public_flat_rd*/;
wire        prof_c_ack      /*verilator public_flat_rd*/;
wire        prof_c_last     /*verilator public_flat_rd*/;
wire        prof_c_write    /*verilator public_flat_rd*/;
wire        prof_c_instr    /*verilator public_flat_rd*/;
wire        prof_c_line     /*verilator public_flat_rd*/;
wire  [1:0] prof_c_size     /*verilator public_flat_rd*/;
wire [31:0] prof_c_addr     /*verilator public_flat_rd*/;
wire        prof_m_req      /*verilator public_flat_rd*/;
wire        prof_m_ack      /*verilator public_flat_rd*/;
wire        prof_m_write    /*verilator public_flat_rd*/;
wire [31:0] prof_m_addr     /*verilator public_flat_rd*/;
wire        prof_sb_pending /*verilator public_flat_rd*/;
wire        prof_vram_wp    /*verilator public_flat_rd*/;
wire  [3:0] prof_qcnt       /*verilator public_flat_rd*/;
wire        prof_dmu_busy   /*verilator public_flat_rd*/;
assign prof_retire     = machine.cpu.dbg_retire;
assign prof_retire2    = machine.cpu.cpu.dbg_retire2;
assign prof_retired_pc = machine.cpu.retired_pc;
assign prof_c_req      = machine.cpu.req;
assign prof_c_ack      = machine.cpu.cpu_bus_ack;
assign prof_c_last     = machine.cpu.last;
assign prof_c_write    = !machine.cpu.c_rw_n;
assign prof_c_instr    = machine.cpu.cpu_bus_instr;
assign prof_c_line     = machine.cpu.is_line;
assign prof_c_size     = machine.cpu.cpu_bus_size;
assign prof_c_addr     = machine.cpu.cpu_bus_addr;
assign prof_m_req      = machine.bus_req;
assign prof_m_ack      = machine.bus_ack;
assign prof_m_write    = machine.bus_write;
assign prof_m_addr     = machine.bus_addr;
assign prof_sb_pending = machine.cpu.buffered_store_pending;
assign prof_vram_wp    = mem_vram_wp;
assign prof_qcnt       = machine.cpu.cpu.qcnt;
assign prof_dmu_busy   = !machine.cpu.cpu.dmu.e_quiet;
`endif

endmodule
