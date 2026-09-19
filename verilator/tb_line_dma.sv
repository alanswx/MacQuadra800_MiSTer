`timescale 1ps/1ps

// tb_line_dma — the CPU's retained-line read shortcut against a second bus
// master (the SONIC's DMA arm of quadra800.sv's service FSM).
//
// The logic between the two banners below is quadra800.sv's, RAM-only subset,
// copied line for line: bus_ram_eligible / bus_line_match / bus_line_wait /
// bus_first_miss, the registered bus_line_ack, bus_req_adapter, dma_take and
// the S_IDLE / S_MEM arms.  Around it sit the real wombat_bus32, the real
// sdram_beat32 + sdram and the chip model from tb_sdram.sv.  The requester
// keeps the post-cache contract (request level-held, the next one presented
// in the clock after the ack); the DMA master writes a region the requester
// never touches, so every value the requester must see is known.
//
// FIX=0 reproduces the 2026-09-18 hardware failure: a line ack that lands in
// the clock the FSM has just left S_IDLE for a DMA beat finds bus_ram_eligible
// low, so bus_req_adapter rises under the ack, wombat_bus32 launches a read
// nobody asked for, and its completion acknowledges whatever request is on the
// bus by then -- a fill beat takes its neighbour's word, a store is dropped.
// FIX=1 holds bus_req_adapter (and eligibility) off in the line-ack clock.

module tb_line_dma #(
	parameter integer FIX = 1,
	parameter integer ROUNDS = 4000
);

localparam integer TR = 5050;
localparam integer TS = 3*TR;

reg clk_ram = 0;
reg clk = 0;
always #TR clk_ram = ~clk_ram;
always #TS clk = ~clk;

reg nreset = 0;
reg init = 1;
wire ce = 1'b1;

// requester (post-cache bus)
reg         bus_req = 0;
reg         bus_write = 0;
reg   [1:0] bus_size = 2'd2;
reg  [31:0] bus_addr = 0;
reg  [31:0] bus_wdata = 0;
wire        bus_ack;
wire [31:0] bus_rdata;

// DMA master
reg         dma_req = 0;
reg         dma_we = 1;
reg  [26:2] dma_addr = 0;
reg   [3:0] dma_be = 4'b1111;
reg  [31:0] dma_wdata = 0;

wire        mem_ack;
wire [31:0] mem_rdata;
wire        mem_line_valid;
wire [26:4] mem_line_tag;
wire [127:0] mem_line_data;
wire        mem_line_pending;
wire [26:4] mem_line_pending_tag;

//================= quadra800.sv, RAM-only subset (verbatim) =================
wire        line_valid_sw   = mem_line_valid;
wire        line_pending_sw = mem_line_pending;
wire        walker_pend = 1'b0;
reg         cpu_berr;

wire        bus_ack_adapter;
wire [31:0] bus_rdata_adapter;
wire        bus_adapter_active;
wire        bus_req_adapter;
reg         bus_line_ack;
reg  [31:0] bus_line_rdata;
reg         bus_miss_ack;
reg  [31:0] bus_miss_rdata;

assign bus_ack   = bus_line_ack || bus_miss_ack || bus_ack_adapter;
assign bus_rdata = bus_line_ack ? bus_line_rdata :
	               bus_miss_ack ? bus_miss_rdata : bus_rdata_adapter;

wire        b_req, b_write;
wire [31:2] b_addr;
wire  [3:0] b_be;
wire [31:0] b_wdata;
reg         b_ack;
reg  [31:0] b_rdata;

localparam S_IDLE = 3'd0, S_MEM = 3'd1;
reg  [2:0] svc;
reg        svc_dma;
reg        svc_bus_direct;
reg        dma_ack;
reg [31:0] dma_rdata;
reg        dma_turn;
reg        mem_req;
reg        mem_write;
reg [31:2] mem_addr;
reg  [3:0] mem_be;
reg [31:0] mem_wdata;

wire line_cpu_match = b_req && !b_write &&
	                  line_valid_sw && (b_addr[26:4] == mem_line_tag);
wire line_cpu_wait  = b_req && !b_write &&
	                  line_pending_sw &&
	                  (b_addr[26:4] == mem_line_pending_tag);
wire [31:0] line_cpu_data = (b_addr[3:2] == 2'd0) ? mem_line_data[127:96] :
	                        (b_addr[3:2] == 2'd1) ? mem_line_data[95:64]  :
	                        (b_addr[3:2] == 2'd2) ? mem_line_data[63:32]  :
	                                                        mem_line_data[31:0];

wire bus_ram_eligible = (svc == S_IDLE) && !walker_pend && !cpu_berr &&
	                    !bus_miss_ack && (FIX == 0 || !bus_line_ack) &&
	                    !bus_adapter_active && !bus_ack_adapter &&
	                    bus_req && !bus_write &&
	                    (bus_size == 2'd2) && (bus_addr[1:0] == 2'b00);
wire bus_line_match = bus_ram_eligible && line_valid_sw &&
	                  (bus_addr[26:4] == mem_line_tag);
wire bus_line_wait  = bus_ram_eligible && line_pending_sw &&
	                  (bus_addr[26:4] == mem_line_pending_tag);
wire bus_first_miss = bus_ram_eligible && !bus_line_match && !bus_line_wait;
wire [31:0] bus_line_data = (bus_addr[3:2] == 2'd0) ? mem_line_data[127:96] :
	                        (bus_addr[3:2] == 2'd1) ? mem_line_data[95:64]  :
	                        (bus_addr[3:2] == 2'd2) ? mem_line_data[63:32]  :
	                                                          mem_line_data[31:0];

assign bus_req_adapter = bus_req && !bus_line_match && !bus_line_wait &&
	                     !bus_first_miss && !svc_bus_direct && !bus_miss_ack &&
	                     (FIX == 0 || !bus_line_ack);

always @(posedge clk) begin
	if (!nreset) begin
		bus_line_ack   <= 0;
		bus_line_rdata <= 0;
	end
	else if (ce) begin
		bus_line_ack <= 0;
		if (!bus_line_ack && bus_line_match) begin
			bus_line_ack   <= 1;
			bus_line_rdata <= bus_line_data;
		end
	end
end

wire cpu_want = walker_pend || bus_first_miss ||
                (b_req && !b_ack && !cpu_berr && !line_cpu_wait);
wire dma_take = dma_req && !dma_ack && !walker_pend &&
                (dma_turn || !cpu_want);

always @(posedge clk) begin
	if (!nreset) begin
		svc <= S_IDLE; svc_bus_direct <= 0; svc_dma <= 0;
		dma_ack <= 0; dma_rdata <= 0; dma_turn <= 0;
		b_ack <= 0; b_rdata <= 0; bus_miss_ack <= 0; bus_miss_rdata <= 0;
		cpu_berr <= 0; mem_req <= 0; mem_write <= 0; mem_addr <= 0;
		mem_be <= 0; mem_wdata <= 0;
	end
	else if (ce) begin
		b_ack        <= 0;
		bus_miss_ack <= 0;
		dma_ack      <= 0;
		case (svc)
		S_IDLE: begin
			if (dma_take) begin
				svc_bus_direct <= 0;
				dma_turn       <= 0;
				svc_dma    <= 1;
				mem_req    <= 1;
				mem_write  <= dma_we;
				mem_addr   <= {5'd0, dma_addr};
				mem_be     <= dma_be;
				mem_wdata  <= dma_wdata;
				svc        <= S_MEM;
			end
			else if (cpu_want) begin
				dma_turn <= 1;
				if (bus_first_miss) begin
					svc_bus_direct <= 1;
					mem_req        <= 1;
					mem_write      <= 0;
					mem_addr       <= bus_addr[31:2];
					mem_be         <= 4'b1111;
					mem_wdata      <= 0;
					svc            <= S_MEM;
				end
				else if (!walker_pend && line_cpu_match) begin
					b_ack   <= 1;
					b_rdata <= line_cpu_data;
				end
				else begin
					svc_bus_direct <= 0;
					mem_req    <= 1;
					mem_write  <= b_write;
					mem_addr   <= b_addr;
					mem_be     <= b_be;
					mem_wdata  <= b_wdata;
					svc        <= S_MEM;
				end
			end
		end
		S_MEM: if (mem_ack) begin
			mem_req <= 0;
			if (svc_dma) begin
				dma_ack   <= 1;
				dma_rdata <= mem_rdata;
				svc_dma   <= 0;
			end
			else if (svc_bus_direct) begin
				bus_miss_ack   <= 1;
				bus_miss_rdata <= mem_rdata;
			end
			else begin
				b_ack   <= 1;
				b_rdata <= mem_rdata;
			end
			svc_bus_direct <= 0;
			svc <= S_IDLE;
		end
		default: svc <= S_IDLE;
		endcase
	end
end
//============================ end of the subset =============================

wombat_bus32 bus32 (
	.clk(clk), .nreset(nreset), .ce(ce),
	.t_req(bus_req_adapter), .t_write(bus_write), .t_size(bus_size),
	.t_addr(bus_addr), .t_wdata(bus_wdata), .t_berr(cpu_berr),
	.t_ack(bus_ack_adapter), .t_rdata(bus_rdata_adapter),
	.t_active(bus_adapter_active),
	.b_req(b_req), .b_write(b_write), .b_addr(b_addr), .b_be(b_be),
	.b_wdata(b_wdata), .b_ack(b_ack), .b_rdata(b_rdata)
);

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire SDRAM_DQML, SDRAM_DQMH;
wire [1:0] SDRAM_BA;
wire SDRAM_nCS, SDRAM_nWE, SDRAM_nRAS, SDRAM_nCAS, SDRAM_CKE, SDRAM_CLK;

sdram_beat32 sdr (
	.init(init), .clk_sys(clk), .clk_ram(clk_ram),
	.req(mem_req), .we(mem_write), .addr(mem_addr[26:2]), .be(mem_be),
	.wdata(mem_wdata), .ack(mem_ack), .rdata(mem_rdata), .busy(),
	.line_valid_o(mem_line_valid), .line_tag_o(mem_line_tag),
	.line_data_o(mem_line_data), .line_pending_o(mem_line_pending),
	.line_pending_tag_o(mem_line_pending_tag),
	.SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH), .SDRAM_BA(SDRAM_BA), .SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nWE(SDRAM_nWE), .SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_CKE(SDRAM_CKE), .SDRAM_CLK(SDRAM_CLK)
);

sdram_model chip (
	.clk(SDRAM_CLK), .cke(SDRAM_CKE), .nCS(SDRAM_nCS),
	.nRAS(SDRAM_nRAS), .nCAS(SDRAM_nCAS), .nWE(SDRAM_nWE),
	.ba(SDRAM_BA), .a(SDRAM_A), .dqmh(SDRAM_DQMH), .dqml(SDRAM_DQML),
	.dq(SDRAM_DQ)
);

// ---- the DMA master: write beats into $100000.., at random intervals ------
reg dma_on = 0;
integer dma_gap = 0;
integer dma_beats = 0;
reg [31:0] lfsr_d = 32'hC0FFEE11;
always @(posedge clk) begin
	if (!nreset) begin
		dma_req <= 0;
	end
	else if (dma_req) begin
		if (dma_ack) begin
			dma_req   <= 0;
			dma_beats <= dma_beats + 1;
			lfsr_d    <= {lfsr_d[30:0], lfsr_d[31] ^ lfsr_d[21] ^ lfsr_d[1] ^ lfsr_d[0]};
			dma_gap   <= lfsr_d[8] ? lfsr_d[5:0] : lfsr_d[1:0];   // op lists: bursts and pauses
		end
	end
	else if (dma_on) begin
		if (dma_gap != 0) dma_gap <= dma_gap - 1;
		else begin
			dma_req   <= 1;
			dma_addr  <= 25'h040000 + {15'd0, lfsr_d[13:4]};
			dma_wdata <= lfsr_d;
		end
	end
end
// ---- the requester -------------------------------------------------------
// value the requester's region must hold: a function of the address unless a
// requester store replaced it
reg [31:0] shadow [0:4095];
function [31:0] pat(input [31:0] a);
	pat = {a[15:2], 2'b00, a[15:2], 2'b11} ^ 32'h5A5A_0000;
endfunction

integer errors = 0;
integer reads = 0, writes = 0, line_acks = 0;
always @(posedge clk) if (bus_line_ack) line_acks <= line_acks + 1;
integer under_ack = 0, ack_in_mem = 0;
always @(posedge clk) begin
	if (bus_line_ack && bus_req_adapter) under_ack <= under_ack + 1;
	if (bus_line_ack && svc != S_IDLE) ack_in_mem <= ack_in_mem + 1;
end

// one transaction; returns in the ack clock, so the caller's next request is
// on the bus in the clock after the ack, as the cache's is
task automatic xact(input wr, input [31:0] a, input [31:0] d, output [31:0] q);
	begin
		// requester registers change just after the clock edge, as flops do
		bus_req   = 1;
		bus_write = wr;
		bus_addr  = a;
		bus_wdata = d;
		@(negedge clk);
		while (!bus_ack) @(negedge clk);
		q = bus_rdata;
		@(posedge clk); #1;
	end
endtask

task automatic idle(input integer n);
	begin
		bus_req = 0;
		repeat (n) @(posedge clk);
		#1;
	end
endtask

integer i, r, w;
reg [31:0] q, a, lfsr;

initial begin
	$display("tb_line_dma: FIX=%0d ROUNDS=%0d", FIX, ROUNDS);
	repeat (8) @(posedge clk);
	nreset = 1;
	repeat (4) @(posedge clk);
	init = 0;
	repeat (8000) @(posedge clk);          // the chip's power-up sequence
	#1;

	// fill the requester's region (lines 0..1023) with the address pattern
	for (i = 0; i < 4096; i = i + 1) begin
		shadow[i] = pat(i << 2);
		xact(1, i << 2, shadow[i], q);
	end
	idle(4);

	dma_on = 1;
	lfsr = 32'h1234_ABCD;
	for (r = 0; r < ROUNDS; r = r + 1) begin
		lfsr = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
		a = {20'd0, lfsr[11:2], 2'b00} << 2;      // a line base in the region
		a = {a[31:4], 4'h0};
		// the cache's fill shape: four aligned longwords, back to back
		for (w = 0; w < 4; w = w + 1) begin
			xact(0, a + (w << 2), 0, q);
			reads = reads + 1;
			if (q !== shadow[(a >> 2) + w]) begin
				errors = errors + 1;
				if (errors <= 8)
					$display("  READ  %08x = %08x, expected %08x (round %0d, beat %0d)",
					         a + (w << 2), q, shadow[(a >> 2) + w], r, w);
			end
		end
		// a store straight after the fill, as a CAS's write follows its read
		if (lfsr[20]) begin
			shadow[(a >> 2) + lfsr[19:18]] = ~lfsr;
			xact(1, a + (lfsr[19:18] << 2), ~lfsr, q);
			writes = writes + 1;
		end
		if (lfsr[23:22] == 0) idle(lfsr[26:24]);
	end
	idle(4);
	dma_on = 0;
	idle(64);

	// every store must have landed
	for (i = 0; i < 4096; i = i + 1) begin
		xact(0, i << 2, 0, q);
		if (q !== shadow[i]) begin
			errors = errors + 1;
			if (errors <= 16)
				$display("  FINAL %08x = %08x, expected %08x", i << 2, q, shadow[i]);
		end
	end

	$display("tb_line_dma: line ack with FSM busy %0d, adapter request under a line ack %0d", ack_in_mem, under_ack);
	$display("tb_line_dma: %0d reads, %0d stores, %0d line acks, %0d DMA beats, %0d errors",
	         reads, writes, line_acks, dma_beats, errors);
	if (errors == 0) $display("tb_line_dma: PASS");
	else             $display("tb_line_dma: FAIL");
	$finish;
end

initial begin
	#(64'd40_000_000_000);
	$display("tb_line_dma: TIMEOUT");
	$finish;
end

endmodule
