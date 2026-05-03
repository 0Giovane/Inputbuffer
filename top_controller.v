module top_controller #(
    parameter BUF_DEPTH = 4,
    parameter OUT_WIDTH = 8
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] addr_in,
    input  wire [63:0] din_in,
    input  wire        req_read,
    input  wire        req_write,
    output wire [OUT_WIDTH-1:0] data_out,
    output wire        data_valid,
    output wire        fifo_full,
    output wire        fifo_empty,
    output wire        ram_ready
);

    // Declaração de Estados (Padrão Verilog clássico)
    localparam ST_IDLE      = 3'b000;
    localparam ST_WRITE     = 3'b001;
    localparam ST_READ_REQ  = 3'b010;
    localparam ST_WAIT_RAM  = 3'b011;
    localparam ST_DONE      = 3'b100;

    reg [2:0] state;
    reg [3:0] wait_cnt;
    reg [63:0] ram_q;
    reg fifo_wr_en;

    // Memória interna simplificada (Para fins de simulação/síntese básica)
    reg [63:0] storage [0:255]; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            wait_cnt <= 0;
            fifo_wr_en <= 0;
            ram_q <= 64'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    fifo_wr_en <= 0;
                    if (req_write) begin
                        storage[addr_in[7:0]] <= din_in;
                        state <= ST_WRITE;
                    end else if (req_read) begin
                        state <= ST_READ_REQ;
                    end
                end

                ST_WRITE: begin
                    state <= ST_DONE;
                end

                ST_READ_REQ: begin
                    ram_q <= storage[addr_in[7:0]];
                    wait_cnt <= 0;
                    state <= ST_WAIT_RAM;
                end

                ST_WAIT_RAM: begin
                    // Aguarda latência da memória (2 ciclos)
                    if (wait_cnt >= 2) begin 
                        fifo_wr_en <= 1;
                        state <= ST_DONE;
                    end else begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                ST_DONE: begin
                    fifo_wr_en <= 0;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    // Ready alto apenas quando pronto para novo comando
    assign ram_ready = (state == ST_IDLE);

    // Lógica de Drain: Se o FIFO tem algo, ele tenta ler para a saída
    wire fifo_rd_en = !fifo_empty;

    input_buffer_fifo #(
        .IN_WIDTH(64),
        .BUF_DEPTH(BUF_DEPTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) fifo_inst (
        .clk(clk),
        .rst_n(rst_n),
        .push_data(ram_q),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .data_out(data_out),
        .data_valid(data_valid),
        .full(fifo_full),
        .empty(fifo_empty)
    );

endmodule