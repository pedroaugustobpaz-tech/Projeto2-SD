// ============================================================================
// module_alu.v - Unidade Logica e Aritmetica da Mini_CPU (combinacional)
// O imediato chega em sinal e modulo (imm_sinal, imm_mod) e e convertido
// para complemento a 2 de 16 bits. O estouro e descartado (16 bits baixos).
// ============================================================================
module module_alu (
    input  wire [2:0]  opcode,
    input  wire [15:0] a,          // valor do registrador Src1 (data_a)
    input  wire [15:0] b,          // valor do registrador Src2 (data_b)
    input  wire        imm_sinal,  // 1 = imediato negativo
    input  wire [5:0]  imm_mod,    // modulo do imediato
    output reg  [15:0] result
);

    // ---------------- Opcodes ----------------
    localparam OP_LOAD    = 3'b000;
    localparam OP_ADD     = 3'b001;
    localparam OP_ADDI    = 3'b010;
    localparam OP_SUB     = 3'b011;
    localparam OP_SUBI    = 3'b100;
    localparam OP_MUL     = 3'b101;
    localparam OP_CLEAR   = 3'b110;
    localparam OP_DISPLAY = 3'b111;

    // ---------- Etapa 01: imediato em complemento a 2 ----------
    wire [15:0] imm_ext = {10'b0, imm_mod};
    wire [15:0] imm     = imm_sinal ? (~imm_ext + 16'd1) : imm_ext;

    // ---------- Etapa 02: as oito saidas ----------
    always @(*) begin
        case (opcode)
            OP_LOAD:    result = imm;
            OP_ADD:     result = a + b;
            OP_ADDI:    result = a + imm;
            OP_SUB:     result = a - b;
            OP_SUBI:    result = a - imm;
            OP_MUL:     result = a * imm;   // 16 bits baixos do produto
            OP_CLEAR:   result = 16'd0;
            OP_DISPLAY: result = a;
            default:    result = 16'd0;
        endcase
    end

endmodule
