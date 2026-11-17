// ============================================================================
// module_mini_cpu.v - Topo da Mini_CPU (DE2-115)
//   KEY[3] = Ligar/Desligar   (age ao SOLTAR)
//   KEY[2] = Enviar instrucao (age ao SOLTAR)
//   KEY[0] = reset
//   SW[17:0] = instrucao
// ============================================================================
module module_mini_cpu (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire [7:0]  LCD_DATA,
    output wire        LCD_RS,
    output wire        LCD_RW,
    output wire        LCD_EN,
    output wire        LCD_ON,
    output wire        LCD_BLON
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

    // ---------------- Modos do LCD ----------------
    localparam M_APAGADO  = 2'd0;
    localparam M_INICIAL  = 2'd1;
    localparam M_COMPLETO = 2'd2;
    localparam M_SO_NOME  = 2'd3;

    // ---------------- Estados ----------------
    localparam S_DESLIGADO   = 4'd0,
               S_INICIAR     = 4'd1,
               S_PRONTO      = 4'd2,
               S_BUSCA       = 4'd3,
               S_LEITURA     = 4'd4,
               S_EXECUCAO    = 4'd5,
               S_ESCRITA     = 4'd6,
               S_MOSTRAR     = 4'd7,
               S_ESPERA_LCD1 = 4'd8,   // um ciclo para busy subir
               S_ESPERA_LCD2 = 4'd9,   // espera busy em 0
               S_DESLIGAR    = 4'd10;

    wire clk = CLOCK_50;
    wire rst = ~KEY[0];

    assign LCD_ON   = 1'b1;
    assign LCD_BLON = 1'b1;

    // ======================= Sinais internos =======================
    // memoria
    wire        we, clr;
    wire [3:0]  addr_a, addr_b, addr_w;
    wire [15:0] data_in, data_a, data_b;
    // ALU
    wire [2:0]  opcode;
    wire        imm_sinal;
    wire [5:0]  imm_mod;
    wire [15:0] result;
    // bin2bcd
    wire [15:0] valor;
    wire        negativo;
    wire [3:0]  d4, d3, d2, d1, d0;
    // LCD
    wire        start, busy;
    wire [3:0]  reg_num;
    reg  [1:0]  modo;

    // registradores da FSM
    reg  [3:0]  state, next_state;
    reg  [17:0] ir;          // registrador de instrucao
    reg  [15:0] res;         // registrador de resultado
    reg         volta_desl;  // destino de "Esperar LCD": 1 = Desligado, 0 = Pronto
    reg  [1:0]  next_modo;
    reg         next_volta_desl;
    reg         we_r, clr_r, start_r;

    // ==================== Etapa 02: detector de soltura ====================
    // 2 FFs sincronizam, o 3o guarda o valor anterior. Botao = 0 apertado.
    reg [2:0] sr_ligar, sr_enviar;
    always @(posedge clk) begin
        sr_ligar  <= {sr_ligar[1:0],  KEY[3]};
        sr_enviar <= {sr_enviar[1:0], KEY[2]};
    end
    initial begin sr_ligar = 3'b111; sr_enviar = 3'b111; end

    wire ligar_solto  = sr_ligar[1]  & ~sr_ligar[2];   // anterior 0, atual 1
    wire enviar_solto = sr_enviar[1] & ~sr_enviar[2];

    // ============ Etapa 03: separacao dos campos da instrucao ============
    //  Reg x Reg : [17:15] op | [14:11] D1 | [10:7] O1 | [6:3] O2
    //  Reg x Imm : [17:15] op | [14:11] D1 | [10:7] O1 | [6] sinal | [5:0] imm
    //  LOAD      : [17:15] op | [14:11] D1 | [10] sinal | [9:4] imm
    //  DISPLAY   : [17:15] op | [14:11] O1
    assign opcode    = ir[17:15];
    assign addr_w    = ir[14:11];
    assign reg_num   = ir[14:11];
    assign addr_a    = (opcode == OP_DISPLAY) ? ir[14:11] : ir[10:7];
    assign addr_b    = ir[6:3];
    assign imm_sinal = (opcode == OP_LOAD) ? ir[10]  : ir[6];
    assign imm_mod   = (opcode == OP_LOAD) ? ir[9:4] : ir[5:0];
    // =====================================================================

    assign data_in = res;
    assign valor   = res;
    assign we      = we_r;
    assign clr     = clr_r;
    assign start   = start_r;

    wire escreve = (opcode != OP_CLEAR) && (opcode != OP_DISPLAY);

    // ======================= Instancias =======================
    memory u_mem (
        .clk     (clk),
        .rst     (rst),
        .we      (we),
        .clr     (clr),
        .addr_a  (addr_a),
        .addr_b  (addr_b),
        .addr_w  (addr_w),
        .data_in (data_in),
        .data_a  (data_a),
        .data_b  (data_b)
    );

    module_alu u_alu (
        .opcode    (opcode),
        .a         (data_a),
        .b         (data_b),
        .imm_sinal (imm_sinal),
        .imm_mod   (imm_mod),
        .result    (result)
    );

    bin2bcd u_bcd (
        .valor    (valor),
        .negativo (negativo),
        .d4 (d4), .d3 (d3), .d2 (d2), .d1 (d1), .d0 (d0)
    );

    lcd_display u_lcd (
        .clk      (clk),
        .rst      (rst),
        .start    (start),
        .modo     (modo),
        .opcode   (opcode),
        .reg_num  (reg_num),
        .negativo (negativo),
        .d4 (d4), .d3 (d3), .d2 (d2), .d1 (d1), .d0 (d0),
        .busy     (busy),
        .lcd_data (LCD_DATA),
        .lcd_rs   (LCD_RS),
        .lcd_rw   (LCD_RW),
        .lcd_e    (LCD_EN)
    );

    // ================= FSM - Bloco 1: sequencial =================
    always @(posedge clk) begin
        if (rst) begin
            state      <= S_DESLIGADO;
            ir         <= 18'd0;
            res        <= 16'd0;
            modo       <= M_APAGADO;
            volta_desl <= 1'b1;
        end else begin
            state      <= next_state;
            modo       <= next_modo;
            volta_desl <= next_volta_desl;
            if (state == S_BUSCA)    ir  <= SW;
            if (state == S_EXECUCAO) res <= result;
            if (state == S_DESLIGAR) res <= 16'd0;
        end
    end

    // ================= FSM - Bloco 2: proximo estado =================
    always @(*) begin
        next_state      = state;
        next_modo       = modo;
        next_volta_desl = volta_desl;
        case (state)
            S_DESLIGADO: if (ligar_solto) next_state = S_INICIAR;
            S_INICIAR: begin
                if (!busy) begin
                    next_modo       = M_INICIAL;
                    next_volta_desl = 1'b0;
                    next_state      = S_ESPERA_LCD1;
                end
            end
            S_PRONTO: begin
                if (ligar_solto)       next_state = S_DESLIGAR;
                else if (enviar_solto) next_state = S_BUSCA;
            end
            S_BUSCA:    next_state = S_LEITURA;
            S_LEITURA:  next_state = S_EXECUCAO;
            S_EXECUCAO: next_state = S_ESCRITA;
            S_ESCRITA:  next_state = S_MOSTRAR;
            S_MOSTRAR: begin
                next_modo       = (opcode == OP_CLEAR) ? M_SO_NOME : M_COMPLETO;
                next_volta_desl = 1'b0;
                next_state      = S_ESPERA_LCD1;
            end
            S_ESPERA_LCD1: next_state = S_ESPERA_LCD2;
            S_ESPERA_LCD2: if (!busy) next_state = volta_desl ? S_DESLIGADO : S_PRONTO;
            S_DESLIGAR: begin
                next_modo       = M_APAGADO;
                next_volta_desl = 1'b1;
                next_state      = S_ESPERA_LCD1;
            end
            default: next_state = S_DESLIGADO;
        endcase
    end

    // ================= FSM - Bloco 3: saidas =================
    always @(*) begin
        we_r    = 1'b0;
        clr_r   = 1'b0;
        start_r = 1'b0;
        case (state)
            S_INICIAR:  start_r = ~busy;
            S_ESCRITA: begin
                we_r  = escreve;
                clr_r = (opcode == OP_CLEAR);
            end
            S_MOSTRAR:  start_r = 1'b1;
            S_DESLIGAR: begin
                clr_r   = 1'b1;
                start_r = 1'b1;
            end
            default: ;
        endcase
    end

endmodule
