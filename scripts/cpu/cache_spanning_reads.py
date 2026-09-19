#!/usr/bin/env python3
"""Compare cache spanning-read data, latency and snoop behavior with baseline."""
from pathlib import Path
import argparse
import subprocess
r=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--cache',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
d=a.out.resolve();d.mkdir(parents=True,exist_ok=True)
s=(r/'rtl/ap68040/tb/tb_ap040_cache_snoop.v').read_text()
s=s.replace('integer errors = 0;', '''integer errors = 0;
integer span_checks=0, span_offset, span_phase, span_base;
reg [63:0] span_pair;
reg [31:0] span_expected;
''')
block=r'''
    // Prime a known line, then cover every within-line longword span.
    @(negedge clk);
    mem['hC800>>2]='h11223344; mem['hC804>>2]='h55667788;
    mem['hC808>>2]='h99AABBCC; mem['hC80C>>2]='hDDEEFF00;
    snoop('hC800);
    cpu_read_count_sized('hC800, 2'b10, d, normal_cycles);
    repeat(24) @(posedge clk);
    for(span_offset=1;span_offset<12;span_offset=span_offset+1) begin
      if((span_offset%4)!=0) begin
        @(negedge clk); c_addr='hC800+span_offset;
        repeat(2) @(posedge clk);
        span_pair={mem[('hC800+span_offset)>>2],mem[(('hC800+span_offset)>>2)+1]};
        span_pair=span_pair << (8*(span_offset%4));
        span_expected=span_pair[63:32];
        span_base=mread_count;
        cpu_read_count_sized('hC800+span_offset,2'b10,d,normal_cycles);
        if(d!==span_expected || mread_count!=span_base) begin
          $display("FAIL explicit span offset=%0d data=%h expected=%h",span_offset,d,span_expected);errors++;
        end
        $display("SPAN offset=%0d cycles=%0d",span_offset,normal_cycles);
        span_checks++;
        if((span_offset%4)==3) begin
          cpu_read_count_sized('hC800+span_offset,2'b01,d,normal_cycles);
          if(d!=={16'd0,span_expected[31:16]}) begin $display("FAIL explicit word span");errors++;end
          span_checks++;
        end
      end
    end
    // Snoop at admission, or during the early line-read assembly window.
    for(span_phase=0;span_phase<3;span_phase++) begin
      @(negedge clk);mem['hC804>>2]='h55667788;snoop('hC800);
      cpu_read_count_sized('hC800,2'b10,d,normal_cycles);
      repeat(24) @(posedge clk);
      @(negedge clk);c_addr='hC802;
      repeat(2) @(posedge clk);
      fork
        begin
          cpu_read_count_sized('hC802,2'b10,d,normal_cycles);
          if(d!==32'h3344ABCD) begin $display("FAIL span snoop phase=%0d data=%h",span_phase,d);errors++;end
        end
        begin
          @(negedge clk);
          repeat(span_phase == 0 ? 0 : 1) @(negedge clk);
          if(span_phase==2) begin ce_run=0; repeat(2) @(negedge clk); end
          mem['hC804>>2]='hABCDEF01;s_addr='hC800;s_stb=1;
          @(negedge clk);s_stb=0;
          if(span_phase==2) begin repeat(2) @(negedge clk);ce_run=1;end
        end
      join
      span_checks++;
    end
    $display("EXPLICIT_SPANS checks=%0d",span_checks);
'''
needle='\tif (errors == 0) $display("ALL TESTS PASSED");'
assert s.count(needle)==1
s=s.replace(needle,block+'\n'+needle)
(d/'spans_tb.v').write_text(s)
for name,cache in [('candidate',a.cache.resolve()),('baseline',r/'rtl/ap68040/rtl/ap040_cache.v')]:
 with (d/(name+'_spans_compile.log')).open('w') as f:
  subprocess.run(['iverilog','-g2012','-I',str(r/'rtl/ap68040/rtl'),'-s','tb_ap040_cache_snoop','-o',str(d/(name+'_spans.vvp')),str(d/'spans_tb.v'),str(cache),str(r/'rtl/ap68040/rtl/primitives/dpram.v')],stdout=f,stderr=subprocess.STDOUT,check=True)
 with (d/(name+'_spans.log')).open('w') as f:subprocess.run(['vvp',str(d/(name+'_spans.vvp'))],stdout=f,stderr=subprocess.STDOUT,check=True)
 log=(d/(name+'_spans.log')).read_text()
 print(name,'\n'.join(x for x in log.splitlines() if x.startswith(('SPAN','EXPLICIT','FAIL','ALL TESTS'))),flush=True)
 assert 'ALL TESTS PASSED' in log and 'FAIL' not in log and 'EXPLICIT_SPANS checks=15' in log
