`timescale 1ns/1ps

module tb_input_buffer;

parameter CLK_PERIOD   = 10;
parameter DEPTH        = 16384;
parameter ADDR_BITS    = 14;
parameter DATA_BITS    = 64;
parameter REPEAT_COUNT = 2;

reg clk;
reg rst_n;
reg start;

wire [DATA_BITS-1:0] out_data;
wire out_valid;
wire done;

wire [ADDR_BITS-1:0] rom_addr;
wire [DATA_BITS-1:0] rom_q;
wire rom_clock;

reg [DATA_BITS-1:0] ref_mem [0:DEPTH-1];

integer k;
integer file_out;
integer pass_count;
integer fail_count;
integer total_errors;
integer cycle_counter;

Input_Buffer #(
    .DEPTH(DEPTH),
    .ADDR_BITS(ADDR_BITS),
    .DATA_BITS(DATA_BITS),
    .REPEAT_COUNT(REPEAT_COUNT)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),

    .rom_q(rom_q),
    .rom_addr(rom_addr),
    .rom_clock(rom_clock),

    .out_data(out_data),
    .out_valid(out_valid),
    .done(done)
);

Memoria rom_inst (
    .clock(rom_clock),
    .address(rom_addr),
    .q(rom_q)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

always @(posedge clk) begin
    cycle_counter = cycle_counter + 1;
end

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
    rst_n = 0;
    start = 0;
    cycle_counter = 0;

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

task run_stream_test;
    input integer tc_num;

    integer expected_total;
    integer received_total;
    integer expected_addr;
    integer expected_repeat;
    integer timeout;
    integer start_cycle;
    integer finish_cycle;
    integer local_errors;
    reg [DATA_BITS-1:0] expected;

begin
    expected_total  = DEPTH * REPEAT_COUNT;
    received_total  = 0;
    expected_addr   = 0;
    expected_repeat = 0;
    timeout         = 0;
    local_errors    = 0;

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "TC%0d - STREAM CONTINUO SEM PAUSA\n", tc_num);
    $fwrite(file_out, "DEPTH=%0d REPEAT_COUNT=%0d TOTAL=%0d\n",
            DEPTH, REPEAT_COUNT, expected_total);
    $fwrite(file_out, "============================================================\n");

    pulse_start();
    start_cycle = cycle_counter;

    while (!done && timeout < (expected_total + 1000)) begin

        @(negedge clk);

        if (out_valid) begin
            expected = ref_mem[expected_addr];

            $fwrite(file_out,
                    "ciclo=%0d rep=%0d addr=%0d data=%h esperado=%h",
                    cycle_counter, expected_repeat, expected_addr,
                    out_data, expected);

            if (out_data !== expected) begin
                $display("[TC%0d] FAIL ciclo=%0d rep=%0d addr=%0d out=%h esperado=%h",
                         tc_num, cycle_counter, expected_repeat,
                         expected_addr, out_data, expected);

                $fwrite(file_out, " FAIL\n");
                local_errors = local_errors + 1;
            end else begin
                $fwrite(file_out, " PASS\n");

                if (received_total < 20)
                    $display("[TC%0d] PASS ciclo=%0d rep=%0d addr=%0d data=%h",
                             tc_num, cycle_counter, expected_repeat,
                             expected_addr, out_data);
            end

            received_total = received_total + 1;

            if (expected_addr == DEPTH - 1) begin
                expected_addr = 0;
                expected_repeat = expected_repeat + 1;
            end else begin
                expected_addr = expected_addr + 1;
            end
        end

        @(posedge clk); #1;
        timeout = timeout + 1;
    end

    finish_cycle = cycle_counter;

    if (timeout >= (expected_total + 1000)) begin
        $display("[TC%0d] FAIL - TIMEOUT", tc_num);
        $fwrite(file_out, "TIMEOUT\n");
        local_errors = local_errors + 1;
    end

    if (received_total != expected_total) begin
        $display("[TC%0d] FAIL total recebido=%0d esperado=%0d",
                 tc_num, received_total, expected_total);

        $fwrite(file_out, "TOTAL FAIL recebido=%0d esperado=%0d\n",
                received_total, expected_total);

        local_errors = local_errors + 1;
    end else begin
        $display("[TC%0d] TOTAL OK recebeu=%0d words",
                 tc_num, received_total);

        $fwrite(file_out, "TOTAL OK recebido=%0d words\n", received_total);
    end

    if (!done) begin
        $display("[TC%0d] FAIL done nao ativou", tc_num);
        $fwrite(file_out, "DONE FAIL\n");
        local_errors = local_errors + 1;
    end else begin
        $display("[TC%0d] DONE OK", tc_num);
        $fwrite(file_out, "DONE OK\n");
    end

    $display("[TC%0d] CICLOS total=%0d transfers=%0d",
             tc_num, finish_cycle - start_cycle, received_total);

    $fwrite(file_out, "CICLOS total=%0d transfers=%0d\n",
            finish_cycle - start_cycle, received_total);

    if (local_errors == 0) begin
        $display("[TC%0d] PASS", tc_num);
        $fwrite(file_out, "RESULTADO TC%0d PASS\n", tc_num);
        pass_count = pass_count + 1;
    end else begin
        $display("[TC%0d] FAIL erros=%0d", tc_num, local_errors);
        $fwrite(file_out, "RESULTADO TC%0d FAIL erros=%0d\n",
                tc_num, local_errors);
        fail_count = fail_count + 1;
    end

    total_errors = total_errors + local_errors;

    repeat (5) @(posedge clk);
end
endtask

task reset_mid_test;
    integer received_before_reset;
begin
    received_before_reset = 0;

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "TC2 - RESET DURANTE STREAM\n");
    $fwrite(file_out, "============================================================\n");

    pulse_start();

    while (received_before_reset < 20) begin
        @(negedge clk);

        if (out_valid)
            received_before_reset = received_before_reset + 1;

        @(posedge clk); #1;
    end

    rst_n = 0;
    repeat (3) @(posedge clk);
    #1 rst_n = 1;

    repeat (3) @(posedge clk);
    #1;

    if (!out_valid && !done) begin
        $display("[TC2] RESET PASS");
        $fwrite(file_out, "RESET PASS\n");
        pass_count = pass_count + 1;
    end else begin
        $display("[TC2] RESET FAIL out_valid=%b done=%b", out_valid, done);
        $fwrite(file_out, "RESET FAIL out_valid=%b done=%b\n", out_valid, done);
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
    $fwrite(file_out, "TC3 - RETORNO PARA ENDERECO 0 APOS RESET\n");
    $fwrite(file_out, "============================================================\n");

    pulse_start();

    while (received < 16) begin
        @(negedge clk);

        if (out_valid) begin
            expected = ref_mem[received];

            $fwrite(file_out, "addr=%0d data=%h esperado=%h",
                    received, out_data, expected);

            if (out_data !== expected) begin
                $fwrite(file_out, " FAIL\n");
                local_errors = local_errors + 1;
            end else begin
                $fwrite(file_out, " PASS\n");
            end

            received = received + 1;
        end

        @(posedge clk); #1;
    end

    if (local_errors == 0) begin
        $display("[TC3] PASS voltou para addr 0");
        $fwrite(file_out, "PASS voltou para addr 0\n");
        pass_count = pass_count + 1;
    end else begin
        $display("[TC3] FAIL erros=%0d", local_errors);
        $fwrite(file_out, "FAIL erros=%0d\n", local_errors);
        fail_count = fail_count + 1;
    end

    total_errors = total_errors + local_errors;
end
endtask

initial begin
    pass_count   = 0;
    fail_count   = 0;
    total_errors = 0;
    cycle_counter = 0;

    file_out = $fopen("saida_memoria.txt", "w");

    if (file_out == 0) begin
        $display("ERRO: nao foi possivel criar saida_memoria.txt");
        $finish;
    end

    $display("============================================================");
    $display(" TESTBENCH - INPUT_BUFFER SEM PAUSA");
    $display("============================================================");

    $fwrite(file_out, "============================================================\n");
    $fwrite(file_out, "RELATORIO - INPUT_BUFFER SEM PAUSA\n");
    $fwrite(file_out, "============================================================\n");

    $display("\nTC1 - Stream completo continuo");
    do_reset();
    run_stream_test(1);

    $display("\nTC2 - Reset durante transmissao");
    do_reset();
    reset_mid_test();

    $display("\nTC3 - Verifica retorno ao endereco 0 apos reset");
    do_reset();
    check_restart_after_reset();

    $display("\n============================================================");
    $display(" RESULTADO FINAL");
    $display(" PASS TESTS=%0d FAIL TESTS=%0d ERROS INTERNOS=%0d",
             pass_count, fail_count, total_errors);

    if (fail_count == 0 && total_errors == 0)
        $display(">>> TODOS OS TESTES PASSARAM <<<");
    else
        $display(">>> EXISTEM FALHAS <<<");

    $display("============================================================");

    $fwrite(file_out, "\n============================================================\n");
    $fwrite(file_out, "RESULTADO FINAL\n");
    $fwrite(file_out, "PASS TESTS=%0d FAIL TESTS=%0d ERROS INTERNOS=%0d\n",
            pass_count, fail_count, total_errors);
    $fwrite(file_out, "============================================================\n");

    $fclose(file_out);

    $finish;
end

endmodule