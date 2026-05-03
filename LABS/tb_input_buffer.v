`timescale 1ns/1ps

module tb_input_buffer;

parameter CLK_PERIOD = 10;
parameter DEPTH      = 16384;
parameter ADDR_BITS  = 14;
parameter DATA_BITS  = 64;
parameter BLOCK_SIZE = 64;

reg clk;
reg rst_n;
reg start;
reg out_ready;

wire [DATA_BITS-1:0] out_data;
wire out_valid;
wire block_done;
wire done;
wire error;
wire [2:0] state_dbg;

wire [ADDR_BITS-1:0] rom_addr;
wire [DATA_BITS-1:0] rom_q;
wire rom_clock;

reg [DATA_BITS-1:0] ref_mem [0:DEPTH-1];

integer k;
integer pass_count;
integer fail_count;
integer total_errors;
integer file_out;

Input_Buffer #(
    .DEPTH(DEPTH),
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(DATA_BITS),
    .BLOCK_SIZE(BLOCK_SIZE)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .out_ready(out_ready),

    .rom_q(rom_q),
    .rom_addr(rom_addr),
    .rom_clock(rom_clock),

    .out_data(out_data),
    .out_valid(out_valid),
    .block_done(block_done),
    .done(done),
    .error(error),
    .state_dbg(state_dbg)
);

Memoria rom_inst (
    .clock(rom_clock),
    .address(rom_addr),
    .q(rom_q)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    for (k = 0; k < DEPTH; k = k + 1)
        ref_mem[k] = 64'h0000000000000000;

    ref_mem[0]  = 64'hABCDEF0123456789;
    ref_mem[1]  = 64'h0123456789ABCDEF;
    ref_mem[2]  = 64'hFEDCBA9876543210;
    ref_mem[3]  = 64'h1122334455667788;
    ref_mem[4]  = 64'h8877665544332211;
    ref_mem[5]  = 64'hAABBCCDDEEFF0011;
    ref_mem[6]  = 64'h1100FFEEDDCCBBAA;
    ref_mem[7]  = 64'hDEADBEEFCAFEBABE;
    ref_mem[8]  = 64'hCAFEBABDEADBEEF0;
    ref_mem[9]  = 64'h0F0F0F0F0F0F0F0F;
    ref_mem[10] = 64'hF0F0F0F0F0F0F0F0;
    ref_mem[11] = 64'hAAAAAAAAAAAAAAAA;
    ref_mem[12] = 64'h5555555555555555;
    ref_mem[13] = 64'hFFFFFFFFFFFFFFFF;
    ref_mem[14] = 64'h0000000000000001;
    ref_mem[15] = 64'h8000000000000000;
end

task do_reset;
begin
    rst_n     = 0;
    start     = 0;
    out_ready = 0;

    repeat (5) @(posedge clk);
    #1 rst_n = 1;

    repeat (3) @(posedge clk);
    #1;
end
endtask

task pulse_start;
begin
    @(posedge clk); #1;
    start = 1;

    @(posedge clk); #1;
    start = 0;
end
endtask

task run_full_test;
    input integer tc_num;
    input integer use_backpressure;

    integer expected_index;
    integer block_counter;
    integer block_total;
    integer timeout;
    integer local_errors;
    reg [DATA_BITS-1:0] expected;

begin
    expected_index = 0;
    block_counter  = 0;
    block_total    = 0;
    timeout        = 0;
    local_errors   = 0;

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "TC%0d - TESTE COMPLETO\n", tc_num);
    $fwrite(file_out, "Backpressure: %0d\n", use_backpressure);
    $fwrite(file_out, "============================================================\n");

    pulse_start();

    while (!done && timeout < 400000) begin

        @(negedge clk);

        if (use_backpressure) begin
            if ((timeout % 7 == 0) || (timeout % 11 == 0))
                out_ready = 0;
            else
                out_ready = 1;
        end else begin
            out_ready = 1;
        end

        if (out_valid && out_ready) begin
            expected = ref_mem[expected_index];

            $display("[MEM] addr=%0d data=%h", expected_index, out_data);
            $fwrite(file_out, "addr=%0d data=%h esperado=%h",
                    expected_index, out_data, expected);

            if (out_data !== expected) begin
                $display("[TC%0d] FAIL word %0d: out=%h esperado=%h",
                         tc_num, expected_index, out_data, expected);

                $fwrite(file_out, "  FAIL\n");
                local_errors = local_errors + 1;
            end else begin
                $fwrite(file_out, "  PASS\n");
            end

            expected_index = expected_index + 1;
            block_counter  = block_counter + 1;
        end

        @(posedge clk); #1;

        if (block_done) begin
            block_total = block_total + 1;

            if (block_counter == BLOCK_SIZE) begin
                $display("[TC%0d] BLOCK %0d OK - %0d words",
                         tc_num, block_total, block_counter);

                $fwrite(file_out, "---- BLOCK %0d DONE OK - %0d words ----\n",
                        block_total, block_counter);
            end else begin
                $display("[TC%0d] BLOCK %0d FAIL - recebeu %0d words",
                         tc_num, block_total, block_counter);

                $fwrite(file_out, "---- BLOCK %0d DONE FAIL - recebeu %0d words ----\n",
                        block_total, block_counter);

                local_errors = local_errors + 1;
            end

            block_counter = 0;
        end

        timeout = timeout + 1;
    end

    if (timeout >= 400000) begin
        $display("[TC%0d] FAIL - TIMEOUT geral", tc_num);
        $fwrite(file_out, "TIMEOUT GERAL\n");
        local_errors = local_errors + 1;
    end

    if (expected_index != DEPTH) begin
        $display("[TC%0d] FAIL - total recebido=%0d esperado=%0d",
                 tc_num, expected_index, DEPTH);

        $fwrite(file_out, "TOTAL FAIL - recebido=%0d esperado=%0d\n",
                expected_index, DEPTH);

        local_errors = local_errors + 1;
    end else begin
        $display("[TC%0d] TOTAL OK - recebeu %0d words", tc_num, expected_index);
        $fwrite(file_out, "TOTAL OK - recebeu %0d words\n", expected_index);
    end

    if (block_total != (DEPTH / BLOCK_SIZE)) begin
        $display("[TC%0d] FAIL - blocos=%0d esperado=%0d",
                 tc_num, block_total, DEPTH / BLOCK_SIZE);

        $fwrite(file_out, "BLOCK_DONE FAIL - blocos=%0d esperado=%0d\n",
                block_total, DEPTH / BLOCK_SIZE);

        local_errors = local_errors + 1;
    end else begin
        $display("[TC%0d] BLOCK_DONE OK - %0d blocos de %0d words",
                 tc_num, block_total, BLOCK_SIZE);

        $fwrite(file_out, "BLOCK_DONE OK - %0d blocos de %0d words\n",
                block_total, BLOCK_SIZE);
    end

    if (!done) begin
        $display("[TC%0d] FAIL - done nao ativou", tc_num);
        $fwrite(file_out, "DONE FAIL\n");
        local_errors = local_errors + 1;
    end else begin
        $display("[TC%0d] DONE OK", tc_num);
        $fwrite(file_out, "DONE OK\n");
    end

    if (local_errors == 0) begin
        $display("[TC%0d] PASS", tc_num);
        $fwrite(file_out, "RESULTADO TC%0d: PASS\n", tc_num);
        pass_count = pass_count + 1;
    end else begin
        $display("[TC%0d] FAIL com %0d erro(s)", tc_num, local_errors);
        $fwrite(file_out, "RESULTADO TC%0d: FAIL com %0d erro(s)\n",
                tc_num, local_errors);
        fail_count = fail_count + 1;
    end

    total_errors = total_errors + local_errors;

    out_ready = 0;
    repeat (5) @(posedge clk);
end
endtask

task reset_mid_test;
    integer received_before_reset;
begin
    received_before_reset = 0;

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "TC3 - RESET DURANTE TRANSMISSAO\n");
    $fwrite(file_out, "============================================================\n");

    pulse_start();
    out_ready = 1;

    while (received_before_reset < 20) begin
        @(negedge clk);
        out_ready = 1;

        if (out_valid && out_ready) begin
            $fwrite(file_out, "antes_reset addr=%0d data=%h\n",
                    received_before_reset, out_data);
            received_before_reset = received_before_reset + 1;
        end

        @(posedge clk); #1;
    end

    rst_n = 0;
    repeat (3) @(posedge clk);
    #1 rst_n = 1;

    repeat (3) @(posedge clk);
    #1;

    if (!out_valid && !done && !block_done && !error) begin
        $display("[TC3] RESET MID TRANSMISSION PASS");
        $fwrite(file_out, "RESET MID TRANSMISSION PASS\n");
        pass_count = pass_count + 1;
    end else begin
        $display("[TC3] RESET MID TRANSMISSION FAIL valid=%b done=%b block_done=%b error=%b",
                 out_valid, done, block_done, error);

        $fwrite(file_out,
                "RESET MID TRANSMISSION FAIL valid=%b done=%b block_done=%b error=%b\n",
                out_valid, done, block_done, error);

        fail_count = fail_count + 1;
        total_errors = total_errors + 1;
    end
end
endtask

task check_restart_after_reset;
    integer received;
    integer local_errors;
    reg [DATA_BITS-1:0] expected;
begin
    received = 0;
    local_errors = 0;

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "TC4 - VERIFICA RETORNO PARA WORD 0 APOS RESET\n");
    $fwrite(file_out, "============================================================\n");

    pulse_start();
    out_ready = 1;

    while (received < 16) begin
        @(negedge clk);
        out_ready = 1;

        if (out_valid && out_ready) begin
            expected = ref_mem[received];

            $display("[MEM RESET] addr=%0d data=%h", received, out_data);
            $fwrite(file_out, "addr=%0d data=%h esperado=%h",
                    received, out_data, expected);

            if (out_data !== expected) begin
                $display("[TC4] FAIL word %0d: out=%h esperado=%h",
                         received, out_data, expected);

                $fwrite(file_out, "  FAIL\n");
                local_errors = local_errors + 1;
            end else begin
                $fwrite(file_out, "  PASS\n");
            end

            received = received + 1;
        end

        @(posedge clk); #1;
    end

    if (local_errors == 0) begin
        $display("[TC4] APOS RESET VOLTOU PARA WORD 0: PASS");
        $fwrite(file_out, "APOS RESET VOLTOU PARA WORD 0: PASS\n");
        pass_count = pass_count + 1;
    end else begin
        $display("[TC4] APOS RESET FAIL com %0d erro(s)", local_errors);
        $fwrite(file_out, "APOS RESET FAIL com %0d erro(s)\n", local_errors);
        fail_count = fail_count + 1;
    end

    total_errors = total_errors + local_errors;
end
endtask

initial begin
    pass_count   = 0;
    fail_count   = 0;
    total_errors = 0;

    file_out = $fopen("saida_memoria.txt", "w");

    if (file_out == 0) begin
        $display("ERRO: nao foi possivel criar saida_memoria.txt");
        $finish;
    end

    $fwrite(file_out, "============================================================\n");
    $fwrite(file_out, "RELATORIO DA SIMULACAO - INPUT_BUFFER\n");
    $fwrite(file_out, "============================================================\n");

    $display("============================================================");
    $display(" TESTBENCH ROBUSTO - INPUT_BUFFER AUTOMATICO 64 WORDS");
    $display("============================================================");

    $display("\nTC1 - Transmissao completa sem backpressure");
    do_reset();
    run_full_test(1, 0);

    $display("\nTC2 - Transmissao completa com backpressure");
    do_reset();
    run_full_test(2, 1);

    $display("\nTC3 - Reset durante transmissao");
    do_reset();
    reset_mid_test();

    $display("\nTC4 - Verifica retorno para word 0 apos reset");
    do_reset();
    check_restart_after_reset();

    $display("\n============================================================");
    $display(" RESULTADO FINAL");
    $display(" PASS TESTS: %0d | FAIL TESTS: %0d | ERROS INTERNOS: %0d",
             pass_count, fail_count, total_errors);

    if (fail_count == 0 && total_errors == 0)
        $display(">>> TODOS OS TESTES PASSARAM <<<");
    else
        $display(">>> EXISTEM FALHAS <<<");

    $display("============================================================");

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "RESULTADO FINAL\n");
    $fwrite(file_out, "PASS TESTS: %0d | FAIL TESTS: %0d | ERROS INTERNOS: %0d\n",
            pass_count, fail_count, total_errors);

    if (fail_count == 0 && total_errors == 0)
        $fwrite(file_out, "TODOS OS TESTES PASSARAM\n");
    else
        $fwrite(file_out, "EXISTEM FALHAS\n");

    $fwrite(file_out, "============================================================\n");

    $fclose(file_out);

    $finish;
end

endmodule