// tb_gfx: a QuickDraw-shaped microbench for the dual core through
// quadra_cpu040, against a memory that answers the way quadra800 does.
//
// It replaces the hour-long OS boot for the CPU-side half of the graphics
// gap: the cost of uncached VRAM stores, unaligned spanning stores and
// uncached framebuffer read-modify-writes, versus the same operations on
// cacheable RAM.  gfx.s runs each kernel a fixed number of times and writes
// a tag to the timestamp port between them; the harness prints the cycle,
// beat, read and write counters at each tag, so cost-per-operation is a
// subtraction.  No DDR3 model here: DDR3 latency is measured in the full
// sim; this isolates the part that lives inside the CPU and the direct path.
//
//   $50000010  timestamp port: on write, print [T] with the written tag
//   $50000000  result port: $A5A5A5A5 ends the run
//   +platform (default on) acks direct RAM/VRAM writes the next clock, as
//              quadra800's bus_wr_direct / bus_vram_direct paths do
//   +lat=N     fixed latency for every non-direct transaction (default 1;
//              deterministic, so a baseline and a modified core differ only
//              by the change)
`timescale 1ns/1ps
module tb_gfx #(parameter VRAM_POST = 1);
reg clk = 0; always #5 clk = ~clk;
reg nreset = 0;

wire        bus_req, bus_write, bus_instr;
wire  [1:0] bus_size;
wire [31:0] bus_addr, bus_wdata;
wire  [2:0] bus_fc;
reg         bus_ack = 0;
reg  [31:0] bus_rdata = 0;
reg   [2:0] ipl = 3'b111;

// +nosb drops store_buffer_ok, so VRAM/RAM stores are not posted through the
// external wombat_store_buffer: an A/B for what that buffer buys the dual core.
reg sb_ok = 1;
initial if ($test$plusargs("nosb")) sb_ok = 0;

quadra_cpu040 #(.AP040_VRAM_POST(VRAM_POST)) dut (
	.clk(clk), .nreset(nreset), .ce(1'b1),
	.ipl(ipl), .ipl_autovector(1'b1), .berr(1'b0), .stall_hold(1'b0), .dbg_stall_flt(),
	.cache_line_valid(1'b0), .cache_line_tag(28'd0), .cache_line_data(128'd0), .store_buffer_ok(sb_ok),
	.bus_req(bus_req), .bus_write(bus_write), .bus_instr(bus_instr), .bus_size(bus_size),
	.bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_fc(bus_fc), .bus_ack(bus_ack), .bus_rdata(bus_rdata),
	.walker_req(), .walker_we(), .walker_addr(), .walker_wdat(),
	.walker_ack(1'b0), .walker_data(32'd0), .walker_berr(1'b0),
	.snoop_stb(1'b0), .snoop_addr(32'd0),
	.nresetout(), .nmi_ack_toggle(), .cacr_out(), .vbr_out(), .debug_busy(),
	.debug_fault(), .debug_halted(), .debug_status(), .debug_status2()
);

// 256 KB flat memory, addressed by bus_addr[17:0].  Code and the RAM bench
// window live low; the VRAM window is mapped from $F9010000 into mem[0x10000].
localparam MEMBYTES = 262144;
reg [7:0] mem [0:MEMBYTES-1];
reg [31:0] words [0:MEMBYTES/4-1];
integer i;
initial begin
	for (i = 0; i < MEMBYTES; i = i + 1) mem[i] = 0;
	for (i = 0; i < MEMBYTES/4; i = i + 1) words[i] = 0;
	$readmemh("gfx.hex", words);
	for (i = 0; i < MEMBYTES/4; i = i + 1) begin
		mem[4*i]   = words[i][31:24]; mem[4*i+1] = words[i][23:16];
		mem[4*i+2] = words[i][15:8];  mem[4*i+3] = words[i][7:0];
	end
end

function [17:0] off(input [31:0] a);
	off = a[17:0];
endfunction

reg platform = 1;
integer lat = 1;
integer nbytes;
reg busy = 0;
reg [2:0] wait_n;
integer cyc = 0, beats = 0, reads = 0, writes = 0;
initial begin
	if ($test$plusargs("noplatform")) platform = 0;
	void'($value$plusargs("lat=%d", lat));
	$display("[CFG] platform=%0d lat=%0d sb_ok=%0d", platform, lat, sb_ok);
end

wire is_direct = (bus_addr[31:30] == 2'b00) || (bus_addr[31:21] == 11'b1111_1001_000);

// DMU engine-state sampling between a kernel's open and close tags
integer est_hist [0:63];
integer est_total = 0, est_wb_wait = 0;
reg     est_on = 0;
always @(posedge clk) if (est_on) begin
	est_hist[dut.cpu.dmu.e_st] <= est_hist[dut.cpu.dmu.e_st] + 1;
	est_total <= est_total + 1;
	// a store sits in WB (not yet retired) while the engine is not idle
	if (dut.cpu.dmu.wb_st && !dut.cpu.dmu.st_rdy && dut.cpu.dmu.e_st != 0)
		est_wb_wait <= est_wb_wait + 1;
end

task do_access;
	begin
		beats <= beats + 1;
		nbytes = (bus_size == 0) ? 1 : (bus_size == 1) ? 2 : 4;
		if (bus_addr[31:28] == 4'h5) begin
			if (bus_write && bus_addr[7:0] == 8'h00) begin
				if (bus_wdata == 32'hA5A5A5A5) begin
					$display("DONE: %0d cycles, %0d beats, %0d reads, %0d writes", cyc, beats, reads, writes);
					$finish;
				end
				else begin
					$display("FAIL: tag %0h at cycle %0d", bus_wdata, cyc); $finish;
				end
			end
			if (bus_write && bus_addr[7:0] == 8'h10) begin
				$display("[T] tag=%0h cyc=%0d beats=%0d reads=%0d writes=%0d", bus_wdata, cyc, beats, reads, writes);
				// DMU engine-state histogram over the kernel just finished
				// (tags ending in 1 close the bracket the preceding tag opened)
				if (bus_wdata[3:0] == 4'h1) begin
					$display("[EST] kernel %0h: engine states (cycles) over %0d cycles:", bus_wdata[11:4], est_total);
					for (i = 0; i < 64; i = i + 1)
						if (est_hist[i] > est_total / 100)
							$display("[EST]   e_st=%0d %8d  %5.1f%%", i, est_hist[i], 100.0 * est_hist[i] / est_total);
					$display("[EST]   wb store waiting with engine busy: %0d cycles", est_wb_wait);
					est_on = 0;
				end
				else begin
					for (i = 0; i < 64; i = i + 1) est_hist[i] = 0;
					est_total = 0; est_wb_wait = 0; est_on = 1;
				end
			end
			bus_rdata <= 0;
		end
		else if (bus_write) begin
			writes <= writes + 1;
			for (i = 0; i < nbytes; i = i + 1)
				mem[off(bus_addr) + i] <= bus_wdata >> (8*(nbytes-1-i));
		end
		else begin
			reads <= reads + 1;
			bus_rdata <= (nbytes == 1) ? {24'd0, mem[off(bus_addr)]} :
			             (nbytes == 2) ? {16'd0, mem[off(bus_addr)], mem[off(bus_addr)+1]} :
			             {mem[off(bus_addr)], mem[off(bus_addr)+1], mem[off(bus_addr)+2], mem[off(bus_addr)+3]};
		end
		if (bus_size == 2 && bus_addr[1:0] != 0) begin
			$display("ERROR: misaligned long beat %h", bus_addr); $finish;
		end
	end
endtask

always @(posedge clk) begin
	cyc <= cyc + 1;
	bus_ack <= 0;
	if (!busy && bus_req && !bus_ack && platform && bus_write && is_direct) begin
		// the direct path: acknowledged the next clock
		bus_ack <= 1;
		do_access;
	end
	else if (!busy && bus_req && !bus_ack) begin
		busy <= 1;
		wait_n <= lat[2:0];
	end
	else if (busy) begin
		if (wait_n != 0) wait_n <= wait_n - 1;
		else begin
			busy <= 0;
			bus_ack <= 1;
			do_access;
		end
	end
	if (cyc > 20000000) begin
		$display("TIMEOUT pc %h beats %0d halted %b", dut.dbg_pc, beats, dut.dbg_halted);
		$finish;
	end
end

initial begin
	repeat (20) @(posedge clk);
	nreset = 1;
end
endmodule
