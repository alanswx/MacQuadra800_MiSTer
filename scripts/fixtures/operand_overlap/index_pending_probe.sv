// Simulation-only, architecturally neutral pending-write injection. Exercise
// the guarded old EXTW path with a no-op A0 write and a no-op ISP aux write.
// No force touches the CPU in ordinary regression runs.
module index_pending_probe;
`define C tb_ap040_program.dut.core
integer injected=0,waiting=0,checked=0;
reg [31:0] preserved_value;
reg enabled=0;
initial enabled=$test$plusargs("index_pending");
always @(negedge tb_ap040_program.clk) if(enabled) begin
 if(waiting==0 && injected<2 && tb_ap040_program.nreset && `C.ce &&
    `C.state==8 && `C.r_imm_ret==14 && `C.imm_n==1 &&
    (`C.epf_ready_pc || `C.epf_fwd_pc) && !`C.rf_we && !`C.aux_we) begin
  if(injected==0) begin
   preserved_value=`C.regfile.areg[0];
   force `C.rf_we=1;force `C.rf_waddr=8;force `C.rf_wdata=preserved_value;
  end else begin
   preserved_value=`C.regfile.isp;
   force `C.aux_we=1;force `C.aux_sel=1;force `C.aux_wdata=preserved_value;
  end
  injected=injected+1;waiting=1;
 end else if(waiting==2) begin
  if(injected==1) begin release `C.rf_we;release `C.rf_waddr;release `C.rf_wdata;end
  else begin release `C.aux_we;release `C.aux_sel;release `C.aux_wdata;end
  waiting=0;
 end
end
always @(posedge tb_ap040_program.clk) if(enabled && waiting==1) begin
 #1;
 if(`C.state!==8'd14) $fatal(1,"INDEX_PENDING_FAIL kind=%0d state=%0d",injected,`C.state);
 checked=checked+1;waiting=2;
 $display("INDEX_PENDING_PASS kind=%0d pc=%h",injected,`C.pc_i);
end
final if(enabled && checked!=2) $error("INDEX_PENDING_MISSING checked=%0d",checked);
`undef C
endmodule
