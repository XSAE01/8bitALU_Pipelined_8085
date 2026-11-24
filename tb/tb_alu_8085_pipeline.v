`timescale 1ns/1ps

module tb_alu_8085_pipeline;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst, in_valid, use_acc;
    reg [7:0] data_in_a, data_in_b;
    reg [4:0] alu_op_in;
    wire out_valid;
    wire [7:0] acc_out, flag_reg_out;
    wire [4:0] flags_out;

    alu_8085_pipeline dut (
        .clk(clk), .rst(rst), .in_valid(in_valid), .use_acc(use_acc),
        .data_in_a(data_in_a), .data_in_b(data_in_b), .alu_op_in(alu_op_in),
        .out_valid(out_valid), .acc_out(acc_out), .flags_out(flags_out),
        .flag_reg_out(flag_reg_out)
    );

    `include "alu_ref_model.vh"

    reg pending, expected_valid;
    reg [7:0] pending_acc, expected_acc;
    reg [4:0] pending_flags, expected_flags;
    integer cycles = 0;
    integer i;

    task tick;
        input reset, valid, forward_acc;
        input [4:0] op;
        input [7:0] a, b;
        reg [7:0] operand_a;
        begin
            @(negedge clk);
            rst = reset;
            in_valid = valid;
            use_acc = forward_acc;
            alu_op_in = op;
            data_in_a = a;
            data_in_b = b;
            @(posedge clk);
            if (reset) begin
                expected_valid = 0;
                expected_acc = 0;
                expected_flags = 5'b01010;
                pending = 0;
            end else begin
                expected_valid = pending;
                if (pending) begin
                    expected_acc = pending_acc;
                    expected_flags = pending_flags;
                end
                pending = valid;
                if (valid) begin
                    operand_a = forward_acc ? expected_acc : a;
                    pending_acc = (op == 5'd7) ? operand_a : ref_result(operand_a, b, op, expected_flags);
                    pending_flags = ref_flags(operand_a, b, op, expected_flags);
                end
            end
            #1;
            cycles = cycles + 1;
            if ({out_valid, acc_out, flags_out} !== {expected_valid, expected_acc, expected_flags})
                $fatal(1, "cycle %0d: valid/A/flags %b/%h/%b, expected %b/%h/%b",
                       cycles, out_valid, acc_out, flags_out, expected_valid, expected_acc, expected_flags);
            if (flag_reg_out !== {expected_flags[4:3], 1'b0, expected_flags[2],
                                  1'b0, expected_flags[1], 1'b0, expected_flags[0]})
                $fatal(1, "cycle %0d: incorrect packed flags %h", cycles, flag_reg_out);
        end
    endtask

    initial begin
        tick(1, 1, 0, 0, 8'hff, 1);
        tick(0, 1, 0, 0, 8'hff, 1);   // ADD produces CY
        tick(0, 1, 0, 1, 0, 0);       // ADC consumes CY immediately
        tick(0, 1, 0, 0, 8'h08, 8'h08);
        tick(0, 1, 1, 17, 0, 0);      // DAA uses forwarded 10h and AC to produce 16h
        tick(0, 1, 1, 7, 8'hff, 8'h20); // CMP keeps forwarded 16h and sets CY
        tick(0, 0, 0, 0, 0, 0);
        tick(0, 1, 1, 1, 0, 1);       // after bubble: 16h + 1 + CY = 18h
        tick(0, 1, 0, 7, 8'h02, 3);   // CMP preserves this request's A
        tick(0, 0, 0, 13, 0, 0);      // bubble between CMP and SBB
        tick(0, 1, 0, 3, 8'h08, 0);
        tick(0, 1, 0, 18, 8'hff, 1);
        tick(0, 1, 0, 19, 0, 0);      // DADH uses DADL carry
        tick(0, 1, 0, 13, 0, 0);
        tick(1, 1, 0, 13, 0, 0);      // discard pending and incoming STC
        tick(0, 0, 0, 0, 0, 0);
        tick(0, 1, 1, 0, 8'hff, 1); // first forwarded request uses reset A = 0
        for (i = 0; i < 1024; i = i + 1)
            tick(0, 1, i[5] ^ i[0], i[4:0], $random, $random);
        tick(0, 0, 0, 0, 0, 0);       // drain last result
        tick(0, 0, 0, 0, 0, 0);
        $display("PASS: %0d cycles checked, including 1024 consecutive requests", cycles);
        $finish;
    end
endmodule
