module sync_fifo_top #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH      = 16,
    localparam integer ADDR_WIDTH = clog2(DEPTH)
) (
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,

    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,

    output wire [ADDR_WIDTH:0]   count
);

// clog2 function
    function integer clog2;
        input integer value;
        integer temp;
        begin
            temp = value - 1;
            for (clog2 = 0; temp > 0; clog2 = clog2 + 1)
                temp = temp >> 1;
        end
    endfunction

    reg [DATA_WIDTH-1:0] mem     [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count_r;  

    assign count    = count_r;
    assign wr_full  = (count_r == DEPTH);
    assign rd_empty = (count_r == 0);

    wire do_write = wr_en && !wr_full;
    wire do_read  = rd_en && !rd_empty;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr  <= {ADDR_WIDTH{1'b0}};
            rd_ptr  <= {ADDR_WIDTH{1'b0}};
            count_r <= {(ADDR_WIDTH+1){1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            
            // Write operation
            if (do_write) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= (wr_ptr == DEPTH-1) ? {ADDR_WIDTH{1'b0}} : wr_ptr + 1'b1;
            end

            // Read operation
            if (do_read) begin
                rd_data <= mem[rd_ptr];
                rd_ptr  <= (rd_ptr == DEPTH-1) ? {ADDR_WIDTH{1'b0}} : rd_ptr + 1'b1;
            end

            // counter update
            if      (do_write && !do_read) count_r <= count_r + 1'b1;
            else if (do_read  && !do_write) count_r <= count_r - 1'b1;
        end
    end

endmodule
