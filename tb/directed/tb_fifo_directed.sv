// -----------------------------------------------------------------------------
// tb_fifo_directed : lightweight self-checking testbench (no UVM)
//
// Runs on free simulators (Icarus Verilog) so GitHub Actions can check every
// push. The full constrained-random UVM environment lives in tb/uvm/.
//
//   Test 1: fill until full, try an extra write (must be dropped), drain all
//   Test 2: read from empty FIFO (must be ignored)
//   Test 3: concurrent random writes/reads with a reference model
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_fifo_directed;

  localparam int DSIZE = 8;
  localparam int ASIZE = 4;
  localparam int DEPTH = 1 << ASIZE;
  localparam int N_RANDOM = 2000;

  logic             wclk = 0, rclk = 0;
  logic             wrst_n, rrst_n;
  logic             winc, rinc;
  logic [DSIZE-1:0] wdata, rdata;
  logic             wfull, rempty;

  // Non-integer clock ratio to stress the CDC logic
  always #5   wclk = ~wclk;   // 100 MHz
  always #8.5 rclk = ~rclk;   // ~58.8 MHz

  async_fifo #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (.*);

  // ---------------- reference model (circular buffer) ----------------
  logic [DSIZE-1:0] model [0:4095];
  int wr_idx = 0, rd_idx = 0;
  int errors = 0, n_reads = 0;
  int wr_done = 0;

  // Record every accepted write
  always @(posedge wclk) if (wrst_n && winc && !wfull) begin
    model[wr_idx % 4096] = wdata;
    wr_idx++;
  end

  // Check every accepted read
  always @(posedge rclk) if (rrst_n && rinc && !rempty) begin
    if (rd_idx >= wr_idx) begin
      $display("ERROR: read with no data written (t=%0t)", $time);
      errors++;
    end else if (rdata !== model[rd_idx % 4096]) begin
      $display("ERROR: data mismatch exp=%h got=%h (t=%0t)",
               model[rd_idx % 4096], rdata, $time);
      errors++;
    end
    rd_idx++;
    n_reads++;
  end

  task automatic write_one(input logic [DSIZE-1:0] d);
    @(negedge wclk); winc = 1; wdata = d;
    @(negedge wclk); winc = 0;
  endtask

  task automatic read_one();
    @(negedge rclk); rinc = 1;
    @(negedge rclk); rinc = 0;
  endtask

  initial begin
    winc = 0; rinc = 0; wdata = 0;
    wrst_n = 0; rrst_n = 0;
    repeat (4) @(posedge wclk);
    wrst_n = 1; rrst_n = 1;
    repeat (4) @(posedge rclk);

    // ---------------- Test 1: fill, overflow, drain ----------------
    $display("[T1] fill to full");
    for (int i = 0; i < DEPTH; i++) write_one(8'hA0 + i);
    @(negedge wclk);
    if (!wfull) begin $display("ERROR: wfull not set after %0d writes", DEPTH); errors++; end
    write_one(8'hFF);                       // must be dropped
    if (wr_idx != DEPTH) begin $display("ERROR: write accepted while full"); errors++; end

    $display("[T1] drain");
    while (!rempty || rd_idx < wr_idx) begin
      if (!rempty) read_one(); else @(negedge rclk);
    end
    repeat (6) @(negedge rclk);
    if (!rempty) begin $display("ERROR: rempty not set after drain"); errors++; end

    // ---------------- Test 2: underflow ----------------
    $display("[T2] read while empty");
    read_one();
    if (rd_idx != wr_idx) begin $display("ERROR: read accepted while empty"); errors++; end

    // ---------------- Test 3: concurrent random traffic ----------------
    $display("[T3] %0d random concurrent writes/reads", N_RANDOM);
    fork
      begin : writer
        for (int i = 0; i < N_RANDOM; i++) begin
          @(negedge wclk);
          winc  = ($urandom_range(0, 3) != 0);   // ~75% write attempts
          wdata = $urandom;
        end
        @(negedge wclk); winc = 0;
        wr_done = 1;
      end
      begin : reader
        while (!wr_done || rd_idx < wr_idx) begin
          @(negedge rclk);
          rinc = ($urandom_range(0, 3) != 0);
        end
        @(negedge rclk); rinc = 0;
      end
    join

    repeat (10) @(posedge rclk);
    $display("--------------------------------------------");
    $display(" writes accepted : %0d", wr_idx);
    $display(" reads checked   : %0d", n_reads);
    $display(" errors          : %0d", errors);
    if (errors == 0 && rd_idx == wr_idx) $display(" RESULT: PASS");
    else                                  $display(" RESULT: FAIL");
    $display("--------------------------------------------");
    $finish;
  end

  // Watchdog
  initial begin
    #5ms;
    $display("ERROR: timeout");
    $display(" RESULT: FAIL");
    $finish;
  end

endmodule
