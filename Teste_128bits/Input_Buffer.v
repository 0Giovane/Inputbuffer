module Input_Buffer #(
    parameter DEPTH        = 8192,
    parameter ADDR_BITS    = 13,
    parameter DATA_BITS    = 128,
    parameter REPEAT_COUNT = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  prepare,
    input  wire                  go,

    input  wire [127:0]  rom_q,
    output reg  [12:0]  rom_addr,
    output wire                  rom_clock,

    output wire [127:0]  out_data,
    output reg                   out_valid,
    output reg                   ready_to_stream,
    output reg                   done
);

assign rom_clock = clk;
assign out_data  = rom_q;

localparam [1:0]
    IDLE    = 2'd0,
    WARMUP  = 2'd1,
    READY   = 2'd2,
    RUN     = 2'd3;

localparam TOTAL_WORDS = DEPTH * REPEAT_COUNT;

reg [1:0] state;

reg [31:0] valid_count;
reg [ADDR_BITS-1:0] next_addr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state           <= IDLE;
        rom_addr        <= {ADDR_BITS{1'b0}};
        next_addr       <= {ADDR_BITS{1'b0}};
        valid_count     <= 32'd0;
        out_valid       <= 1'b0;
        ready_to_stream <= 1'b0;
        done            <= 1'b0;
    end else begin
        done <= 1'b0;

        case (state)

            IDLE: begin
                out_valid       <= 1'b0;
                ready_to_stream <= 1'b0;
                valid_count     <= 32'd0;
                rom_addr        <= {ADDR_BITS{1'b0}};

                if (prepare) begin
                    rom_addr <= {ADDR_BITS{1'b0}};

                    if (DEPTH > 1)
                        next_addr <= {{(ADDR_BITS-1){1'b0}}, 1'b1};
                    else
                        next_addr <= {ADDR_BITS{1'b0}};

                    state <= WARMUP;
                end
            end

            WARMUP: begin
                out_valid       <= 1'b0;
                ready_to_stream <= 1'b1;
                state           <= READY;
            end

            READY: begin
                out_valid       <= 1'b0;
                ready_to_stream <= 1'b1;

                if (go) begin
                    out_valid       <= 1'b1;
                    ready_to_stream <= 1'b0;
                    valid_count     <= 32'd1;

                    if (TOTAL_WORDS > 1) begin
                        rom_addr <= next_addr;

                        if (next_addr == DEPTH - 1)
                            next_addr <= {ADDR_BITS{1'b0}};
                        else
                            next_addr <= next_addr + 1'b1;
                    end

                    state <= RUN;
                end
            end

            RUN: begin
                ready_to_stream <= 1'b0;

                if (valid_count >= TOTAL_WORDS) begin
                    out_valid <= 1'b0;
                    done      <= 1'b1;
                    state     <= IDLE;
                end else begin
                    out_valid   <= 1'b1;
                    valid_count <= valid_count + 1'b1;

                    if (valid_count < TOTAL_WORDS - 1) begin
                        rom_addr <= next_addr;

                        if (next_addr == DEPTH - 1)
                            next_addr <= {ADDR_BITS{1'b0}};
                        else
                            next_addr <= next_addr + 1'b1;
                    end
                end
            end

            default: begin
                state           <= IDLE;
                out_valid       <= 1'b0;
                ready_to_stream <= 1'b0;
            end

        endcase
    end
end

endmodule