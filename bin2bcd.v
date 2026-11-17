// ============================================================================
// bin2bcd.v - Converte um valor de 16 bits em complemento a 2 para
// sinal (negativo) + cinco digitos decimais (d4 = dezena de milhar ... d0).
// Combinacional, algoritmo "deslocar e somar 3" (double dabble).
// ============================================================================
module bin2bcd (
    input  wire [15:0] valor,
    output wire        negativo,
    output wire [3:0]  d4,
    output wire [3:0]  d3,
    output wire [3:0]  d2,
    output wire [3:0]  d1,
    output wire [3:0]  d0
);

    // ---------- Etapa 04: sinal e modulo ----------
    assign negativo = valor[15];
    wire [15:0] modulo = negativo ? (~valor + 16'd1) : valor;

    // ---------- Etapa 05: double dabble ----------
    reg [35:0] shift;   // [35:16] cinco digitos BCD, [15:0] binario
    integer i;

    always @(*) begin
        shift = {20'd0, modulo};
        for (i = 0; i < 16; i = i + 1) begin
            if (shift[19:16] >= 4'd5) shift[19:16] = shift[19:16] + 4'd3;
            if (shift[23:20] >= 4'd5) shift[23:20] = shift[23:20] + 4'd3;
            if (shift[27:24] >= 4'd5) shift[27:24] = shift[27:24] + 4'd3;
            if (shift[31:28] >= 4'd5) shift[31:28] = shift[31:28] + 4'd3;
            if (shift[35:32] >= 4'd5) shift[35:32] = shift[35:32] + 4'd3;
            shift = shift << 1;
        end
    end

    assign d4 = shift[35:32];
    assign d3 = shift[31:28];
    assign d2 = shift[27:24];
    assign d1 = shift[23:20];
    assign d0 = shift[19:16];

endmodule
