`timescale 1ns/1ps
 
module tb_sync_fifo;
 
    // Parameters
    parameter integer DATA_WIDTH = 8;
    parameter integer DEPTH      = 16;
    parameter integer ADDR_WIDTH = 4;
 
    reg                   clk;
    reg                   rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    wire                  wr_full;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  rd_empty;
    wire [ADDR_WIDTH:0]   count;
 
    integer cycle;
    integer seed;
    integer idx;
    integer model_wr_ptr;
    integer model_rd_ptr;
    integer model_count;
 
    reg [DATA_WIDTH-1:0] model_mem     [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] model_rd_data;
    reg [DATA_WIDTH-1:0] write_queue   [0:DEPTH-1];
 
    integer cov_full;
    integer cov_empty;
    integer cov_wrap;
    integer cov_simul;
    integer cov_overflow;
    integer cov_underflow;
 
    // DUT instantiation
    sync_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .wr_full  (wr_full),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .rd_empty (rd_empty),
        .count    (count)
    );
 
    // Clock generation ? 10 ns period (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;
 
    // Initialise bookkeeping variables
    initial begin
        cycle = 0;
        seed  = 42;
    end
 
    always @(posedge clk) cycle = cycle + 1;
 
     // Golden Reference Model
     always @(posedge clk) begin
        if (!rst_n) begin
            model_wr_ptr  = 0;
            model_rd_ptr  = 0;
            model_count   = 0;
            model_rd_data = 0;
        end else begin
            // Write 
            if (wr_en && (model_count < DEPTH)) begin
                model_mem[model_wr_ptr] = wr_data;
                model_wr_ptr = (model_wr_ptr == DEPTH-1) ? 0 : model_wr_ptr + 1;
            end
            // Read 
            if (rd_en && (model_count > 0)) begin
                model_rd_data = model_mem[model_rd_ptr];
                model_rd_ptr  = (model_rd_ptr == DEPTH-1) ? 0 : model_rd_ptr + 1;
            end
            // Count update
            if      ((wr_en && model_count < DEPTH) && !(rd_en && model_count > 0))
                model_count = model_count + 1;
            else if ((rd_en && model_count > 0) && !(wr_en && model_count < DEPTH))
                model_count = model_count - 1;
        end
    end
 
    // Coverage counter initialisation
     initial begin
        cov_full      = 0;
        cov_empty     = 0;
        cov_wrap      = 0;
        cov_simul     = 0;
        cov_overflow  = 0;
        cov_underflow = 0;
    end
 
    // Coverage tracking
     always @(posedge clk) begin
        if (rst_n) begin
            if (count == DEPTH)
                cov_full = cov_full + 1;
            if (count == 0)
                cov_empty = cov_empty + 1;
            if (wr_en && wr_full)
                cov_overflow = cov_overflow + 1;
            if (rd_en && rd_empty)
                cov_underflow = cov_underflow + 1;
            if (wr_en && !wr_full && rd_en && !rd_empty)
                cov_simul = cov_simul + 1;
            if (wr_en && !wr_full && (dut.u_fifo.wr_ptr == DEPTH-1))
                cov_wrap = cov_wrap + 1;
        end
    end
 
    // Scoreboard Task
    task scoreboard_check;
        input [255:0] test_name;
        begin
            #1;
 
            if (rd_en && !rd_empty) begin
                if (rd_data !== model_rd_data) begin
                    $display("============================================================");
                    $display("SCOREBOARD ERROR  time=%0t  cycle=%0d", $time, cycle);
                    $display("  Test     : %s", test_name);
                    $display("  Signal   : rd_data");
                    $display("  Expected : 0x%0h  (%0d)", model_rd_data, model_rd_data);
                    $display("  Got      : 0x%0h  (%0d)", rd_data, rd_data);
                    $display("  Inputs   : wr_en=%b  wr_data=0x%0h  rd_en=%b",
                             wr_en, wr_data, rd_en);
                    $display("  Model    : wr_ptr=%0d  rd_ptr=%0d  count=%0d",
                             model_wr_ptr, model_rd_ptr, model_count);
                    $display("  Seed     : %0d", seed);
                    $display("============================================================");
                    $finish;
                end
            end
 
            if (count !== model_count) begin
                $display("============================================================");
                $display("SCOREBOARD ERROR  time=%0t  cycle=%0d", $time, cycle);
                $display("  Test     : %s", test_name);
                $display("  Signal   : count");
                $display("  Expected : %0d", model_count);
                $display("  Got      : %0d", count);
                $display("  Inputs   : wr_en=%b  wr_data=0x%0h  rd_en=%b",
                         wr_en, wr_data, rd_en);
                $display("  Model    : wr_ptr=%0d  rd_ptr=%0d  count=%0d",
                         model_wr_ptr, model_rd_ptr, model_count);
                $display("  Seed     : %0d", seed);
                $display("============================================================");
                $finish;
            end
 
            if (rd_empty !== (model_count == 0)) begin
                $display("============================================================");
                $display("SCOREBOARD ERROR  time=%0t  cycle=%0d", $time, cycle);
                $display("  Test     : %s", test_name);
                $display("  Signal   : rd_empty");
                $display("  Expected : %b  (model_count=%0d)",
                         (model_count == 0), model_count);
                $display("  Got      : %b", rd_empty);
                $display("  Inputs   : wr_en=%b  wr_data=0x%0h  rd_en=%b",
                         wr_en, wr_data, rd_en);
                $display("  Model    : wr_ptr=%0d  rd_ptr=%0d  count=%0d",
                         model_wr_ptr, model_rd_ptr, model_count);
                $display("  Seed     : %0d", seed);
                $display("============================================================");
                $finish;
            end
 
            if (wr_full !== (model_count == DEPTH)) begin
                $display("============================================================");
                $display("SCOREBOARD ERROR  time=%0t  cycle=%0d", $time, cycle);
                $display("  Test     : %s", test_name);
                $display("  Signal   : wr_full");
                $display("  Expected : %b  (model_count=%0d  DEPTH=%0d)",
                         (model_count == DEPTH), model_count, DEPTH);
                $display("  Got      : %b", wr_full);
                $display("  Inputs   : wr_en=%b  wr_data=0x%0h  rd_en=%b",
                         wr_en, wr_data, rd_en);
                $display("  Model    : wr_ptr=%0d  rd_ptr=%0d  count=%0d",
                         model_wr_ptr, model_rd_ptr, model_count);
                $display("  Seed     : %0d", seed);
                $display("============================================================");
                $finish;
            end
        end
    endtask
 
    // Helper Tasks
    task apply_reset;
        input [31:0] n;
        begin
            rst_n   = 0;
            wr_en   = 0;
            rd_en   = 0;
            wr_data = 0;
            repeat (n) @(posedge clk);
            @(negedge clk);
            rst_n = 1;
            @(posedge clk);
            scoreboard_check("apply_reset");
        end
    endtask
 
    task do_write;
        input [DATA_WIDTH-1:0] data;
        input [255:0]          test_name;
        begin
            @(negedge clk);
            wr_en   = 1;
            wr_data = data;
            rd_en   = 0;
            @(posedge clk);
            scoreboard_check(test_name);
            @(negedge clk);
            wr_en   = 0;
            wr_data = 0;
        end
    endtask
 
    task do_read;
        input [255:0] test_name;
        begin
            @(negedge clk);
            rd_en = 1;
            wr_en = 0;
            @(posedge clk);
            scoreboard_check(test_name);
            @(negedge clk);
            rd_en = 0;
        end
    endtask
 
    task idle;
        input [31:0] n;
        begin
            @(negedge clk);
            wr_en = 0;
            rd_en = 0;
            repeat (n) @(posedge clk);
        end
    endtask
 
    // Main Test Sequence
     initial begin
        // Initialise all driven signals before clock starts
        rst_n   = 0;
        wr_en   = 0;
        rd_en   = 0;
        wr_data = 0;
 
        $display("====================================================");
        $display("  Synchronous FIFO Testbench");
        $display("  DATA_WIDTH=%0d  DEPTH=%0d  ADDR_WIDTH=%0d  Seed=%0d",
                 DATA_WIDTH, DEPTH, ADDR_WIDTH, seed);
        $display("====================================================");
 
        // TEST 1: Reset Test
         $display("\n[TEST 1] Reset Test");
        apply_reset(4);
        idle(2);
 
        if (count    !== 0) begin $display("FAIL [TEST 1]: count=%0d expected 0",   count);    $finish; end
        if (rd_empty !== 1) begin $display("FAIL [TEST 1]: rd_empty=%b expected 1", rd_empty); $finish; end
        if (wr_full  !== 0) begin $display("FAIL [TEST 1]: wr_full=%b expected 0",  wr_full);  $finish; end
        $display("[TEST 1] PASS - count=%0d  rd_empty=%b  wr_full=%b",
                 count, rd_empty, wr_full);
 
        // TEST 2: Single Write / Read Test
         $display("\n[TEST 2] Single Write / Read Test");
        apply_reset(2);
 
        do_write(8'hA5, "SingleWriteRead");
        if (count    !== 1) begin $display("FAIL [TEST 2]: count=%0d after write expected 1",   count);    $finish; end
        if (rd_empty !== 0) begin $display("FAIL [TEST 2]: rd_empty=%b after write expected 0", rd_empty); $finish; end
        if (wr_full  !== 0) begin $display("FAIL [TEST 2]: wr_full=%b after write expected 0",  wr_full);  $finish; end
 
        do_read("SingleWriteRead");
        if (rd_data  !== 8'hA5) begin $display("FAIL [TEST 2]: rd_data=0x%0h expected 0xA5",    rd_data);  $finish; end
        if (count    !== 0)     begin $display("FAIL [TEST 2]: count=%0d after read expected 0", count);    $finish; end
        if (rd_empty !== 1)     begin $display("FAIL [TEST 2]: rd_empty=%b after read expected 1",rd_empty);$finish; end
        $display("[TEST 2] PASS - wrote 0xA5, read back 0x%0h, count=%0d", rd_data, count);
 
        // TEST 3: Fill Test
        $display("\n[TEST 3] Fill Test");
        apply_reset(2);
 
        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            write_queue[idx] = 8'h10 + idx[DATA_WIDTH-1:0];
            do_write(write_queue[idx], "FillTest");
        end
 
        if (count   !== DEPTH) begin $display("FAIL [TEST 3]: count=%0d expected %0d", count, DEPTH); $finish; end
        if (wr_full !== 1)     begin $display("FAIL [TEST 3]: wr_full=%b expected 1",  wr_full);       $finish; end
        $display("[TEST 3] PASS - FIFO full: count=%0d  wr_full=%b", count, wr_full);
 
        // TEST 4: Drain Test
        $display("\n[TEST 4] Drain Test");
 
        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            do_read("DrainTest");
            if (rd_data !== write_queue[idx]) begin
                $display("FAIL [TEST 4]: idx=%0d  rd_data=0x%0h  expected=0x%0h",
                         idx, rd_data, write_queue[idx]);
                $finish;
            end
        end
 
        if (count    !== 0) begin $display("FAIL [TEST 4]: count=%0d expected 0",   count);    $finish; end
        if (rd_empty !== 1) begin $display("FAIL [TEST 4]: rd_empty=%b expected 1", rd_empty); $finish; end
        $display("[TEST 4] PASS - all %0d entries drained in order, count=%0d  rd_empty=%b",
                 DEPTH, count, rd_empty);
 
        // TEST 5: Overflow Attempt Test
        $display("\n[TEST 5] Overflow Attempt Test");
        apply_reset(2);
 
        for (idx = 0; idx < DEPTH; idx = idx + 1)
            do_write(8'hCC, "OverflowTest-Fill");
 
        @(negedge clk); wr_en = 1; wr_data = 8'hFF; rd_en = 0;
        @(posedge clk); scoreboard_check("OverflowTest-Attempt1");
        @(negedge clk); wr_en = 1; wr_data = 8'hEE;
        @(posedge clk); scoreboard_check("OverflowTest-Attempt2");
        @(negedge clk); wr_en = 0; wr_data = 0;
 
        if (count   !== DEPTH) begin $display("FAIL [TEST 5]: count=%0d expected %0d", count, DEPTH); $finish; end
        if (wr_full !== 1)     begin $display("FAIL [TEST 5]: wr_full=%b expected 1",  wr_full);       $finish; end
        $display("[TEST 5] PASS - overflow blocked: count=%0d  wr_full=%b", count, wr_full);
 
        // TEST 6: Underflow Attempt Test
        $display("\n[TEST 6] Underflow Attempt Test");
        apply_reset(2);
 
        @(negedge clk); rd_en = 1; wr_en = 0;
        @(posedge clk); scoreboard_check("UnderflowTest-Attempt1");
        @(negedge clk); rd_en = 1;
        @(posedge clk); scoreboard_check("UnderflowTest-Attempt2");
        @(negedge clk); rd_en = 0;
 
        if (count    !== 0) begin $display("FAIL [TEST 6]: count=%0d expected 0",   count);    $finish; end
        if (rd_empty !== 1) begin $display("FAIL [TEST 6]: rd_empty=%b expected 1", rd_empty); $finish; end
        $display("[TEST 6] PASS - underflow blocked: count=%0d  rd_empty=%b", count, rd_empty);
 
        // TEST 7: Simultaneous Read / Write Test
        $display("\n[TEST 7] Simultaneous Read / Write Test");
        apply_reset(2);
 
        for (idx = 0; idx < 8; idx = idx + 1) begin
            write_queue[idx] = 8'h30 + idx[DATA_WIDTH-1:0];
            do_write(write_queue[idx], "SimulTest-Fill");
        end
 
        if (count !== 8) begin $display("FAIL [TEST 7]: count=%0d after fill expected 8", count); $finish; end
 
        for (idx = 0; idx < 8; idx = idx + 1) begin
            @(negedge clk);
            wr_en   = 1;
            wr_data = 8'hA0 + idx[DATA_WIDTH-1:0];
            rd_en   = 1;
            @(posedge clk);
            scoreboard_check("SimulTest-RW");
            if (rd_data !== write_queue[idx]) begin
                $display("FAIL [TEST 7]: idx=%0d  rd_data=0x%0h  expected=0x%0h",
                         idx, rd_data, write_queue[idx]);
                $finish;
            end
            @(negedge clk);
            wr_en = 0; rd_en = 0;
        end
 
        if (count !== 8) begin $display("FAIL [TEST 7]: count=%0d expected 8", count); $finish; end
        $display("[TEST 7] PASS - 8 simultaneous R/W cycles, count stayed at %0d", count);
 
        // TEST 8: Pointer Wrap-Around Test
        $display("\n[TEST 8] Pointer Wrap-Around Test");
        apply_reset(2);
 
        for (idx = 0; idx < DEPTH-4; idx = idx + 1)
            do_write(8'h00 + idx[DATA_WIDTH-1:0], "WrapTest-Advance");
        for (idx = 0; idx < DEPTH-4; idx = idx + 1)
            do_read("WrapTest-Advance");
 
        if (count !== 0) begin $display("FAIL [TEST 8]: count=%0d after advance+drain expected 0", count); $finish; end
 
        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            write_queue[idx] = 8'hB0 + idx[DATA_WIDTH-1:0];
            do_write(write_queue[idx], "WrapTest-Write");
        end
 
        if (count   !== DEPTH) begin $display("FAIL [TEST 8]: count=%0d expected %0d", count, DEPTH); $finish; end
        if (wr_full !== 1)     begin $display("FAIL [TEST 8]: wr_full=%b expected 1",  wr_full);       $finish; end
 
        for (idx = 0; idx < DEPTH; idx = idx + 1) begin
            do_read("WrapTest-Read");
            if (rd_data !== write_queue[idx]) begin
                $display("FAIL [TEST 8]: idx=%0d  rd_data=0x%0h  expected=0x%0h",
                         idx, rd_data, write_queue[idx]);
                $finish;
            end
        end
 
        if (count    !== 0) begin $display("FAIL [TEST 8]: count=%0d expected 0",   count);    $finish; end
        if (rd_empty !== 1) begin $display("FAIL [TEST 8]: rd_empty=%b expected 1", rd_empty); $finish; end
        $display("[TEST 8] PASS - pointer wrap-around: data integrity preserved, count=%0d", count);
 
        // Coverage report
        idle(4);
        $display("\n====================================================");
        $display("  Coverage Summary");
        $display("====================================================");
        $display("  cov_full      = %0d  (cycles FIFO was full)",          cov_full);
        $display("  cov_empty     = %0d  (cycles FIFO was empty)",         cov_empty);
        $display("  cov_wrap      = %0d  (wr_ptr wrap-around events)",     cov_wrap);
        $display("  cov_simul     = %0d  (valid simultaneous R/W cycles)", cov_simul);
        $display("  cov_overflow  = %0d  (write attempts while full)",     cov_overflow);
        $display("  cov_underflow = %0d  (read attempts while empty)",     cov_underflow);
        $display("====================================================");
 
        if (cov_full      == 0) $display("WARNING: cov_full never triggered");
        if (cov_empty     == 0) $display("WARNING: cov_empty never triggered");
        if (cov_wrap      == 0) $display("WARNING: cov_wrap never triggered");
        if (cov_simul     == 0) $display("WARNING: cov_simul never triggered");
        if (cov_overflow  == 0) $display("WARNING: cov_overflow never triggered");
        if (cov_underflow == 0) $display("WARNING: cov_underflow never triggered");
 
        if (cov_full > 0 && cov_empty > 0 && cov_wrap > 0 &&
            cov_simul > 0 && cov_overflow > 0 && cov_underflow > 0)
            $display("\n  ALL COVERAGE BINS HIT - adequate coverage achieved");
 
        $display("\n====================================================");
        $display("  ALL 8 TESTS PASSED");
        $display("====================================================\n");
        $finish;
    end
 
    // Timeout watchdog
    initial begin
        #1000000;
        $display("ERROR: Simulation timeout at time %0t", $time);
        $finish;
    end
 
endmodule
