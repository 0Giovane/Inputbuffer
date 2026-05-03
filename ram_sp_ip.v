// ============================================================
//  0.  Stub do IP gerado pelo Quartus (apenas para simulação)
//      * REMOVA este bloco ao sintetizar — use o .qip real *
// ============================================================
module ram_sp_ip (
    input  wire        clock,
    input  wire        wren,
    input  wire        rden,
    input  wire [13:0] address,
    input  wire [63:0] data,
    output reg  [63:0] q
);
    reg [63:0] mem [0:16383];

    always @(posedge clock) begin
        if (wren)
            mem[address] <= data;
        if (rden)
            q <= mem[address];   // latência de 1 ciclo (síncrono)
    end
endmodule