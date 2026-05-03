module Input_Buffer #(
    parameter DEPTH      = 16384,
    parameter ADDR_BITS  = 14,
    parameter DATA_BITS  = 64,
    parameter BLOCK_SIZE = 64
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire                  out_ready,

    input  wire [DATA_BITS-1:0]  rom_q,
    output reg  [ADDR_BITS-1:0]  rom_addr,
    output wire                  rom_clock,

    output reg  [DATA_BITS-1:0]  out_data,
    output reg                   out_valid,
    output reg                   block_done,
    output reg                   done,
    output reg                   error,
    output reg  [2:0]            state_dbg
);

assign rom_clock = clk;

localparam [2:0]
    IDLE       = 3'd0,
    SET_ADDR   = 3'd1,
    WAIT_ROM   = 3'd2,
    LOAD_DATA  = 3'd3,
    SEND       = 3'd4,
    BLOCK_DONE = 3'd5,
    DONE_ST    = 3'd6;

reg [2:0] state;
reg [2:0] next_state;

reg [ADDR_BITS:0] word_index;
reg [6:0]         block_count;

always @(*) begin
    out_valid  = (state == SEND);
    block_done = (state == BLOCK_DONE);
    done       = (state == DONE_ST);
    state_dbg  = state;
end

always @(*) begin
    next_state = state;

    case (state)
        IDLE: begin
            if (start) begin
                if (word_index >= DEPTH)
                    next_state = DONE_ST;
                else
                    next_state = SET_ADDR;
            end
        end

        SET_ADDR:   next_state = WAIT_ROM;
        WAIT_ROM:   next_state = LOAD_DATA;
        LOAD_DATA:  next_state = SEND;

        SEND: begin
            if (out_ready) begin
                if (block_count + 1 >= BLOCK_SIZE)
                    next_state = BLOCK_DONE;
                else
                    next_state = SET_ADDR;
            end
        end

        BLOCK_DONE: begin
            if (word_index >= DEPTH)
                next_state = DONE_ST;
            else
                next_state = SET_ADDR;
        end

        DONE_ST: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= IDLE;
        rom_addr    <= {ADDR_BITS{1'b0}};
        word_index  <= {(ADDR_BITS+1){1'b0}};
        block_count <= 7'd0;
        out_data    <= {DATA_BITS{1'b0}};
        error       <= 1'b0;
    end else begin
        state <= next_state;
        error <= 1'b0;

        case (state)
            IDLE: begin
                if (start && word_index >= DEPTH)
                    error <= 1'b1;
            end

            SET_ADDR: begin
                rom_addr <= word_index[ADDR_BITS-1:0];
            end

            WAIT_ROM: begin
            end

            LOAD_DATA: begin
                out_data <= rom_q;
            end

            SEND: begin
                if (out_ready) begin
                    word_index <= word_index + 1'b1;

                    if (block_count + 1 >= BLOCK_SIZE)
                        block_count <= 7'd0;
                    else
                        block_count <= block_count + 1'b1;
                end
            end

            BLOCK_DONE: begin
            end

            DONE_ST: begin
            end

            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule