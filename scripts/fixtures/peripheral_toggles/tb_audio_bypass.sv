`timescale 1ns/1ps
module tb_audio_bypass;
reg clk=0;
always #5 clk=~clk;
reg reset=1, rate=0, signed_audio=1;
reg [31:0] flt_rate=0;
reg [4:0] att=0;
reg [1:0] boost=0,mix=0;
reg [15:0] l=0,r=0,alsa_l=0,alsa_r=0;
wire bclk,lrclk,data,spdif,dacl,dacr;
audio_out dut(.reset(reset),.clk(clk),.sample_rate(rate),.flt_rate(flt_rate),
 .cx(40'h123456789a),.cx0(8'h87),.cx1(8'h65),.cx2(8'h43),
 .cy0(24'habcdef),.cy1(24'h123456),.cy2(24'h789abc),
 .att(att),.boost(boost),.mix(mix),.is_signed(signed_audio),.core_l(l),.core_r(r),
 .alsa_l(alsa_l),.alsa_r(alsa_r),.i2s_bclk(bclk),.i2s_lrclk(lrclk),.i2s_data(data),
 .spdif(spdif),.dac_l(dacl),.dac_r(dacr));

// Independent bypass and DC-blocker arithmetic reference, including the
// previous-sample NBA boundary. Mixer reference reuses unchanged production
// module to verify channel routing, Linux mix, attenuation and boost wiring.
reg [15:0] expected_l=0,expected_r=0;
reg [39:0] x1l=0,x1r=0,yl=0,yr=0;
wire [15:0] dl=dut.a_en2 ? yl[38:23] : 16'd0;
wire [15:0] dr=dut.a_en2 ? yr[38:23] : 16'd0;
wire [15:0] mixl,mixr,prel,prer;
aud_mix_top ref_l(clk,dut.sample_ce,att,boost,mix,dl,alsa_l,prer,prel,mixl);
aud_mix_top ref_r(clk,dut.sample_ce,att,boost,mix,dr,alsa_r,prel,prer,mixr);
integer samples=0, checks=0, clocks=0, last_sample=0;
integer warm_samples=0;
integer bc=0,sc=0,dc=0;
reg oldb=0,olds=0,oldd=0;
function automatic [39:0] asr(input signed [39:0] value, input integer amount);
 asr=value >>> amount;
endfunction
always @(posedge clk) begin : scoreboard
 reg [39:0] xl,xr,nl,nr;
 reg ce;
 ce=dut.sample_ce;
 clocks++;
 if(reset) warm_samples=0;
 else if(ce) warm_samples++;
 if(ce) begin
  xl={expected_l[15],expected_l,23'd0}; xr={expected_r[15],expected_r,23'd0};
  xl=xl-asr(xl,rate?11:10);
  xr=xr-asr(xr,rate?11:10);
  nl=xl-x1l+yl-asr(yl,rate?10:9);
  nr=xr-x1r+yr-asr(yr,rate?10:9);
  x1l<=xl; x1r<=xr;
  yl<=(^nl[39:38])?{{2{nl[39]}},{38{nl[38]}}}:nl;
  yr<=(^nr[39:38])?{{2{nr[39]}},{38{nr[38]}}}:nr;
  if(last_sample && !reset) begin
   assert(clocks-last_sample==(rate?256:512)) else $fatal(1,"sample cadence");
  end
  last_sample=clocks;
  samples++;
 end
 if(reset) begin expected_l<=0; expected_r<=0; end
 else if(ce) begin
  expected_l<=dut.a_en1?{~signed_audio ^ dut.cl[15],dut.cl[14:0]}:16'd0;
  expected_r<=dut.a_en1?{~signed_audio ^ dut.cr[15],dut.cr[14:0]}:16'd0;
 end
 #1;
 assert(dut.acl===expected_l && dut.acr===expected_r) else $fatal(1,"signed/sample/CE boundary");
 assert(dut.a_en1==(warm_samples>=4) && dut.a_en2==(warm_samples>(rate?16384:8192)))
  else $fatal(1,"startup gate duration");
 assert(dut.adl===dl && dut.adr===dr) else $fatal(1,"DC state/stereo/startup mute: got %h/%h expected %h/%h",dut.adl,dut.adr,dl,dr);
 assert(dut.al===mixl && dut.ar===mixr) else $fatal(1,"volume/Linux/boost/mix pipeline");
 if(bclk!=oldb) bc++; if(spdif!=olds) sc++; if(dacl!=oldd) dc++;
 oldb=bclk; olds=spdif; oldd=dacl;
 checks+=3;
end

task automatic wait_samples(input integer n);
 integer goal;
 begin goal=samples+n; while(samples<goal) @(negedge clk); end
endtask
initial begin
 for(integer sr=0;sr<2;sr++) begin
  @(negedge clk); reset=1; rate=sr; last_sample=0;
  signed_audio=1; l=0; r=0; alsa_l=0; alsa_r=0; att=0; boost=0; mix=0;
  wait_samples(4);
  @(negedge clk); reset=0;
  wait_samples(8);
  assert(!dut.a_en2 && dut.a_en1) else $fatal(1,"startup gate");
  wait_samples(sr?32770:16386);
  assert(dut.a_en2) else $fatal(1,"startup release");
  for(integer k=0;k<24;k++) begin
   @(negedge clk);
   signed_audio=(k<12); flt_rate=(k&1)?32'hffffffff:0;
   case(k%6)
    0: begin l=16'h0000; r=16'h8000; end
    1: begin l=16'h7fff; r=16'hffff; end
    2: begin l=16'h8000; r=16'h7fff; end
    3: begin l=16'hffff; r=16'h0001; end
    4: begin l=16'h1234; r=16'hfedc; end
    5: begin l=16'h8000; r=16'h8000; end
   endcase
   alsa_l=16'h1234; alsa_r=16'hfedc;
   att=k%6; mix=k%4; boost=k%3;
   wait_samples(16);
   assert(dut.cl==l && dut.cr==r &&
          dut.acl=={~signed_audio ^ l[15],l[14:0]} &&
          dut.acr=={~signed_audio ^ r[15],r[14:0]}) else $fatal(1,"stable stereo conversion");
  end
  // A one-clock asynchronous input glitch must not pass the existing
  // two-consecutive-equal-samples capture stage.
  @(negedge clk); l=16'h0000; r=16'hffff;
  @(negedge clk); l=16'h8000; r=16'h8000;
  repeat(4) @(negedge clk);
  assert(dut.cl==16'h8000 && dut.cr==16'h8000) else $fatal(1,"input glitch rejection");
  @(negedge clk); att=16; wait_samples(12);
  assert(dut.al==0 && dut.ar==0) else $fatal(1,"attenuation mute");
  @(negedge clk); reset=1; #2;
  assert(dut.acl==0 && dut.acr==0 && !dut.a_en2) else $fatal(1,"async reset");
  $display("PASS audio %0d kHz: signed/unsigned extrema, stereo, CE hold, rate-independent bypass, reset, startup, DC, mix/volume",sr?96:48);
 end
 assert(bc>100 && sc>100 && dc>100) else $fatal(1,"output serializers inactive");
 $display("PASS audio bypass: %0d sample events, %0d checks; I2S/SPDIF/DAC activity %0d/%0d/%0d",samples,checks,bc,sc,dc);
 $finish;
end
endmodule
