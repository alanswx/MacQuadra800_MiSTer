//============================================================================
//  wombat_cpu — AP68040 bundled for the Quadra 800's flat 32-bit bus.
//
//  Same core+MMU+cache wiring as ap040_tg68k_compat (the configuration the
//  silicon campaign validated), minus the 16-bit Minimig bus adapter: the
//  post-cache 32-bit transaction port is exported directly for djMEMC.
//
//  Bus contract (same as ap040_bus16_adapter's core side):
//   - bus_req is level-held; during a cache line fill it stays high across
//     the 4 beats with bus_addr changing, so consumers must re-accept on
//     req && !their-own-ack, never on a req edge.
//   - bus_ack is a single-cycle pulse with bus_rdata valid (right-aligned
//     by bus_size); wdata is right-aligned by size.
//   - Misaligned word/long transactions appear here unsplit; the consumer
//     (wombat_bus32) splits them into aligned beats.
//   - berr is a single-cycle pulse while the transaction is in flight.
//============================================================================

`include "ap040_defs.svh"

module wombat_cpu
#(
	parameter AP040_HAS_FPU      = 1,
	parameter AP040_ENABLE_CACHE = 1,
	parameter AP040_STORE_BUFFER = 1
)
(
	input         clk,
	input         nreset,
	input         ce,

	input   [2:0] ipl,            // active low
	input         ipl_autovector,
	input         berr,

	// Optional completed physical RAM line retained by the platform.
	input         cache_line_valid,
	input  [31:4] cache_line_tag,
	input [127:0] cache_line_data,
	// High only when low physical addresses select non-faulting RAM.
	input         store_buffer_ok,

	// post-cache 32-bit transaction bus (physical addresses)
	output        bus_req,
	output        bus_write,
	output        bus_instr,
	output  [1:0] bus_size,       // AP040_SZ_B/W/L
	output [31:0] bus_addr,
	output [31:0] bus_wdata,
	output  [2:0] bus_fc,
	input         bus_ack,
	input  [31:0] bus_rdata,

	// MMU table-walker port (physical, aligned longwords)
	output        walker_req,
	output        walker_we,
	output [31:0] walker_addr,
	output [31:0] walker_wdat,
	input         walker_ack,
	input  [31:0] walker_data,
	input         walker_berr,

	// DMA write snoop (SONIC later; tie off until then)
	input         snoop_stb,
	input  [31:0] snoop_addr,

	output        nresetout,
	output        nmi_ack_toggle,
	output [31:0] cacr_out,
	output [31:0] vbr_out,
	output        debug_busy,
	output        debug_fault,
	output        debug_halted,
	output [255:0] debug_status,
	output [127:0] debug_status2
);

// core to MMU
wire        mem_req;
wire        mem_write;
wire        mem_instr;
wire  [1:0] mem_size;
wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire  [2:0] mem_fc;
wire        mem_ack;
wire [31:0] mem_rdata;
wire        mem_flt_mmu;

// Core-side stall watchdog, verbatim from ap040_tg68k_compat: a request
// lost below the core would otherwise hang it with no fault frame.
wire        core_stall_flt;
ap040_bus_timeout #(.COUNTER_BITS(21)) core_stall_watchdog (
	.clk(clk),
	.nreset(nreset),
	.req(mem_req),
	.complete(mem_ack | mem_flt_mmu),
	.berr(core_stall_flt)
);
wire        mem_flt = mem_flt_mmu | core_stall_flt;

// MMU to cache
wire        mm_req, mm_write, mm_instr;
wire  [1:0] mm_size;
wire [31:0] mm_addr, mm_wdata;
wire  [2:0] mm_fc;
wire        mm_ack, mm_nocache;
wire [31:0] mm_rdata;

// MMU walker requests are held behind older buffered CPU stores. This matters
// when software writes a page-table entry and immediately incurs an ATC miss:
// the walker must not observe memory before that store has reached the platform.
wire        mmu_walker_req, mmu_walker_we;
wire [31:0] mmu_walker_addr, mmu_walker_wdat;

// Cache/no-cache master side before the ordered write buffer.
wire        cpu_bus_req, cpu_bus_write, cpu_bus_instr;
wire  [1:0] cpu_bus_size;
wire [31:0] cpu_bus_addr, cpu_bus_wdata;
wire  [2:0] cpu_bus_fc;
wire        cpu_bus_ack;
wire [31:0] cpu_bus_rdata;
wire        buffered_store_pending;

// CINV sideband
wire        cinv_req, cinv_ic, cinv_dc, cinv_done;

// control registers and PTEST/PFLUSH sideband
wire [31:0] w_tc, w_urp, w_srp, w_itt0, w_itt1, w_dtt0, w_dtt1;
wire        pt_req, pt_write, pt_done;
wire [31:0] pt_addr, pt_mmusr;
wire  [2:0] pt_fcw;
wire        pf_req, pf_done;
wire  [1:0] pf_mode;
wire [31:0] pf_addr;
wire  [2:0] pf_fcw;

ap040_core #(
	.AP040_HAS_MMU(1),
	.AP040_HAS_FPU(AP040_HAS_FPU),
	.AP040_ENABLE_CACHE(AP040_ENABLE_CACHE),
	.AP040_FAST_SIM(0)
) core (
	.clk(clk),
	.nreset(nreset),
	.ce(ce),

	.mem_req(mem_req),
	.mem_write(mem_write),
	.mem_instr(mem_instr),
	.mem_size(mem_size),
	.mem_addr(mem_addr),
	.mem_wdata(mem_wdata),
	.mem_fc(mem_fc),
	.mem_ack(mem_ack),
	.mem_rdata(mem_rdata),
	.mem_flt(mem_flt),

	.tc_out(w_tc),
	.urp_out(w_urp),
	.srp_out(w_srp),
	.itt0_out(w_itt0),
	.itt1_out(w_itt1),
	.dtt0_out(w_dtt0),
	.dtt1_out(w_dtt1),
	.pt_req(pt_req),
	.pt_write(pt_write),
	.pt_addr(pt_addr),
	.pt_fc(pt_fcw),
	.pt_done(pt_done),
	.pt_mmusr(pt_mmusr),
	.pf_req(pf_req),
	.pf_mode(pf_mode),
	.pf_addr(pf_addr),
	.pf_fc(pf_fcw),
	.pf_done(pf_done),
	.cinv_req(cinv_req),
	.cinv_ic(cinv_ic),
	.cinv_dc(cinv_dc),
	.cinv_done(cinv_done),

	.ipl(ipl),
	.ipl_autovector(ipl_autovector),
	.berr(berr),
	.nmi_ack_toggle(nmi_ack_toggle),

	.nresetout(nresetout),
	.cacr_out(cacr_out),
	.vbr_out(vbr_out),

	.debug_busy(debug_busy),
	.debug_fault(debug_fault),
	.debug_halted(debug_halted),
	.debug_status(debug_status),
	.debug_status2(debug_status2)
);

ap040_mmu mmu (
	.clk(clk),
	.nreset(nreset),
	.ce(ce),

	.tc(w_tc),
	.urp(w_urp),
	.srp(w_srp),
	.itt0(w_itt0),
	.itt1(w_itt1),
	.dtt0(w_dtt0),
	.dtt1(w_dtt1),

	.c_req(mem_req),
	.c_write(mem_write),
	.c_instr(mem_instr),
	.c_size(mem_size),
	.c_addr(mem_addr),
	.c_wdata(mem_wdata),
	.c_fc(mem_fc),
	.c_ack(mem_ack),
	.c_rdata(mem_rdata),
	.c_flt(mem_flt_mmu),

	.pt_req(pt_req),
	.pt_write(pt_write),
	.pt_addr(pt_addr),
	.pt_fc(pt_fcw),
	.pt_done(pt_done),
	.pt_mmusr(pt_mmusr),

	.pf_req(pf_req),
	.pf_mode(pf_mode),
	.pf_addr(pf_addr),
	.pf_fc(pf_fcw),
	.pf_done(pf_done),

	.m_req(mm_req),
	.m_write(mm_write),
	.m_instr(mm_instr),
	.m_size(mm_size),
	.m_addr(mm_addr),
	.m_wdata(mm_wdata),
	.m_fc(mm_fc),
	.m_ack(mm_ack),
	.m_rdata(mm_rdata),

	.walker_req(mmu_walker_req),
	.walker_we(mmu_walker_we),
	.walker_addr(mmu_walker_addr),
	.walker_wdat(mmu_walker_wdat),
	.walker_ack(walker_ack),
	.walker_data(walker_data),
	.walker_berr(walker_berr),

	.phys_addr(),
	.cache_inhibit(),
	.m_nocache(mm_nocache)
);

assign walker_req  = mmu_walker_req && !buffered_store_pending;
assign walker_we   = mmu_walker_we;
assign walker_addr = mmu_walker_addr;
assign walker_wdat = mmu_walker_wdat;

// Walker U/M-bit writes invalidate any cached copy of the descriptor —
// same one-slot pending scheme as ap040_tg68k_compat (audit 5.5 there).
reg         wsnp_pend;
reg  [31:0] wsnp_addr;
reg         walker_wr_d;
wire        walker_wr_edge = (walker_req & walker_we) & ~walker_wr_d;

always @(posedge clk) begin
	if (!nreset) begin
		walker_wr_d <= 1'b0;
		wsnp_pend   <= 1'b0;
		wsnp_addr   <= 32'd0;
	end
	else begin
		walker_wr_d <= walker_req & walker_we;
		if (walker_wr_edge) begin
			wsnp_pend <= 1'b1;
			wsnp_addr <= walker_addr;
		end
		else if (wsnp_pend && !snoop_stb)
			wsnp_pend <= 1'b0;
	end
end

wire        snp_stb  = snoop_stb | wsnp_pend;
wire [31:0] snp_addr = snoop_stb ? snoop_addr : wsnp_addr;

generate
if (AP040_ENABLE_CACHE != 0) begin : g_cache
	// Quadra 800 physical cacheability: RAM space (djMEMC banks,
	// $00000000-$3FFFFFFF) and the ROM window ($40000000-$4FFFFFFF) may be
	// cached; IOSB I/O, DAFB VRAM/registers and NuBus must never be.  With
	// translation on, the MMU's CM attributes (mm_nocache) still override.
	wire cache_allow = (mm_addr[31:30] == 2'b00) || (mm_addr[31:28] == 4'h4);

	ap040_cache cache (
		.clk(clk),
		.nreset(nreset),
		.ce(ce),

		.ie(cacr_out[15]),
		.de(cacr_out[31]),

		.cinv_req(cinv_req),
		.cinv_ic(cinv_ic),
		.cinv_dc(cinv_dc),
		.cinv_done(cinv_done),

		.c_req(mm_req),
		.c_write(mm_write),
		.c_instr(mm_instr),
		.c_size(mm_size),
		.c_addr(mm_addr),
		.c_wdata(mm_wdata),
		.c_fc(mm_fc),
		.c_nocache(mm_nocache | ~cache_allow),
		.s_stb(snp_stb),
		.s_addr(snp_addr),
		.c_ack(mm_ack),
		.c_rdata(mm_rdata),

		.m_req(cpu_bus_req),
		.m_write(cpu_bus_write),
		.m_instr(cpu_bus_instr),
		.m_size(cpu_bus_size),
		.m_addr(cpu_bus_addr),
		.m_wdata(cpu_bus_wdata),
		.m_fc(cpu_bus_fc),
		.m_ack(cpu_bus_ack),
		.m_rdata(cpu_bus_rdata),
		// A retained line predating a queued store is stale until the
		// write reaches the platform and invalidates that lower-level line.
		.m_line_valid(cache_line_valid && !buffered_store_pending),
		.m_line_tag(cache_line_tag),
		.m_line_data(cache_line_data),
		.m_err(berr)
	);
end
else begin : g_nocache
	assign cpu_bus_req   = mm_req;
	assign cpu_bus_write = mm_write;
	assign cpu_bus_instr = mm_instr;
	assign cpu_bus_size  = mm_size;
	assign cpu_bus_addr  = mm_addr;
	assign cpu_bus_wdata = mm_wdata;
	assign cpu_bus_fc    = mm_fc;
	assign mm_ack        = cpu_bus_ack;
	assign mm_rdata      = cpu_bus_rdata;
	assign cinv_done = 1'b1;
end
endgenerate

wombat_store_buffer #(.ENABLE(AP040_STORE_BUFFER)) store_buffer (
	.clk(clk),
	.nreset(nreset),
	.ce(ce),
	.buffer_writes(store_buffer_ok),

	.s_req(cpu_bus_req),
	.s_write(cpu_bus_write),
	.s_instr(cpu_bus_instr),
	.s_size(cpu_bus_size),
	.s_addr(cpu_bus_addr),
	.s_wdata(cpu_bus_wdata),
	.s_fc(cpu_bus_fc),
	.s_ack(cpu_bus_ack),
	.s_rdata(cpu_bus_rdata),

	.m_req(bus_req),
	.m_write(bus_write),
	.m_instr(bus_instr),
	.m_size(bus_size),
	.m_addr(bus_addr),
	.m_wdata(bus_wdata),
	.m_fc(bus_fc),
	.m_ack(bus_ack),
	.m_rdata(bus_rdata),
	.m_err(berr),
	.pending(buffered_store_pending)
);

endmodule
