// Additional simulation root for the real core's opt-in P1 integration.
`timescale 1ns/1ps
`define C tb_ap040_program.dut.core
module handoff_monitor;
    integer entries = 0, commits = 0, paused = 0;
    always @(posedge tb_ap040_program.clk) begin
        if (tb_ap040_program.nreset) begin
            if (`C.pipe_owner && (`C.rf_we || `C.aux_we))
                $fatal(1, "sequencer write during pipeline ownership");
            if (`C.pipe_retire && !`C.pipe_owner)
                $fatal(1, "pipeline retirement without ownership");
            if (`C.integer_pipeline.fallback_valid)
                $fatal(1, "unsupported opcode admitted to P1");
            if (`C.pipe_owner && !`C.ce) paused = paused + 1;
            if (`C.ce) begin
                if (`C.pipe_input && `C.pipe_ready) entries = entries + 1;
                if (`C.pipe_retire) begin
                    commits = commits + 1;
                    if (`C.pipe_pc !== `C.pc_i || `C.pipe_opcode !== `C.ir)
                        $fatal(1, "pipeline instruction identity changed");
                end
            end
        end
    end
    final $display("HANDOFF entries=%0d commits=%0d paused=%0d", entries, commits, paused);
endmodule
`undef C
