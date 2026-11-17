`timescale 1ns/1ps
// Testbench do topo com TODOS os modulos reais. Os atrasos do LCD sao
// reduzidos com defparam, e um modelo simples do HD44780 reconstroi a tela
// para conferir o "Roteiro de teste na placa" (Roteiro 5), passos 1 a 19.
module tb_module_mini_cpu;
    reg clk = 0; always #10 clk = ~clk;   // 50 MHz
    reg [3:0] KEY = 4'b1111;
    reg [17:0] SW = 0;
    wire [7:0] LCD_DATA; wire LCD_RS, LCD_RW, LCD_EN, LCD_ON, LCD_BLON;
    integer erros = 0;

    module_mini_cpu dut (.CLOCK_50(clk), .KEY(KEY), .SW(SW), .LCD_DATA(LCD_DATA),
        .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN), .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON));

    defparam dut.u_lcd.DELAY_PULSE = 2;
    defparam dut.u_lcd.DELAY_WRITE = 5;
    defparam dut.u_lcd.u_init.DELAY_POWER = 20;
    defparam dut.u_lcd.u_init.DELAY_PULSE = 2;
    defparam dut.u_lcd.u_init.DELAY_CMD   = 5;

    // ---------- modelo do HD44780 ----------
    reg [7:0] tela [0:31];
    integer addr = 0, k;
    initial for (k = 0; k < 32; k = k + 1) tela[k] = " ";
    always @(negedge LCD_EN) begin
        if (LCD_RS == 0) begin
            if (LCD_DATA == 8'h01) begin
                for (k = 0; k < 32; k = k + 1) tela[k] = " ";
                addr = 0;
            end else if (LCD_DATA[7]) addr = (LCD_DATA[6:0] >= 7'h40) ? 16 + LCD_DATA[6:0] - 7'h40 : LCD_DATA[6:0];
        end else begin
            tela[addr] = LCD_DATA; addr = addr + 1;
        end
    end

    function [16*8-1:0] linha(input integer n);
        integer j; begin
            for (j = 0; j < 16; j = j + 1) linha[(15-j)*8 +: 8] = tela[n*16 + j];
        end
    endfunction

    // ---------- botoes ----------
    task soltar(input integer b);
    begin
        KEY[b] = 0; repeat (5) @(posedge clk);
        KEY[b] = 1; repeat (3000) @(posedge clk);   // tempo para desenhar a tela
    end endtask

    task passo(input integer n, input [17:0] sw, input integer botao,
               input [16*8-1:0] l1, input [16*8-1:0] l2);
    begin
        SW = sw; soltar(botao);
        if (linha(0) === l1 && linha(1) === l2)
            $display("ok    passo %2d |%s|%s|", n, linha(0), linha(1));
        else begin
            $display("ERRO  passo %2d |%s|%s|  esperado |%s|%s|", n, linha(0), linha(1), l1, l2);
            erros = erros + 1;
        end
    end endtask

    localparam BR = "                ";
    localparam IN1 = "----      [----]";
    localparam IN2 = "          +00000";

    initial begin
        KEY[0] = 0; repeat (5) @(posedge clk); KEY[0] = 1;
        repeat (500) @(posedge clk);                       // passo 1: gravar
        if (linha(0) === BR && linha(1) === BR) $display("ok    passo  1 (em branco)");
        else begin $display("ERRO  passo  1"); erros = erros + 1; end

        passo( 2, 18'b0,                           2, BR, BR);
        passo( 3, 18'b0,                           3, IN1, IN2);
        passo( 4, 18'b000_0010_0_001100_0000,      2, "LOAD      [0010]", "          +00012");
        passo( 5, 18'b001_0001_0000_0010_000,      2, "ADD       [0001]", "          +00012");
        passo( 6, 18'b010_0001_0000_0_001100,      2, "ADDI      [0001]", "          +00012");
        passo( 7, 18'b111_0010_0000_0000_000,      2, "DPL       [0010]", "          +00012");
        passo( 8, 18'b100_0011_0010_0_000101,      2, "SUBI      [0011]", "          +00007");
        passo( 9, 18'b011_0101_0011_0010_000,      2, "SUB       [0101]", "          -00005");
        passo(10, 18'b101_0100_0010_1_000011,      2, "MUL       [0100]", "          -00036");
        passo(11, 18'b000_1111_1_111111_0000,      2, "LOAD      [1111]", "          -00063");
        passo(12, 18'b101_0110_1111_0_111111,      2, "MUL       [0110]", "          -03969");
        passo(13, 18'b101_0111_0110_0_111111,      2, "MUL       [0111]", "          +12097");
        passo(14, 18'b110_0000_0000_0000_000,      2, "CLR             ", BR);
        passo(15, 18'b111_0010_0000_0000_000,      2, "DPL       [0010]", "          +00000");
        passo(16, 18'b000_0010_0_001100_0000,      2, "LOAD      [0010]", "          +00012");
        passo(17, 18'b0,                           3, BR, BR);
        passo(18, 18'b0,                           3, IN1, IN2);
        passo(19, 18'b111_0010_0000_0000_000,      2, "DPL       [0010]", "          +00000");

        // testes extras: mexer nos switches nao muda a tela; segurar nao executa
        SW = 18'b000_0011_0_000001_0000; repeat (2000) @(posedge clk);
        KEY[2] = 0; repeat (2000) @(posedge clk);
        if (linha(0) === "DPL       [0010]") $display("ok    extras (switches/segurar nao executam)");
        else begin $display("ERRO  extras"); erros = erros + 1; end
        KEY[2] = 1; repeat (3000) @(posedge clk);
        if (linha(0) === "LOAD      [0011]" && linha(1) === "          +00001") $display("ok    extra  (executa ao soltar)");
        else begin $display("ERRO  extra soltar |%s|%s|", linha(0), linha(1)); erros = erros + 1; end

        $display("tb_module_mini_cpu: %0d erro(s)", erros); $finish;
    end
endmodule
