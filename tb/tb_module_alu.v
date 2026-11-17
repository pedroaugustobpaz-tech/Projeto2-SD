`timescale 1ns/1ps
module tb_module_alu;
    reg  [2:0] opcode; reg [15:0] a, b; reg imm_sinal; reg [5:0] imm_mod;
    wire [15:0] result;
    integer erros = 0;
    module_alu dut (.opcode(opcode), .a(a), .b(b), .imm_sinal(imm_sinal), .imm_mod(imm_mod), .result(result));

    task teste(input [2:0] op, input [15:0] va, input [15:0] vb, input s, input [5:0] m, input [15:0] esp);
    begin
        opcode = op; a = va; b = vb; imm_sinal = s; imm_mod = m; #5;
        if (result === esp) $display("ok    op=%b a=%0d b=%0d imm=%s%0d -> %h", op, va, vb, s?"-":"+", m, result);
        else begin $display("ERRO  op=%b a=%0d b=%0d imm=%s%0d -> %h (esperado %h)", op, va, vb, s?"-":"+", m, result, esp); erros = erros + 1; end
    end endtask

    initial begin
        teste(3'b000, 16'd99,    16'd7,  0, 25, 16'd25);
        teste(3'b000, 16'd99,    16'd7,  1, 25, 16'hFFE7);
        teste(3'b001, 16'd10,    16'd5,  0, 0,  16'd15);
        teste(3'b001, 16'd32767, 16'd1,  0, 0,  16'h8000);
        teste(3'b011, 16'd5,     16'd10, 0, 0,  16'hFFFB);
        teste(3'b010, 16'd10,    16'd0,  1, 3,  16'd7);
        teste(3'b100, 16'd10,    16'd0,  1, 3,  16'd13);
        teste(3'b101, 16'd12,    16'd0,  1, 3,  16'hFFDC);
        teste(3'b101, 16'd1000,  16'd0,  0, 63, 16'hF618);
        teste(3'b110, 16'd55,    16'd66, 1, 9,  16'd0);
        teste(3'b111, 16'd1234,  16'd66, 1, 9,  16'd1234);
        $display("tb_module_alu: %0d erro(s)", erros); $finish;
    end
endmodule
