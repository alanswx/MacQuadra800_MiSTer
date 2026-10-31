// tb_pix_retarget: the pix_reconfig block of MacQuadra800.sv (a copy, with its
// block-local regs hoisted: Verilator re-runs their initialisers) against a fake
// pll_cfg that ignores the first +ignore=N start writes.  Expect N retries and
// clk_vid at 25.175 MHz (hp=19.861) for N <= 15.
// verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style --top-module tb tb_pix_retarget.sv
`timescale 1ns/1ps
module tb;
reg CLK_50M=0; always #10 CLK_50M=~CLK_50M;
real hp = 7.093; // 70.49 MHz half period
reg clk_vid=0; always #(hp) clk_vid=~clk_vid;
reg pll_video_locked=1; wire pixcfg_waitrequest=0;
reg [31:0] pix_c0 = 32'h00000E0E;
localparam [31:0] PIX_C0_STATIC = 32'h00000505;
reg pixcfg_write=0; reg [5:0] pixcfg_address=0; reg [31:0] pixcfg_data=0;
integer starts=0, ignore=1; reg [31:0] c0w=0;
always @(posedge CLK_50M) if (pixcfg_write) begin
  if (pixcfg_address==5) c0w = pixcfg_data;
  if (pixcfg_address==2) begin starts=starts+1; $display("%0t start #%0d c0=%h", $time, starts, c0w);
    if (starts > ignore) begin case (c0w[7:0]) 8'h0E: hp=19.861; 8'h16: hp=31.92; 8'h06: hp=9.221; default: hp=7.093; endcase end
  end
end
reg [3:0] pixmon_div = 4'd0;
always @(posedge clk_vid) pixmon_div <= pixmon_div + 4'd1;

reg pix_quiet = 1'b0;
reg [3:0] pix_retries = 4'd0;          // retargets the check had to repeat
reg [21:0] settle = 22'd0;
reg [31:0] c0_cur = PIX_C0_STATIC;   // the divider the PLL powers up with
reg [31:0] c0_s1 = PIX_C0_STATIC, c0_s2 = PIX_C0_STATIC;
reg [2:0]  state = 0;
reg        pixmon_meta, pixmon_s1, pixmon_s2;
reg [15:0] pixmon_win = 16'd0;
reg [13:0] pixmon_cnt = 14'd0;
reg [13:0] pix_lo, pix_hi;
reg        pix_redo;
always @(posedge CLK_50M) begin : pix_reconfig
	c0_s1 <= pix_c0;                     // settle across clk_sys -> CLK_50M
	c0_s2 <= c0_s1;
	pixmon_meta <= pixmon_div[3];
	pixmon_s1   <= pixmon_meta;
	pixmon_s2   <= pixmon_s1;
	case (c0_cur[7:0])                   // clk_vid/8 edges in 1.31 ms, +-1/16
		8'h16:   begin pix_lo <= 14'd2406;  pix_hi <= 14'd2727;  end // 15.664 MHz
		8'h06:   begin pix_lo <= 14'd8329;  pix_hi <= 14'd9439;  end // 54.223
		8'h05:   begin pix_lo <= 14'd10828; pix_hi <= 14'd12271; end // 70.490
		default: begin pix_lo <= 14'd3867;  pix_hi <= 14'd4382;  end // 25.175
	endcase
	pix_redo <= 1'b0;
	if (state != 0 || settle != 0 || !pll_video_locked) begin
		pixmon_win <= 16'd0;
		pixmon_cnt <= 14'd0;
	end else begin
		pixmon_win <= pixmon_win + 16'd1;
		if (pixmon_s1 != pixmon_s2 && pixmon_cnt != 14'h3FFF) pixmon_cnt <= pixmon_cnt + 14'd1;
		if (pixmon_win == 16'hFFFF) begin
			pixmon_cnt <= 14'd0;
			if ((pixmon_cnt < pix_lo || pixmon_cnt > pix_hi) && pix_retries != 4'hF) pix_redo <= 1'b1;
		end
	end
	if ((c0_s2 == c0_s1 && c0_s2 != c0_cur) || pix_redo) begin
		settle    <= 22'h3FFFFF;
		pix_quiet <= 1'b1;
	end else if (settle != 0) begin
		settle    <= settle - 1'd1;
	end else begin
		pix_quiet <= 1'b0;
	end
	if (pix_redo) pix_retries <= pix_retries + 4'd1;
	if (!pixcfg_waitrequest) begin
		pixcfg_write <= 0;
		if (pll_video_locked) begin
			if (state) state <= state + 1'd1;
			case (state)
				0: if (c0_s2 == c0_s1 && c0_s2 != c0_cur) begin
						c0_cur <= c0_s2;
						state  <= 1;
					end
					else if (pix_redo) state <= 1;
				1: begin pixcfg_address <= 0; pixcfg_data <= 0;      pixcfg_write <= 1; end // polled mode
				3: begin pixcfg_address <= 5; pixcfg_data <= c0_cur; pixcfg_write <= 1; end // C0 counter
				5: begin pixcfg_address <= 2; pixcfg_data <= 0;      pixcfg_write <= 1; end // start
				default: ;
			endcase
		end
	end
end

initial begin
  if ($value$plusargs("ignore=%d", ignore)) ;
  #2000000000; $display("done: starts=%0d retries=%0d hp=%f quiet=%b", starts, pix_retries, hp, pix_quiet); $finish;
end
endmodule
