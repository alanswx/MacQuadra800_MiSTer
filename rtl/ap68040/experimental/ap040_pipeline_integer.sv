// Experimental resident-instruction ID/EX/WB pipeline. Not in files.qip.
// Optional head-ordered (An) loads use the owner's memory/exception sequencer.
`include "ap040_defs.svh"
module ap040_pipeline_integer #(parameter EXTERNAL_STATE = 0, parameter ENABLE_LOADS = 0) (
    input wire clk, nreset, ce, flush,
    // Cancel ID/EX while allowing an accepting WB to commit. A blocked WB
    // is retained. Used when an interrupt is recognized at retirement.
    input wire kill_younger,
    output wire idle,
    // EXTERNAL_STATE uses the owner's one architectural register file and CCR.
    input wire [31:0] external_a, external_b,
    input wire [4:0] external_ccr,
    output wire [3:0] read_src, read_dst,
    output wire in_supported,
    input wire in_valid,
    output wire in_ready,
    input wire [31:0] in_pc,
    input wire [15:0] in_opcode,
    input wire retire_ready,
    output wire retire_valid,
    output wire [31:0] retire_pc,
    output wire [15:0] retire_opcode,
    output wire retire_we,
    output wire [3:0] retire_dst,
    output wire [31:0] retire_data,
    output wire [4:0] retire_ccr,
    // One head-ordered read, stable until acknowledgement. Responses are
    // accepted even while architectural CE is paused; cancellation drains
    // an already-issued read without architectural effects.
    output wire load_req,
    output wire [31:0] load_addr,
    output wire [1:0] load_size,
    output wire [31:0] load_pc,
    output wire [15:0] load_opcode,
    input wire load_ack, load_fault,
    input wire [31:0] load_data,
    output wire retire_fault,
    output wire [31:0] retire_fault_addr,
    output wire fallback_valid,
    output wire [31:0] fallback_pc,
    output wire [15:0] fallback_opcode
);
    reg id_v, ex_v, wb_v;
    reg ex_load, wb_fault;
    reg [31:0] wb_fault_addr;
    reg load_pending, load_done, load_discard, load_error;
    reg [31:0] load_addr_r, load_value, load_pc_r;
    reg [15:0] load_opcode_r;
    reg [1:0] load_size_r;
    wire load_issue;
    assign load_req = load_pending;
    assign load_addr = load_addr_r;
    assign load_size = load_size_r;
    assign load_pc = load_pc_r;
    assign load_opcode = load_opcode_r;
    assign retire_fault = wb_fault;
    assign retire_fault_addr = wb_fault_addr;
    function automatic is_load(input [15:0] word);
        is_load = ENABLE_LOADS && word[15:14] == 0 && word[13:12] != 0 &&
                  word[8:6] == 0 && word[5:3] == 3'b010;
    endfunction
    reg [31:0] id_pc, ex_pc, wb_pc;
    reg [15:0] id_opcode, ex_opcode, wb_opcode;
    reg [5:0] ex_op;
    reg [1:0] ex_size;
    reg [3:0] ex_src, ex_dst, wb_dst;
    reg ex_imm, ex_we, ex_flags, ex_word_src, wb_we;
    reg [31:0] ex_immediate, wb_data;
    reg [4:0] ccr, wb_ccr;

    // One decode function serves admission and ID. The testbench checks all
    // 65,536 words against a map generated independently from semantic cases.
    function automatic [52:0] decode;
        input [15:0] word;
        reg legal, immediate, writeback, flags, word_src;
        reg [5:0] operation;
        reg [1:0] size;
        reg [3:0] source, destination;
        reg [31:0] literal;
        begin
            legal = 0; immediate = 0; writeback = 1; flags = 1; word_src = 0;
            operation = `AP040_ALU_MOVE; size = `AP040_SZ_L;
            source = {1'b0, word[2:0]}; destination = {1'b0, word[11:9]};
            literal = {{24{word[7]}}, word[7:0]};
            if (is_load(word)) begin
                legal = 1;
                source = {1'b1, word[2:0]};
                destination = {1'b0, word[11:9]};
                size = word[13:12] == 1 ? `AP040_SZ_B :
                       word[13:12] == 2 ? `AP040_SZ_L : `AP040_SZ_W;
            end else if (word == 16'h4e71) begin
                legal = 1; writeback = 0; flags = 0;
            end else if ((word & 16'hf100) == 16'h7000) begin
                legal = 1; immediate = 1;
            end else if (word[15:14] == 0 && word[13:12] != 0 &&
                         word[8:7] == 0 && word[5:4] == 0 &&
                         !(word[13:12] == 1 && (word[6] || word[3]))) begin
                legal = 1;
                source = {word[3], word[2:0]};
                destination = {word[6], word[11:9]};
                size = word[13:12] == 1 ? `AP040_SZ_B :
                       word[13:12] == 2 ? `AP040_SZ_L : `AP040_SZ_W;
                if (word[6]) begin
                    // MOVEA.W sign-extends before its full-width write.
                    word_src = size == `AP040_SZ_W;
                    size = `AP040_SZ_L; flags = 0;
                end
            end else if (word[15:12] == 5 && word[7:6] != 3 &&
                         word[5:4] == 0 && !(word[7:6] == 0 && word[3])) begin
                legal = 1; immediate = 1;
                literal = word[11:9] == 0 ? 32'd8 : {29'd0, word[11:9]};
                destination = {word[3], word[2:0]};
                operation = word[8] ? `AP040_ALU_SUB : `AP040_ALU_ADD;
                size = word[3] ? `AP040_SZ_L : word[7:6];
                flags = !word[3];
            end else if (word[5:4] == 0 &&
                         (word[15:12] == 9 || word[15:12] == 11 || word[15:12] == 13)) begin
                source = {word[3], word[2:0]};
                operation = word[15:12] == 9 ? `AP040_ALU_SUB :
                            word[15:12] == 13 ? `AP040_ALU_ADD : `AP040_ALU_CMP;
                writeback = word[15:12] != 11;
                if (word[7:6] == 3) begin
                    legal = 1; destination[3] = 1;
                    word_src = !word[8]; size = `AP040_SZ_L;
                    flags = word[15:12] == 11;
                end else if (!word[8] && !(word[7:6] == 0 && word[3])) begin
                    legal = 1; size = word[7:6];
                end else if (word[15:12] == 11 && word[8] && !word[3]) begin
                    legal = 1; size = word[7:6]; writeback = 1;
                    operation = `AP040_ALU_EOR;
                    source = {1'b0, word[11:9]}; destination = {1'b0, word[2:0]};
                end
            end else if (word[5:3] == 0 && word[7:6] != 3 && !word[8] &&
                         (word[15:12] == 8 || word[15:12] == 12)) begin
                legal = 1; size = word[7:6];
                operation = word[15:12] == 8 ? `AP040_ALU_OR : `AP040_ALU_AND;
            end
            decode = {legal, immediate, writeback, flags, word_src, operation,
                      size, source, destination, literal};
        end
    endfunction
    wire legal, dec_imm, dec_we, dec_flags, dec_word_src;
    wire [5:0] dec_op;
    wire [1:0] dec_size;
    wire [3:0] dec_src, dec_dst;
    wire [31:0] dec_immediate;
    wire [52:0] admission = decode(in_opcode);
    assign in_supported = admission[52];
    assign {legal, dec_imm, dec_we, dec_flags, dec_word_src, dec_op,
            dec_size, dec_src, dec_dst, dec_immediate} = decode(id_opcode);

    wire wb_ready = !wb_v || (retire_ready && !wb_fault);
    wire load_response = load_pending && load_ack && !load_discard && !flush && !kill_younger;
    wire ex_complete = !ex_load || load_done || load_response;
    wire ex_ready = !ex_v || (wb_ready && ex_complete);
    wire id_advance = id_v && legal && ex_ready;
    assign idle = !id_v && !ex_v && !wb_v && !load_pending;
    assign in_ready = nreset && ce && !flush && !kill_younger && !load_discard && (!id_v || id_advance);
    assign retire_valid = nreset && ce && !flush && wb_v;
    wire commit = retire_valid && retire_ready;
    assign retire_pc = wb_pc;
    assign retire_opcode = wb_opcode;
    assign retire_we = wb_we && !wb_fault;
    assign retire_dst = wb_dst;
    assign retire_data = wb_data;
    assign retire_ccr = wb_ccr;
    assign fallback_valid = nreset && ce && !flush && id_v && !legal && !ex_v && !wb_v;
    assign fallback_pc = id_pc;
    assign fallback_opcode = id_opcode;

    wire [31:0] rf_a, rf_b;
    assign read_src = ex_src;
    assign read_dst = ex_dst;
    generate if (EXTERNAL_STATE) begin : shared_state
        assign rf_a = external_a;
        assign rf_b = external_b;
    end else begin : private_state
    ap040_regfile regfile (
        .clk(clk), .nreset(nreset), .ce(ce), .sr_s(1'b1), .sr_m(1'b0),
        .we(commit && wb_we && !wb_fault), .waddr(wb_dst), .wdata(wb_data),
        .raddr_a(ex_src), .raddr_b(ex_dst),
        .rdata_a(rf_a), .rdata_b(rf_b),
        .aux_we(1'b0), .aux_sel(2'd0), .aux_wdata(32'd0),
        .usp_q(), .isp_q(), .msp_q(), .dbg_d0(), .dbg_d1(), .dbg_d2(), .dbg_a0(), .dbg_a7()
    );
    end endgenerate
    // EX reads late, forwarding the immediately older WB value, including
    // the upper bytes needed for partial-register writes. The existing RF
    // handles its own delayed MLAB write beneath this bypass.
    wire [31:0] source_full = ex_imm ? ex_immediate :
        (wb_v && wb_we && wb_dst == ex_src) ? wb_data : rf_a;
    wire [31:0] src = ex_load ? (load_done ? load_value : load_data) : ex_word_src ? {{16{source_full[15]}}, source_full[15:0]} : source_full;
    wire [31:0] dst = (wb_v && wb_we && wb_dst == ex_dst) ? wb_data : rf_b;
    wire [4:0] flags_in = wb_v ? wb_ccr : (EXTERNAL_STATE ? external_ccr : ccr);
    wire [31:0] alu_result;
    wire [4:0] alu_flags;
    ap040_alu alu (
        .op(ex_op), .size(ex_size), .shcnt(6'd0), .a(src), .b(dst),
        .flags_in(flags_in), .result(alu_result), .flags_out(alu_flags),
        .fast_flags(), .fast_ok()
    );
    wire [31:0] merged = ex_size == `AP040_SZ_B ? {dst[31:8], alu_result[7:0]} :
                         ex_size == `AP040_SZ_W ? {dst[31:16], alu_result[15:0]} : alu_result;
    assign load_issue = ENABLE_LOADS && nreset && ce && !flush && !kill_younger &&
        ex_v && ex_load && !wb_v && !load_pending && !load_done && !load_discard;
    always @(posedge clk) begin
        if (!nreset) begin
            load_pending <= 0; load_done <= 0; load_discard <= 0;
            load_error <= 0; load_addr_r <= 0; load_size_r <= 0; load_value <= 0;
            load_pc_r <= 0; load_opcode_r <= 0;
        end else begin
            if (ce && ex_v && ex_load && ex_complete && wb_ready)
                load_done <= 0;
            if (load_issue) begin
                load_pending <= 1; load_addr_r <= source_full;
                load_size_r <= ex_size; load_discard <= 0;
                load_pc_r <= ex_pc; load_opcode_r <= ex_opcode;
            end
            if (ce && (flush || kill_younger)) begin
                load_done <= 0;
                if (load_pending) load_discard <= 1;
            end
            if (load_pending && load_ack) begin
                load_pending <= 0;
                load_discard <= 0;
                if (load_discard || (ce && (flush || kill_younger)))
                    load_done <= 0;
                else begin
                    // Forward a response directly into WB when EX can advance;
                    // otherwise retain it, including throughout a CE pause.
                    load_done <= !(ce && ex_v && ex_load && wb_ready);
                    load_value <= load_data; load_error <= load_fault;
                end
            end
        end
    end
    always @(posedge clk) begin
        if (!nreset) begin
            id_v <= 0; ex_v <= 0; wb_v <= 0; ccr <= 0;
            ex_load <= 0; wb_fault <= 0; wb_fault_addr <= 0;
            id_pc <= 0; ex_pc <= 0; wb_pc <= 0;
            id_opcode <= 0; ex_opcode <= 0; wb_opcode <= 0;
            ex_op <= 0; ex_size <= 0; ex_src <= 0; ex_dst <= 0;
            ex_word_src <= 0; ex_imm <= 0; ex_we <= 0; ex_flags <= 0; ex_immediate <= 0;
            wb_dst <= 0; wb_we <= 0; wb_data <= 0; wb_ccr <= 0;
        end else if (ce) begin
            if (flush) begin
                id_v <= 0; ex_v <= 0; wb_v <= 0;
            end else begin
                if (commit && !wb_fault) ccr <= wb_ccr;
                if (kill_younger) begin
                    id_v <= 0; ex_v <= 0;
                    if (commit || wb_ready) wb_v <= 0;
                end else begin
                if (wb_ready) begin
                    wb_v <= ex_v && ex_complete;
                    if (ex_v && ex_complete) begin
                        wb_pc <= ex_pc; wb_opcode <= ex_opcode;
                        wb_fault <= ex_load && (load_done ? load_error : load_fault);
                        wb_fault_addr <= load_addr_r;
                        wb_dst <= ex_dst; wb_we <= ex_we; wb_data <= merged;
                        wb_ccr <= ex_flags ? alu_flags : flags_in;
                    end
                end
                if (ex_ready) begin
                    ex_v <= id_v && legal;
                    if (id_v && legal) begin
                        ex_pc <= id_pc; ex_opcode <= id_opcode;
                        ex_load <= is_load(id_opcode);
                        ex_op <= dec_op; ex_size <= dec_size;
                        ex_src <= dec_src; ex_dst <= dec_dst;
                        ex_imm <= dec_imm; ex_immediate <= dec_immediate;
                        ex_we <= dec_we; ex_flags <= dec_flags; ex_word_src <= dec_word_src;
                    end
                end
                if (in_ready) begin
                    id_v <= in_valid;
                    if (in_valid) begin id_pc <= in_pc; id_opcode <= in_opcode; end
                end
                end
            end
        end
    end
endmodule
