module input_buffer_fifo #(
    parameter IN_WIDTH  = 64,
    parameter BUF_DEPTH = 4,
    parameter OUT_WIDTH = 8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [IN_WIDTH-1:0]  push_data,
    input  wire                 wr_en,
    input  wire                 rd_en,
    output reg  [OUT_WIDTH-1:0] data_out,
    output reg                  data_valid,
    output wire                 full,
    output wire                 empty
);

    // Cálculo do tamanho do ponteiro (Log2 manual)
    localparam ADDR_W = (BUF_DEPTH <= 2) ? 1 : (BUF_DEPTH <= 4) ? 2 : (BUF_DEPTH <= 8) ? 3 : 4;

    reg [IN_WIDTH-1:0] mem [0:BUF_DEPTH-1];
    reg [ADDR_W:0] wr_ptr, rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && 
                   (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);

    // Escrita na Fila
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_W-1:0]] <= push_data;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Leitura e Validação do Dado
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            data_out <= 0;
            data_valid <= 0;
        end else if (rd_en && !empty) begin
            data_out <= mem[rd_ptr[ADDR_W-1:0]][OUT_WIDTH-1:0];
            data_valid <= 1'b1;
            rd_ptr <= rd_ptr + 1'b1;
        end else begin
            data_valid <= 1'b0;
        end
    end
endmodule