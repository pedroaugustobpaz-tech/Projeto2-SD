// ============================================================================
// lcd_init_hd44780.v - Inicializacao do LCD HD44780 (8 bits, 2 linhas)
// Espera a energizacao, envia 4 comandos e levanta "done".
//   0x38 Modo funcional : DL=1 (8 bits), N=1 (2 linhas), F=0 (5x8)
//   0x0C Display        : D=1, C=0, B=0
//   0x01 Limpar display
//   0x06 Modo de entrada: I/D=1, S=0
// OBS: se o grupo ja tem o lcd_init_hd44780.v do Lab 08, use o do lab
//      e ajuste apenas os nomes de porta na instancia em lcd_display.v.
// ============================================================================
module lcd_init_hd44780 #(
    parameter DELAY_POWER = 1_000_000,  // 20 ms  @ 50 MHz
    parameter DELAY_PULSE = 25,         // 500 ns de Enable em 1
    parameter DELAY_CMD   = 100_000     // 2 ms apos cada comando
)(
    input  wire       clk,
    input  wire       rst,
    output reg  [7:0] lcd_data,
    output wire       lcd_rs,
    output wire       lcd_rw,
    output reg        lcd_e,
    output reg        done
);

    localparam S_POWER = 3'd0,
               S_SETUP = 3'd1,
               S_PULSE = 3'd2,
               S_HOLD  = 3'd3,
               S_DONE  = 3'd4;

    reg [2:0]  state;
    reg [1:0]  cmd_index;
    reg [20:0] count;

    assign lcd_rs = 1'b0;   // so comandos
    assign lcd_rw = 1'b0;   // so escrita

    always @(*) begin
        case (cmd_index)
            2'd0: lcd_data = 8'h38;
            2'd1: lcd_data = 8'h0C;
            2'd2: lcd_data = 8'h01;
            default: lcd_data = 8'h06;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            state     <= S_POWER;
            cmd_index <= 2'd0;
            count     <= 21'd0;
            lcd_e     <= 1'b0;
            done      <= 1'b0;
        end else begin
            case (state)
                S_POWER: begin
                    if (count >= DELAY_POWER - 1) begin
                        count <= 0; state <= S_SETUP;
                    end else count <= count + 1'b1;
                end
                S_SETUP: begin           // dado estavel antes do Enable
                    lcd_e <= 1'b1; count <= 0; state <= S_PULSE;
                end
                S_PULSE: begin
                    if (count >= DELAY_PULSE - 1) begin
                        lcd_e <= 1'b0; count <= 0; state <= S_HOLD;
                    end else count <= count + 1'b1;
                end
                S_HOLD: begin
                    if (count >= DELAY_CMD - 1) begin
                        count <= 0;
                        if (cmd_index == 2'd3) state <= S_DONE;
                        else begin
                            cmd_index <= cmd_index + 1'b1;
                            state     <= S_SETUP;
                        end
                    end else count <= count + 1'b1;
                end
                default: begin
                    done  <= 1'b1;
                    lcd_e <= 1'b0;
                end
            endcase
        end
    end

endmodule
