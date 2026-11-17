`timescale 1ns/1ps
module tb_bin2bcd;
    reg [15:0] valor; wire negativo; wire [3:0] d4, d3, d2, d1, d0;
    integer erros = 0;
    bin2bcd dut (.valor(valor), .negativo(negativo), .d4(d4), .d3(d3), .d2(d2), .d1(d1), .d0(d0));

    task teste(input [15:0] v, input n, input [3:0] e4, e3, e2, e1, e0);
    begin
        valor = v; #5;
        if ({negativo,d4,d3,d2,d1,d0} === {n,e4,e3,e2,e1,e0})
            $display("ok    %h -> %s%0d%0d%0d%0d%0d", v, negativo?"-":"+", d4, d3, d2, d1, d0);
        else begin
            $display("ERRO  %h -> %s%0d%0d%0d%0d%0d", v, negativo?"-":"+", d4, d3, d2, d1, d0); erros = erros + 1;
        end
    end endtask

    initial begin
        teste(16'd0,     0, 0,0,0,0,0);
        teste(16'd12,    0, 0,0,0,1,2);
        teste(16'd9999,  0, 0,9,9,9,9);
        teste(16'd10000, 0, 1,0,0,0,0);
        teste(16'd32767, 0, 3,2,7,6,7);
        teste(16'hFFFF,  1, 0,0,0,0,1);
        teste(16'hFFFB,  1, 0,0,0,0,5);
        teste(16'h8000,  1, 3,2,7,6,8);
        $display("tb_bin2bcd: %0d erro(s)", erros); $finish;
    end
endmodule
