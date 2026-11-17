// ============================================================================
// lcd_display.v - Controlador do LCD da Mini_CPU
// A cada pulso de "start" (com busy = 0) redesenha as duas linhas:
//   indice 0      : 8'h80 (linha 1, coluna 0)  rs = 0
//   indices 1..16 : 16 caracteres da linha 1   rs = 1
//   indice 17     : 8'hC0 (linha 2, coluna 0)  rs = 0
//   indices 18..33: 16 caracteres da linha 2   rs = 1
// Modos: APAGADO, INICIAL, COMPLETO, SO_NOME.
// ============================================================================
module lcd_display #(
    parameter DELAY_PULSE = 25,       // Enable em 1 por 500 ns
    parameter DELAY_WRITE = 50_000    // 1 ms apos a descida do Enable
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [1:0] modo,
    input  wire [2:0] opcode,
    input  wire [3:0] reg_num,
    input  wire       negativo,
    input  wire [3:0] d4,
    input  wire [3:0] d3,
    input  wire [3:0] d2,
    input  wire [3:0] d1,
    input  wire [3:0] d0,
    output wire       busy,
    output wire [7:0] lcd_data,
    output wire       lcd_rs,
    output wire       lcd_rw,
    output wire       lcd_e
);

    // ---------------- Modos ----------------
    localparam M_APAGADO  = 2'd0;
    localparam M_INICIAL  = 2'd1;
    localparam M_COMPLETO = 2'd2;
    localparam M_SO_NOME  = 2'd3;

    localparam MSG_LEN = 34;

    // ---------------- Estados ----------------
    localparam S_WAIT_INIT = 3'd0,
               S_IDLE      = 3'd1,
               S_PREPARE   = 3'd2,
               S_PULSE_E   = 3'd3,
               S_WAIT      = 3'd4;

    reg [2:0]  state, next_state;
    reg [5:0]  msg_index, next_msg_index;
    reg [16:0] count, next_count;

    reg [7:0]  wr_data;
    reg        wr_rs, wr_e;

    // ---------------- Inicializacao (Lab 08) ----------------
    wire       init_done;
    wire [7:0] init_data;
    wire       init_rs, init_rw, init_e;

    lcd_init_hd44780 u_init (
        .clk      (clk),
        .rst      (rst),
        .lcd_data (init_data),
        .lcd_rs   (init_rs),
        .lcd_rw   (init_rw),
        .lcd_e    (init_e),
        .done     (init_done)
    );

    assign busy = (state != S_IDLE);

    // ---------------- Byte do indice atual ----------------
    wire is_cmd = (msg_index == 6'd0) || (msg_index == 6'd17);

    // mnemonico de 4 letras
    reg [31:0] mnem;
    always @(*) begin
        case (opcode)
            3'b000: mnem = "LOAD";
            3'b001: mnem = "ADD ";
            3'b010: mnem = "ADDI";
            3'b011: mnem = "SUB ";
            3'b100: mnem = "SUBI";
            3'b101: mnem = "MUL ";
            3'b110: mnem = "CLR ";
            default: mnem = "DPL ";
        endcase
    end

    wire       linha2 = (msg_index >= 6'd18);
    wire [5:0] coluna = linha2 ? (msg_index - 6'd18) : (msg_index - 6'd1);

    wire       mostra_nome  = (modo == M_COMPLETO) || (modo == M_SO_NOME);
    wire       mostra_valor = (modo == M_COMPLETO);
    wire       inicial      = (modo == M_INICIAL);

    reg [7:0] char;
    always @(*) begin
        char = 8'h20;                                  // espaco
        if (msg_index == 6'd0)       char = 8'h80;     // linha 1, coluna 0
        else if (msg_index == 6'd17) char = 8'hC0;     // linha 2, coluna 0
        else if (!linha2) begin
            case (coluna)
                6'd0: char = inicial ? "-" : (mostra_nome ? mnem[31:24] : 8'h20);
                6'd1: char = inicial ? "-" : (mostra_nome ? mnem[23:16] : 8'h20);
                6'd2: char = inicial ? "-" : (mostra_nome ? mnem[15:8]  : 8'h20);
                6'd3: char = inicial ? "-" : (mostra_nome ? mnem[7:0]   : 8'h20);
                6'd10: char = (inicial || mostra_valor) ? "[" : 8'h20;
                6'd11: char = inicial ? "-" : (mostra_valor ? (reg_num[3] ? "1" : "0") : 8'h20);
                6'd12: char = inicial ? "-" : (mostra_valor ? (reg_num[2] ? "1" : "0") : 8'h20);
                6'd13: char = inicial ? "-" : (mostra_valor ? (reg_num[1] ? "1" : "0") : 8'h20);
                6'd14: char = inicial ? "-" : (mostra_valor ? (reg_num[0] ? "1" : "0") : 8'h20);
                6'd15: char = (inicial || mostra_valor) ? "]" : 8'h20;
                default: char = 8'h20;
            endcase
        end else begin
            case (coluna)
                6'd10: char = inicial ? "+" : (mostra_valor ? (negativo ? "-" : "+") : 8'h20);
                6'd11: char = inicial ? "0" : (mostra_valor ? (8'h30 + d4) : 8'h20);
                6'd12: char = inicial ? "0" : (mostra_valor ? (8'h30 + d3) : 8'h20);
                6'd13: char = inicial ? "0" : (mostra_valor ? (8'h30 + d2) : 8'h20);
                6'd14: char = inicial ? "0" : (mostra_valor ? (8'h30 + d1) : 8'h20);
                6'd15: char = inicial ? "0" : (mostra_valor ? (8'h30 + d0) : 8'h20);
                default: char = 8'h20;
            endcase
        end
    end

    // ---------------- Bloco 1: registradores ----------------
    always @(posedge clk) begin
        if (rst) begin
            state     <= S_WAIT_INIT;
            msg_index <= 6'd0;
            count     <= 17'd0;
        end else begin
            state     <= next_state;
            msg_index <= next_msg_index;
            count     <= next_count;
        end
    end

    // ---------------- Bloco 2: proximo estado ----------------
    always @(*) begin
        next_state     = state;
        next_msg_index = msg_index;
        next_count     = count;
        case (state)
            S_WAIT_INIT: if (init_done) next_state = S_IDLE;
            S_IDLE: begin
                if (start) begin
                    next_msg_index = 6'd0;
                    next_count     = 17'd0;
                    next_state     = S_PREPARE;
                end
            end
            S_PREPARE: begin
                next_count = 17'd0;
                next_state = S_PULSE_E;
            end
            S_PULSE_E: begin
                if (count >= DELAY_PULSE - 1) begin
                    next_count = 17'd0;
                    next_state = S_WAIT;
                end else next_count = count + 1'b1;
            end
            S_WAIT: begin
                if (count >= DELAY_WRITE - 1) begin
                    next_count = 17'd0;
                    if (msg_index == MSG_LEN - 1) next_state = S_IDLE;
                    else begin
                        next_msg_index = msg_index + 1'b1;
                        next_state     = S_PREPARE;
                    end
                end else next_count = count + 1'b1;
            end
            default: next_state = S_WAIT_INIT;
        endcase
    end

    // ---------------- Bloco 3: saidas ----------------
    always @(*) begin
        wr_data = char;
        wr_rs   = 1'b0;
        wr_e    = 1'b0;
        case (state)
            S_PREPARE: begin wr_rs = ~is_cmd; wr_e = 1'b0; end
            S_PULSE_E: begin wr_rs = ~is_cmd; wr_e = 1'b1; end
            S_WAIT:    begin wr_rs = ~is_cmd; wr_e = 1'b0; end
            default:   begin wr_rs = 1'b0;    wr_e = 1'b0; end
        endcase
    end

    // durante a inicializacao quem dirige o LCD e o lcd_init_hd44780
    assign lcd_data = (state == S_WAIT_INIT) ? init_data : wr_data;
    assign lcd_rs   = (state == S_WAIT_INIT) ? init_rs   : wr_rs;
    assign lcd_rw   = (state == S_WAIT_INIT) ? init_rw   : 1'b0;
    assign lcd_e    = (state == S_WAIT_INIT) ? init_e    : wr_e;

endmodule
