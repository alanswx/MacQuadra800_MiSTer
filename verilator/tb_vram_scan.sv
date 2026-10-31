`timescale 1ns/1ps
// Build: verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style --top-module tb_vram_scan tb_vram_scan.sv ../rtl/vram_ddr3.sv
// Run:   ./obj_dir/Vtb_vram_scan +verilator+seed+N [+n=clocks] [+stallp=1-in-N scaler stall] [+busyp=CPU traffic 1/N]
// Scanout check: vram_ddr3 with a DAFB-like scanout (16 bpp 640 wide, stride
// 1280, H_TOT 800) and the MacQuadra800.sv arbiter's handshake with random
// BUSY, long scaler stalls and read gaps.  CPU traffic only touches the upper
// half of VRAM, so every displayed word must equal the initial memory.
module tb_vram_scan;
reg clk_sys = 0, clk_vid = 0;
real hs = 18.52, hv = 19.86;
always #(hs) clk_sys = ~clk_sys;
always #(hv) clk_vid = ~clk_vid;
reg reset = 1, reset_vid = 1;
reg mem_req = 0, mem_is_vram = 0, mem_write = 0, mem_vram_wp = 0;
reg [31:2] mem_addr = 0; reg [3:0] mem_be = 0; reg [31:0] mem_wdata = 0;
reg [9:0] vid_col_word = 0; reg [13:0] vid_stride = 14'd1280;
reg vid_line_req = 0, vid_line_swap = 0; reg [20:0] vid_line_addr = 0;
reg ddr_busy = 0, ddr_ack = 0, ddr_rvalid = 0; reg [63:0] ddr_dout = 0;
wire n_ack, n_room, n_req, n_we; wire [31:0] n_rd, n_vid; wire [28:0] n_addr;
wire [7:0] n_bc, n_be; wire [63:0] n_din;

vram_ddr3 n(.clk_sys, .reset, .mem_req, .mem_is_vram, .mem_write, .mem_addr, .mem_be, .mem_wdata, .mem_vram_wp,
  .vram_ack(n_ack), .vram_rdata(n_rd), .vram_wq_room(n_room), .clk_vid, .reset_vid, .vid_col_word, .vid_stride,
  .vid_line_req, .vid_line_addr, .vid_line_swap, .vid_rdata(n_vid), .vram_ddr_req(n_req), .vram_ddr_we(n_we),
  .vram_ddr_addr(n_addr), .vram_ddr_burstcnt(n_bc), .vram_ddr_din(n_din), .vram_ddr_be(n_be),
  .vram_ddr_busy(ddr_busy), .vram_ddr_ack(ddr_ack), .vram_ddr_dout(ddr_dout), .vram_ddr_rvalid(ddr_rvalid));

reg [63:0] mem [0:131071];
reg [63:0] init [0:16383];
reg accept = 0, wait_wr = 0, wait_rd = 0, rd_ack = 0;
reg [7:0] left = 0; reg [16:0] a = 0; reg [3:0] lat = 0; integer stall = 0;
integer head_lines = 0; integer i, j, bad_words = 0, bad_lines = 0, lines = 0, wbeats = 0, rbeats = 0, bursts = 0;
reg [31:0] seed; integer N, stallp;
wire wr_ack = wait_wr && !ddr_busy;
always @(*) ddr_ack = wr_ack || rd_ack;
always @(*) begin ddr_rvalid = wait_rd && lat == 0 && !rd_ack && !ddr_busy; ddr_dout = mem[a]; end
always @(posedge clk_sys) begin
  rd_ack <= 0;
  if (stall > 0) begin stall <= stall - 1; ddr_busy <= 1; end
  else if (($urandom % stallp) == 0) begin stall <= 10 + $urandom % 120; ddr_busy <= 1; end
  else ddr_busy <= ($urandom % 4) == 0;
  if (!n_req && !wait_wr) accept <= 0;
  if (wait_wr && !ddr_busy) begin
    for (i = 0; i < 8; i = i + 1) if (n_be[i]) mem[a][8*i +: 8] <= n_din[8*i +: 8];
    a <= a + 1; left <= left - 1; wbeats <= wbeats + 1;
    if (left == 1) begin wait_wr <= 0; if (!n_req) accept <= 0; end
  end else if (wait_rd) begin
    if (ddr_rvalid) begin a <= a + 1; left <= left - 1; rbeats <= rbeats + 1; lat <= $urandom % 3 == 0 ? $urandom % 6 : 0;
      if (left == 1) wait_rd <= 0; end
    else if (lat != 0) lat <= lat - 1;
  end else if (!ddr_busy && n_req && !accept && ($urandom % 3 != 0)) begin
    a <= n_addr[16:0]; left <= n_bc; accept <= 1; bursts <= bursts + 1;
    if (n_we) wait_wr <= 1; else begin wait_rd <= 1; rd_ack <= 1; lat <= $urandom % 8; end
  end
end

// scanout: 64 lines of 1280 bytes from 0, request at hcnt 16 for the next
// line, swap at H_TOT-3, a word every two pixels over 640 pixels
localparam H_TOT = 800, H_ACT = 640;
integer h = 0, line = 0, req_line = 0, disp_line = -1, chk_line = -1, chk_col = 0, nlines = 0;
reg chk = 0, line_bad = 0; integer first_bad = -1, last_bad = -1;
reg [31:0] got_first = 0;
function [31:0] w32(input integer l, input integer c);
  reg [63:0] b; integer wi;
  begin wi = l * 320 + c; b = init[wi >> 1]; w32 = wi[0] ? b[63:32] : b[31:0]; end
endfunction
always @(negedge clk_vid) if (chk) begin
  if (n_vid !== w32(chk_line, chk_col)) begin
    bad_words = bad_words + 1;
    if (!line_bad) begin first_bad = chk_col; got_first = n_vid; end
    line_bad = 1; last_bad = chk_col;
  end
end
always @(posedge clk_vid) if (!reset_vid) begin
  // what the RAM read sampled on this edge
  if (vid_line_swap) disp_line = req_line;
  chk <= (disp_line >= 0) && (h < H_ACT) && (nlines > 3);
  chk_line <= disp_line; chk_col <= vid_col_word;
  // the scanout's own registers
  vid_line_req <= 0; vid_line_swap <= 0;
  h <= (h == H_TOT - 1) ? 0 : h + 1;
  if (h == 16) begin req_line <= (line + 1) % 64; vid_line_addr <= ((line + 1) % 64) * 1280; vid_line_req <= 1; end
  if (h == H_TOT - 3) begin
    vid_line_swap <= 1; vid_col_word <= 0; line <= (line + 1) % 64; nlines <= nlines + 1;
    if (line_bad) begin
      bad_lines = bad_lines + 1;
      if (first_bad < 64) head_lines = head_lines + 1;
      if (first_bad < 64 && head_lines <= 12) begin
        // where did the first bad word come from?
        j = -1; for (i = 0; i < 32768; i = i + 1) if (j < 0 && w32(i / 320, i % 320) == got_first) j = i;
        $display("line %0d (displayed %0d): cols %0d..%0d bad, col %0d holds %h = line %0d col %0d @%0t",
          lines, disp_line, first_bad, last_bad, first_bad, got_first, j < 0 ? -1 : j / 320, j < 0 ? -1 : j % 320, $time);
      end
    end
    line_bad = 0; lines = lines + 1;
  end
  else if (h < H_ACT && h[0]) vid_col_word <= vid_col_word + 1;
end

// CPU: posted writes and handshake writes to the upper half, reads anywhere
reg [31:2] wa = 0; reg rd_on = 0, hw_on = 0; integer busyp;
always @(posedge clk_sys) if (!reset) begin
  mem_vram_wp <= 0;
  if (rd_on || hw_on) begin
    if (n_ack) begin rd_on <= 0; hw_on <= 0; mem_req <= 0; end
  end else begin
    case ($urandom % busyp)
    0,1,2,3,4,5,6,7: if (n_room) begin
        case ($urandom % 8) 0,1,2,3: wa <= wa + 1; 4: wa <= wa; 5: wa <= wa + 2; default: wa <= $urandom; endcase
        mem_vram_wp <= 1; mem_addr <= {wa[31:20], 1'b1, wa[18:2]}; mem_be <= ($urandom % 3 == 0) ? (4'b1 << ($urandom % 4)) : 4'hF; mem_wdata <= $urandom;
      end
    8,9: begin rd_on <= 1; mem_req <= 1; mem_is_vram <= 1; mem_write <= 0; mem_addr <= $urandom % 262144; end
    10: begin hw_on <= 1; mem_req <= 1; mem_is_vram <= 1; mem_write <= 1; mem_addr <= 131072 + $urandom % 131072;
        mem_be <= 4'hF; mem_wdata <= $urandom; end
    default: ;
    endcase
  end
end

initial begin
  if (!$value$plusargs("n=%d", N)) N = 2000000;
  if (!$value$plusargs("stallp=%d", stallp)) stallp = 300;
  if (!$value$plusargs("busyp=%d", busyp)) busyp = 16;
  if ($test$plusargs("vid70")) hv = 7.09;
  if ($test$plusargs("sys33")) hs = 15.0;
  for (i = 0; i < 131072; i = i + 1) mem[i] = {$urandom, $urandom};
  for (i = 0; i < 16384; i = i + 1) init[i] = mem[i];
  repeat (5) @(posedge clk_sys); reset = 0; reset_vid = 0;
  repeat (N) @(posedge clk_sys);
  $display("%0d head-bad lines; %0d lines, %0d bad lines, %0d bad words; %0d write beats, %0d read beats, %0d bursts",
    head_lines, lines, bad_lines, bad_words, wbeats, rbeats, bursts);
  $finish;
end
endmodule
