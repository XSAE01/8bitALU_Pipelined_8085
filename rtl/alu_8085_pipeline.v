// Accept one request per rising edge. A request captured at edge N
// produces registered outputs at edge N+1, unless reset flushes it.
module alu_8085_pipeline (
    input  wire       clk,
    input  wire       rst,
    input  wire       in_valid,
    input  wire [7:0] data_in_a,
    input  wire [7:0] data_in_b,
    input  wire [4:0] alu_op_in,
    output reg        out_valid,
    output reg  [7:0] acc_out,
    output reg  [4:0] flags_out,     // {S, Z, AC, P, CY}
    output wire [7:0] flag_reg_out,
    input  wire       use_acc        // 1 selects the last committed accumulator
);
    localparam [4:0] OP_CMP = 5'b00111;

    reg       execute_valid;
    reg       use_acc_reg;
    reg [7:0] a_reg, b_reg;
    reg [4:0] op_reg;
    wire [7:0] result;
    wire [4:0] next_flags;
    reg [7:0] operand_a;

    always @(*) begin
        operand_a = a_reg;
        if (use_acc_reg)
            operand_a = acc_out;
    end

    // When a new request enters execution, flags_out already holds the
    // flags committed by the preceding request on the same clock edge.
    alu_8bit alu (
        .a(operand_a), .b(b_reg), .alu_op(op_reg), .flags_in(flags_out),
        .result(result), .flag_s(next_flags[4]), .flag_z(next_flags[3]),
        .flag_ac(next_flags[2]), .flag_p(next_flags[1]), .flag_cy(next_flags[0])
    );

    always @(posedge clk) begin
        if (rst) begin
            execute_valid <= 1'b0;
            out_valid <= 1'b0;
            acc_out <= 8'h00;
            flags_out <= 5'b01010;
        end else begin
            execute_valid <= in_valid;
            if (in_valid) begin
                use_acc_reg <= use_acc;
                a_reg <= data_in_a;
                b_reg <= data_in_b;
                op_reg <= alu_op_in;
            end

            out_valid <= execute_valid;
            if (execute_valid) begin
                acc_out <= (op_reg == OP_CMP) ? operand_a : result;
                flags_out <= next_flags;
            end
        end
    end

    assign flag_reg_out = {flags_out[4:3], 1'b0, flags_out[2],
                           1'b0, flags_out[1], 1'b0, flags_out[0]};
endmodule
