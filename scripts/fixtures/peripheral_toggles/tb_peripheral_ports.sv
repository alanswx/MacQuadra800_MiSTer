`timescale 1ns/1ps
module tb_peripheral_ports;
reg clk=0;
always #5 clk=~clk;
reg blank=0, vs=0, hs=0, de=0;
reg [23:0] rgb=0;
wire [26:0] got, golden;
trim_shadow dut(clk,blank,rgb,vs,hs,de,got);
// The actual original shadowmask at unity gain is the latency oracle.
shadowmask ref_mask(.clk(clk),.clk_sys(clk),.cmd_wr(1'b1),.cmd_in(16'd0),
 .din(blank ? 24'd0 : rgb),.hs_in(hs),.vs_in(vs),.de_in(de),.brd_in(~de),.enable(1'b1),
 .dout(golden[26:3]),.vs_out(golden[2]),.hs_out(golden[1]),.de_out(golden[0]));
reg rxin=1, dsr=1, tx=1, rts=1;
reg [7:0] mode=0;
reg signed [15:0] ml=0,mr=0,cl=0,cr=0;
wire txout,rtsout,dtr,rx,info;
wire [3:0] infod;
wire [6:0] userout;
wire [23:0] vga;
wire [15:0] al,ar;
trim_ports ports(rxin,dsr,tx,rts,mode,rgb[23:16],rgb[15:8],rgb[7:0],ml,mr,cl,cr,
 txout,rtsout,dtr,userout,vga[23:16],vga[15:8],vga[7:0],al,ar,rx,info,infod);
function automatic [15:0] sat(input integer v);
 sat=(v>32767)?16'h7fff:(v< -32768)?16'h8000:v[15:0];
endfunction
integer checks=0;
initial begin
 repeat(20) @(negedge clk);
 for(integer i=0;i<1000;i=i+1) begin
  rgb=$random; {blank,vs,hs,de}=$random;
  {rxin,dsr,tx,rts}=$random; mode=i%5;
  ml=$random; mr=$random; cl=$random; cr=$random;
  @(posedge clk); #1;
  assert(got===golden) else $fatal(1,"shadowmask latency/blanking %0d got=%h ref=%h",i,got,golden);
  assert(userout==7'h7f && !info && infod==0) else $fatal(1,"MT32 idle ties");
  assert(rx==rxin && txout==tx && rtsout==rts && dtr==dsr) else $fatal(1,"host UART mode %0d",mode);
  assert(vga==rgb) else $fatal(1,"LCD bypass");
  assert(al==sat(integer'(ml)+integer'(cl)) && ar==sat(integer'(mr)+integer'(cr))) else $fatal(1,"EASC/CD stereo saturation");
  checks+=5;
  @(negedge clk);
 end
 $display("PASS peripheral ports/shadowmask: %0d checks",checks);
 $finish;
end
endmodule
