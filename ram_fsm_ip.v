// ============================================================
//  1.  FSM da RAM — adaptada para IP Single-Port
//
//  Estados (one-hot):
//    IDLE      : aguarda comando
//    WRITE     : ativa wren por 1 ciclo → dados gravados
//    READ_REQ  : ativa rden por 1 ciclo → dispara leitura
//    READ_WAIT : absorve latência de 1 ciclo do IP
//    DONE      : sinaliza ready; mantém q estável
//
//  NOTA: wren e rden nunca devem ser '1' ao mesmo tempo
//        (restrição da RAM Single-Port).
// ============================================================
module ram_fsm_ip (
    input  wire        clk,
    input  wire        rst_n,

    // Interface com o controlador externo
    input  wire        cs,
    input  wire        we,
    input  wire        oe,
    input  wire [13:0] addr,
    input  wire [63:0] din,
    output wire [63:0] dout,   // conectado diretamente ao q do IP
    output reg         ready,

    // Interface com o IP da RAM (conectar aos pinos do .qip)
    output reg         ram_wren,
    output reg         ram_rden,
    output reg  [13:0] ram_addr,
    output reg  [63:0] ram_data,
    input  wire [63:0] ram_q
);

    // dout espelha a saída do IP diretamente
    assign dout = ram_q;

    // Estados one-hot (5 estados)
    localparam [4:0]
        IDLE      = 5'b00001,
        WRITE     = 5'b00010,
        READ_REQ  = 5'b00100,
        READ_WAIT = 5'b01000,
        DONE      = 5'b10000;

    reg [4:0] state, next_state;

    // Registrador de estado
    always @(posedge clk or negedge rst_n)
        if (!rst_n) state <= IDLE;
        else        state <= next_state;

    // Próximo estado
    always @(*) begin
        case (state)
            IDLE:      if      (cs && we && !oe) next_state = WRITE;
                       else if (cs && oe && !we) next_state = READ_REQ;
                       else                      next_state = IDLE;
            WRITE:     next_state = DONE;
            READ_REQ:  next_state = READ_WAIT;   // aguarda 1 ciclo de latência
            READ_WAIT: next_state = DONE;         // q já está válido aqui
            DONE:      next_state = cs ? DONE : IDLE;
            default:   next_state = IDLE;
        endcase
    end

    // Saídas para o IP e sinais de status
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ram_wren <= 1'b0;
            ram_rden <= 1'b0;
            ram_addr <= 14'b0;
            ram_data <= 64'b0;
            ready    <= 1'b0;
        end else begin
            // Defaults (pulsos de 1 ciclo)
            ram_wren <= 1'b0;
            ram_rden <= 1'b0;
            ready    <= 1'b0;

            case (state)
                IDLE: begin
                    ram_addr <= addr;   // captura endereço cedo
                    ram_data <= din;
                end

                WRITE: begin
                    ram_wren <= 1'b1;
                    ram_addr <= addr;
                    ram_data <= din;
                end

                READ_REQ: begin
                    ram_rden <= 1'b1;
                    ram_addr <= addr;
                end

                READ_WAIT: ;            // aguarda q propagar (sem ação)

                DONE: begin
                    ready <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule