`timescale 1ns/1ps

module top_controller_ip_tb;

    localparam BUF_DEPTH = 4;
    localparam OUT_WIDTH = 32;

    reg clk, rst_n, req_read, req_write;
    reg [13:0] addr_in;
    reg [63:0] din_in;

    wire [OUT_WIDTH-1:0] data_out;
    wire data_valid, fifo_full, fifo_empty, ram_ready;

    top_controller #(
        .BUF_DEPTH(BUF_DEPTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n), .addr_in(addr_in), .din_in(din_in),
        .req_read(req_read), .req_write(req_write), .data_out(data_out),
        .data_valid(data_valid), .fifo_full(fifo_full), 
        .fifo_empty(fifo_empty), .ram_ready(ram_ready)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    task pulse_write(input [13:0] a, input [63:0] d);
        begin
            @(posedge clk);
            addr_in = a; din_in = d;
            req_write = 1;
            @(posedge clk);
            req_write = 0;
            wait(ram_ready == 1);
            @(posedge clk);
        end
    endtask

    task pulse_read(input [13:0] a);
        begin
            @(posedge clk);
            addr_in = a;
            req_read = 1;
            @(posedge clk);
            req_read = 0;
            wait(ram_ready == 1);
            @(posedge clk);
        end
    endtask

    initial begin
        rst_n = 0; req_read = 0; req_write = 0;
        addr_in = 0; din_in = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("==> ESCREVENDO: 0xDEADBEEFCAFE0011");
        pulse_write(14'h0010, 64'hDEADBEEFCAFE0011);

        $display("==> LENDO: addr 0x0010");
        pulse_read(14'h0010);

        $display("==> MONITORANDO SAIDA...");
        repeat(20) begin
            @(posedge clk);
            if (data_valid)
                $display("    [%0t ns] DATA_OUT = 0x%h", $time, data_out);
        end

        $display("==> TESTE CONCLUIDO.");
        $stop;
    end

endmodule