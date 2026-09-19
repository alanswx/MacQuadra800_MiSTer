// Extra simulation root alongside the existing, unchanged CPU program bench.
// This is deliberately limited to the straight-line, register-only payload.
// fetch_next/retire_req is not a general retirement interface for branches,
// exceptions, or multi-write instructions.
`timescale 1ns/1ps
`define CORE tb_ap040_program.dut.core
module reference_trace;
    integer fd, count, i, seen = 0;
    reg [1023:0] path;
    reg [31:0] pc_before;
    reg [15:0] opcode_before;
    reg ce_before;
    reg [31:0] value;
    initial begin
        if (!$value$plusargs("trace=%s", path) || !$value$plusargs("count=%d", count))
            $fatal(1, "missing reference arguments");
        fd = $fopen(path, "w");
        if (!fd) $fatal(1, "cannot open reference trace");
    end
    always @(posedge tb_ap040_program.clk) begin
        pc_before = `CORE.pc_i;
        opcode_before = `CORE.ir;
        ce_before = `CORE.ce;
        #1;
        if (tb_ap040_program.nreset && ce_before && `CORE.retire_req &&
            pc_before >= 32'h400 && pc_before < 32'h400 + 2*count) begin
            $fwrite(fd, "%08x %04x %02x", pc_before, opcode_before, `CORE.sr[4:0]);
            for (i = 0; i < 8; i = i + 1) begin
                // Match the architectural pending-write order of the MLAB RF.
                value = `CORE.regfile.rf_written[i] ? `CORE.regfile.bank_a[i] : 0;
                if (`CORE.regfile.pend_we && `CORE.regfile.pend_waddr == i)
                    value = `CORE.regfile.pend_wdata;
                if (`CORE.rf_we && `CORE.rf_waddr == i) value = `CORE.rf_wdata;
                $fwrite(fd, " %08x", value);
            end
            $fwrite(fd, "\n");
            seen = seen + 1;
            if (seen == count) begin $fclose(fd); $display("REFERENCE TRACE COMPLETE %0d", seen); end
            if (seen > count) $fatal(1, "duplicate reference retirement");
        end
    end
endmodule
`undef CORE
