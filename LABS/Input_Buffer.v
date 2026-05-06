module Input_Buffer #(
    parameter DEPTH        = 16384,
    parameter ADDR_BITS    = 14,
    parameter DATA_BITS    = 64,
    parameter REPEAT_COUNT = 2
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,

    input  wire [DATA_BITS-1:0]  rom_q,
    output reg  [ADDR_BITS-1:0]  rom_addr,
    output wire                  rom_clock,

    output wire [DATA_BITS-1:0]  out_data,
    output reg                   out_valid,
    output reg                   done
);

assign rom_clock = clk;
assign out_data  = rom_q;

localparam [1:0]
    IDLE    = 2'd0,
    WARMUP  = 2'd1,
    RUN     = 2'd2,
    DONE_ST = 2'd3;

localparam TOTAL_WORDS = DEPTH * REPEAT_COUNT;

reg [1:0] state;

reg [31:0] valid_count;
reg [ADDR_BITS-1:0] next_addr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= IDLE;
        rom_addr    <= {ADDR_BITS{1'b0}};
        next_addr   <= {ADDR_BITS{1'b0}};
        valid_count <= 32'd0;
        out_valid   <= 1'b0;
        done        <= 1'b0;
    end else begin
        done <= 1'b0;

        case (state)

            IDLE: begin
                out_valid   <= 1'b0;
                valid_count <= 32'd0;
                rom_addr    <= {ADDR_BITS{1'b0}};

                if (start) begin
                    rom_addr  <= {ADDR_BITS{1'b0}};
                    next_addr <= {{(ADDR_BITS-1){1'b0}}, 1'b1};
                    state     <= WARMUP;
                end
            end

            WARMUP: begin
                out_valid   <= 1'b1;
                valid_count <= 32'd1;

                rom_addr <= next_addr;

                if (next_addr == DEPTH - 1)
                    next_addr <= {ADDR_BITS{1'b0}};
                else
                    next_addr <= next_addr + 1'b1;

                state <= RUN;
            end

            RUN: begin
                if (valid_count >= TOTAL_WORDS) begin
                    out_valid <= 1'b0;
                    done      <= 1'b1;
                    state     <= DONE_ST;
                end else begin
                    out_valid   <= 1'b1;
                    valid_count <= valid_count + 1'b1;

                    rom_addr <= next_addr;

                    if (next_addr == DEPTH - 1)
                        next_addr <= {ADDR_BITS{1'b0}};
                    else
                        next_addr <= next_addr + 1'b1;
                end
            end

            DONE_ST: begin
                out_valid <= 1'b0;
                state     <= IDLE;
            end

            default: begin
                state <= IDLE;
            end

        endcase
    end
end

endmodule