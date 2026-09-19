// Experimental resident-instruction ID/EX/WB pipeline. Not in files.qip.
// Only Dn instructions are admitted. No memory, interrupts, or prediction.
`include "ap040_defs.svh"
module ap040_pipeline_integer #(parameter EXTERNAL_STATE = 0) (
    input wire clk, nreset, ce, flush,
    // Cancel ID/EX while allowing an accepting WB to commit. A blocked WB
    // is retained. Used when an interrupt is recognized at retirement.
    input wire kill_younger,
    output wire idle,
    // EXTERNAL_STATE uses the owner's one architectural register file and CCR.
    input wire [31:0] external_a, external_b,
    input wire [4:0] external_ccr,
    output wire [2:0] read_src, read_dst,
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
    output wire [2:0] retire_dst,
    output wire [31:0] retire_data,
    output wire [4:0] retire_ccr,
    output wire fallback_valid,
    output wire [31:0] fallback_pc,
    output wire [15:0] fallback_opcode
);
    // Admission is also exposed before accepting a word. Exhaustively tested
    // against the independent opcode map alongside the ID decoder below.
    assign in_supported = in_opcode == 16'h4e71 ||
        (in_opcode & 16'hf100) == 16'h7000 ||
        ((in_opcode & 16'hc1f8) == 0 && in_opcode[13:12] != 0) ||
        (in_opcode[5:3] == 0 && in_opcode[7:6] != 3 &&
         ((!in_opcode[8] && (in_opcode[15:12] == 4'hd ||
           in_opcode[15:12] == 4'h9 || in_opcode[15:12] == 4'hb ||
           in_opcode[15:12] == 4'hc || in_opcode[15:12] == 4'h8)) ||
          (in_opcode[8] && in_opcode[15:12] == 4'hb)));
    reg id_v, ex_v, wb_v;
    reg [31:0] id_pc, ex_pc, wb_pc;
    reg [15:0] id_opcode, ex_opcode, wb_opcode;
    reg [5:0] ex_op;
    reg [1:0] ex_size;
    reg [2:0] ex_src, ex_dst, wb_dst;
    reg ex_imm, ex_we, ex_flags, wb_we;
    reg [31:0] ex_immediate, wb_data;
    reg [4:0] ccr, wb_ccr;

    reg legal, dec_imm, dec_we, dec_flags;
    reg [5:0] dec_op;
    reg [1:0] dec_size;
    reg [2:0] dec_src, dec_dst;
    reg [31:0] dec_immediate;
    always @* begin
        legal = 0; dec_imm = 0; dec_we = 1; dec_flags = 1;
        dec_op = `AP040_ALU_MOVE; dec_size = `AP040_SZ_L;
        dec_src = id_opcode[2:0]; dec_dst = id_opcode[11:9];
        dec_immediate = {{24{id_opcode[7]}}, id_opcode[7:0]};
        if (id_opcode == 16'h4e71) begin
            legal = 1; dec_we = 0; dec_flags = 0;
        end else if ((id_opcode & 16'hf100) == 16'h7000) begin
            legal = 1; dec_imm = 1;
        end else if ((id_opcode & 16'hc1f8) == 16'h0000 &&
                     id_opcode[13:12] != 0) begin
            // MOVE.B/W/L Dn,Dn (both EA modes must be register direct).
            legal = 1;
            case (id_opcode[13:12])
                1: dec_size = `AP040_SZ_B;
                2: dec_size = `AP040_SZ_L;
                3: dec_size = `AP040_SZ_W;
            endcase
        end else if (id_opcode[5:3] == 0 && id_opcode[7:6] != 3) begin
            dec_size = id_opcode[7:6];
            // Ordinary <ea>,Dn direction; exclude ADDA/SUBA/CMPA and X forms.
            if (!id_opcode[8]) begin
                case (id_opcode[15:12])
                    4'hd: begin legal = 1; dec_op = `AP040_ALU_ADD; end
                    4'h9: begin legal = 1; dec_op = `AP040_ALU_SUB; end
                    4'hb: begin legal = 1; dec_op = `AP040_ALU_CMP; dec_we = 0; end
                    4'hc: begin legal = 1; dec_op = `AP040_ALU_AND; end
                    4'h8: begin legal = 1; dec_op = `AP040_ALU_OR; end
                    default: begin end
                endcase
            end else if (id_opcode[15:12] == 4'hb) begin
                legal = 1; dec_op = `AP040_ALU_EOR;
                dec_src = id_opcode[11:9]; dec_dst = id_opcode[2:0];
            end
        end
    end

    wire wb_ready = !wb_v || retire_ready;
    wire ex_ready = !ex_v || wb_ready;
    wire id_advance = id_v && legal && ex_ready;
    assign idle = !id_v && !ex_v && !wb_v;
    assign in_ready = nreset && ce && !flush && !kill_younger && (!id_v || id_advance);
    assign retire_valid = nreset && ce && !flush && wb_v;
    wire commit = retire_valid && retire_ready;
    assign retire_pc = wb_pc;
    assign retire_opcode = wb_opcode;
    assign retire_we = wb_we;
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
        .we(commit && wb_we), .waddr({1'b0, wb_dst}), .wdata(wb_data),
        .raddr_a({1'b0, ex_src}), .raddr_b({1'b0, ex_dst}),
        .rdata_a(rf_a), .rdata_b(rf_b),
        .aux_we(1'b0), .aux_sel(2'd0), .aux_wdata(32'd0),
        .usp_q(), .isp_q(), .msp_q(), .dbg_d0(), .dbg_d1(), .dbg_d2(), .dbg_a0(), .dbg_a7()
    );
    end endgenerate
    // EX reads late, forwarding the immediately older WB value, including
    // the upper bytes needed for partial-register writes. The existing RF
    // handles its own delayed MLAB write beneath this bypass.
    wire [31:0] src = ex_imm ? ex_immediate :
        (wb_v && wb_we && wb_dst == ex_src) ? wb_data : rf_a;
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
    always @(posedge clk) begin
        if (!nreset) begin
            id_v <= 0; ex_v <= 0; wb_v <= 0; ccr <= 0;
            id_pc <= 0; ex_pc <= 0; wb_pc <= 0;
            id_opcode <= 0; ex_opcode <= 0; wb_opcode <= 0;
            ex_op <= 0; ex_size <= 0; ex_src <= 0; ex_dst <= 0;
            ex_imm <= 0; ex_we <= 0; ex_flags <= 0; ex_immediate <= 0;
            wb_dst <= 0; wb_we <= 0; wb_data <= 0; wb_ccr <= 0;
        end else if (ce) begin
            if (flush) begin
                id_v <= 0; ex_v <= 0; wb_v <= 0;
            end else begin
                if (commit) ccr <= wb_ccr;
                if (kill_younger) begin
                    id_v <= 0; ex_v <= 0;
                    if (wb_ready) wb_v <= 0;
                end else begin
                if (wb_ready) begin
                    wb_v <= ex_v;
                    if (ex_v) begin
                        wb_pc <= ex_pc; wb_opcode <= ex_opcode;
                        wb_dst <= ex_dst; wb_we <= ex_we; wb_data <= merged;
                        wb_ccr <= ex_flags ? alu_flags : flags_in;
                    end
                end
                if (ex_ready) begin
                    ex_v <= id_v && legal;
                    if (id_v && legal) begin
                        ex_pc <= id_pc; ex_opcode <= id_opcode;
                        ex_op <= dec_op; ex_size <= dec_size;
                        ex_src <= dec_src; ex_dst <= dec_dst;
                        ex_imm <= dec_imm; ex_immediate <= dec_immediate;
                        ex_we <= dec_we; ex_flags <= dec_flags;
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
