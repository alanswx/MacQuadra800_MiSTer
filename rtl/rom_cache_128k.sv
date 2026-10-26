//============================================================================
//  rom_cache_128k.sv — 128 KB Direct-Mapped BRAM Cache for Quadra 800 ROM
//
//  The Quadra 800 has a 1 MB physical ROM ($40800000-$408FFFFF / $40F00000-$40FFFFFF).
//  QuickDraw and Mac OS toolbox routines execute from ROM and thrash the 8 KB
//  L1 I-cache. Without a ROM cache, each I-cache fill requires a 2-beat DDR3
//  round-trip (35-45 cycles) competing with streaming DDR3 VRAM writes.
//
//  This module implements a 128 KB direct-mapped cache using on-chip M10K BRAM:
//  - 8,192 lines of 16 bytes (128 bits each = 4 longwords).
//  - Line address: addr[19:4] (16 bits for 1 MB ROM).
//  - Cache index:  addr[16:4] (13 bits = 8,192 lines).
//  - Cache tag:    addr[19:17] (3 bits).
//  - BRAM usage:   ~139 M10K blocks out of 364 free blocks on Cyclone V.
//
//  Hit latency: 1 cycle from lookup_req to lookup_hit / lookup_data.
//============================================================================

`timescale 1ns/1ps

module rom_cache_128k (
	input             clk,
	input             rst,            // synchronous reset (invalidates cache)

	// Lookup port (synchronous read)
	input             lookup_req,
	input      [19:4] lookup_addr,
	output            lookup_hit,
	output    [127:0] lookup_data,

	// Fill port (from DDR3 completion)
	input             fill_we,
	input      [19:4] fill_addr,
	input     [127:0] fill_data
);

	localparam integer LINES      = 8192;
	localparam integer INDEX_BITS = 13;   // addr[16:4]
	localparam integer TAG_BITS   = 3;    // addr[19:17]

	// 8,192 x 128-bit line data RAM (128 M10K blocks in 8192x1)
	(* ramstyle = "M10K, no_rw_check" *)
	reg [127:0] data_mem [0:LINES-1];

	// 8,192 x 11-bit tag RAM: {epoch[7:0], tag[2:0]} (11 M10K blocks)
	(* ramstyle = "M10K, no_rw_check" *)
	reg [10:0] tag_mem [0:LINES-1];



	// Generation / epoch counter for instant O(1) invalidation on reset
	reg  [7:0] epoch = 8'd1;
	reg        rst_prev = 1'b0;

	// Background sweeper to zero tag memory while reset is actively held
	reg [12:0] clr_idx = 13'd0;

	// Registered lookup pipeline
	reg [127:0] lookup_data_q = 128'd0;
	reg  [10:0] tag_data_q = 11'd0;
	reg   [2:0] req_tag_q = 3'd0;
	reg         req_valid_q = 1'b0;

	always @(posedge clk) begin
		rst_prev <= rst;

		// On rising edge of reset, bump epoch (skip 0)
		if (rst && !rst_prev) begin
			epoch   <= (epoch == 8'hFF) ? 8'd1 : (epoch + 1'b1);
			clr_idx <= 13'd0;
		end

		// Background sweeper writes zero only while rst is high
		if (rst) begin
			tag_mem[clr_idx] <= 11'd0;
			clr_idx <= clr_idx + 13'd1;
		end
		else if (fill_we) begin
			data_mem[fill_addr[16:4]] <= fill_data;
			tag_mem[fill_addr[16:4]]  <= {epoch, fill_addr[19:17]};
		end

		// Synchronous lookup read
		if (lookup_req && !rst) begin
			lookup_data_q <= data_mem[lookup_addr[16:4]];
			tag_data_q    <= tag_mem[lookup_addr[16:4]];
			req_tag_q     <= lookup_addr[19:17];
			req_valid_q   <= 1'b1;
		end
		else begin
			req_valid_q   <= 1'b0;
		end
	end

	wire tag_match = (tag_data_q[10:3] == epoch) && (tag_data_q[2:0] == req_tag_q);

	assign lookup_data = lookup_data_q;
	assign lookup_hit  = req_valid_q && tag_match;

endmodule
