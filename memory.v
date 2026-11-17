// ============================================================================
// memory.v - Banco de registradores / memoria de dados da Mini_CPU
// RAM de 16 x 16 bits (R0..R15), duas portas de leitura e uma de escrita.
//  - Leitura sincrona: data_a/data_b ficam validos 1 ciclo depois do endereco.
//  - Escrita sincrona: com we = 1, mem[addr_w] <= data_in na borda de subida.
//  - clr (ou rst) zera os 16 registradores.
// ============================================================================
module memory (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,        // habilita escrita
    input  wire        clr,       // zera todos os registradores
    input  wire [3:0]  addr_a,    // endereco de leitura A (Src1)
    input  wire [3:0]  addr_b,    // endereco de leitura B (Src2)
    input  wire [3:0]  addr_w,    // endereco de escrita (Dest)
    input  wire [15:0] data_in,   // dado a ser escrito
    output reg  [15:0] data_a,    // conteudo de addr_a
    output reg  [15:0] data_b     // conteudo de addr_b
);

    reg [15:0] mem [0:15];
    integer i;

    always @(posedge clk) begin
        if (rst || clr) begin
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 16'd0;
            data_a <= 16'd0;
            data_b <= 16'd0;
        end else begin
            if (we)
                mem[addr_w] <= data_in;
            data_a <= mem[addr_a];
            data_b <= mem[addr_b];
        end
    end

endmodule
