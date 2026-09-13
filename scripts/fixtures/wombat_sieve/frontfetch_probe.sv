// Partial diagnostic only: stop before CMP #100,D6 after the FIRST original
// outer pass (D6=1). Does not replace the full 100-pass correctness fixture.
module frontfetch_probe;
`define P tb_ap040_program
`define C tb_ap040_program.dut.core
`define K tb_ap040_program.dut.g_cache.cache
integer f[0:40][0:6];
integer im[0:40], disp[0:40], seed[0:40];
integer starts[0:255], fh_from[0:40];
integer states[0:255];
integer ih=0, ip=0, miss=0, killed=0, requests=0;
integer a,b,slot,category,elapsed=0,pre_state;
reg pre_pend, pre_active;
reg [31:0] pre_pc_i;
reg [31:0] last_dispatch=32'hffffffff;
reg active=0;
reg enabled=0;
integer kernel_pc='h2000;
integer check_addr, check_got, check_wanted;
// The preceding ADDQ D6 can be retiring on this opcode-dispatch edge.
wire [31:0] effective_d6 = (`C.rf_we && `C.rf_waddr==4'd6) ?
                          `C.rf_wdata : `C.regfile.dreg[6];

function integer pcslot(input [31:0] pc);
    if (pc >= kernel_pc && pc < kernel_pc+80) pcslot=(pc-kernel_pc)/2;
    else pcslot=40;
endfunction

initial begin
    enabled=$test$plusargs("fetchprobe");
    if($value$plusargs("kernelpc=%h",kernel_pc)) begin end
    for(a=0;a<41;a=a+1) begin
        im[a]=0; disp[a]=0; seed[a]=0; fh_from[a]=0;
        for(b=0;b<7;b=b+1) f[a][b]=0;
    end
    for(a=0;a<256;a=a+1) begin starts[a]=0; states[a]=0; end
end

always @(posedge `P.clk) if(enabled && `P.nreset) begin
    pre_state=`C.state; pre_pend=`C.epf_pend;
    pre_active=active; pre_pc_i=`C.pc_i;
    if(active) begin
        elapsed=elapsed+1;
        states[pre_state]=states[pre_state]+1;
        if(pre_state==3) begin
            slot=pcslot(`C.pc);
            if(`C.epf_fwd_pc) category=1;
            else if(`C.epf_ready_pc) category=0;
            else if(`C.epf_pend && `C.epf_kill) category=3;
            else if(`C.epf_pend) category=2;
            else if(!`C.epf_armed || `C.epf_next!=`C.pc || `C.epf_super!=`C.sr_s) category=4;
            else if(`C.mem_req || `C.mem_ack) category=5;
            else category=6;
            f[slot][category]=f[slot][category]+1;
            if(`C.epf_brf) seed[slot]=seed[slot]+1;
        end
        if(pre_state==8) begin
            slot=pcslot(`C.pc_i); im[slot]=im[slot]+1;
        end
        if(`K.ce && `K.ipred_hit) ip=ip+1;
        if(`K.ce && `K.cst==1 && `K.r_bank) begin
            if(`K.look_hit) ih=ih+1;
            else miss=miss+1;
        end
        if(`C.ce && `C.epf_pend && `C.i_ack && `C.epf_kill) killed=killed+1;
    end
    #1;
    if(!active && `C.state==4 && `C.pc_i==kernel_pc) active=1;
    if(active) begin
        // This particular kernel has no consecutive same-PC dispatches.
        // PC_i is assigned before fetch completes, so exclude S_FETCH.
        if(`C.state!=3 && `C.pc_i!=last_dispatch) begin
            slot=pcslot(`C.pc_i); disp[slot]=disp[slot]+1;
            last_dispatch=`C.pc_i;
        end
        if(pre_active && !pre_pend && `C.epf_pend) begin
            starts[pre_state]=starts[pre_state]+1; requests=requests+1;
        end
        if(pre_active && pre_state!=3 && `C.state==3) begin
            slot=pcslot(pre_pc_i); fh_from[slot]=fh_from[slot]+1;
        end
        if(`C.state==4 && `C.pc_i==kernel_pc+74 && effective_d6==1) begin
            if(`C.regfile.dreg[7] !== `P.sieve_monitor.expected_count ||
               `C.regfile.areg[2] !== 32'h4000)
                $fatal(1,"ALIGN_FAIL register/oracle mismatch");
            for(check_addr='h3fe0;check_addr<'h6020;check_addr=check_addr+1) begin
                check_got=`P.sieve_monitor.memory_byte(check_addr);
                if(check_addr>='h4000 && check_addr<='h5ffe)
                    check_wanted=`P.sieve_monitor.expected[check_addr-'h4000] ? 1 : 0;
                else check_wanted=check_addr[0] ? 'h5a : 'ha5;
                if(check_got !== check_wanted)
                    $fatal(1,"ALIGN_FAIL addr=%h got=%h expected=%h",check_addr,check_got,check_wanted);
            end
            $display("FETCH_PROBE_COMPLETE kind=partial_first_outer_pass kernelpc=%04x array=PASS guards=PASS cycles=%0d D6=%0d D7=%0d requests=%0d ihit=%0d ipred=%0d imiss=%0d killed_ack=%0d",
                kernel_pc,elapsed,effective_d6,`C.regfile.dreg[7],requests,ih,ip,miss,killed);
            for(a=0;a<41;a=a+1)
                if(disp[a] || im[a] || fh_from[a] || f[a][0]+f[a][1]+f[a][2]+f[a][3]+f[a][4]+f[a][5]+f[a][6])
                    $display("FETCH_PC pc=%04x dispatch=%0d from_fetch=%0d im_cycles=%0d ready=%0d fwd=%0d pending=%0d killed=%0d rearm=%0d port_gap=%0d other=%0d brf=%0d",
                        kernel_pc+2*a,disp[a],fh_from[a],im[a],f[a][0],f[a][1],f[a][2],f[a][3],f[a][4],f[a][5],f[a][6],seed[a]);
            for(a=0;a<256;a=a+1)
                if(states[a] || starts[a]) $display("FETCH_STATE state=%0d cycles=%0d request_starts=%0d",a,states[a],starts[a]);
            $finish;
        end
    end
end
`undef P
`undef C
`undef K
endmodule
