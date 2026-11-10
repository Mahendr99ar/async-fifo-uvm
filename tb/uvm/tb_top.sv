// -----------------------------------------------------------------------------
// tb_top : clocks, resets, DUT, interface, UVM launch
//   +WCLK_PERIOD=<ns>  (default 10)
//   +RCLK_PERIOD=<ns>  (default 17)  -> try fast-write/slow-read and vice versa
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import fifo_pkg::*;
  `include "uvm_macros.svh"

  logic wclk = 0, rclk = 0;
  int   wclk_period = 10;
  int   rclk_period = 17;

  initial begin
    if ($value$plusargs("WCLK_PERIOD=%d", wclk_period)) $display("tb_top: WCLK_PERIOD overridden");
    if ($value$plusargs("RCLK_PERIOD=%d", rclk_period)) $display("tb_top: RCLK_PERIOD overridden");
    $display("tb_top: wclk=%0dns rclk=%0dns", wclk_period, rclk_period);
    fork
      forever #(wclk_period / 2.0) wclk = ~wclk;
      forever #(rclk_period / 2.0) rclk = ~rclk;
    join
  end

  fifo_if #(.DSIZE(DSIZE)) vif (.wclk(wclk), .rclk(rclk));

  async_fifo #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (
    .wclk  (wclk),       .wrst_n(vif.wrst_n),
    .winc  (vif.winc),   .wdata (vif.wdata),   .wfull (vif.wfull),
    .rclk  (rclk),       .rrst_n(vif.rrst_n),
    .rinc  (vif.rinc),   .rdata (vif.rdata),   .rempty(vif.rempty)
  );

  // Independent resets for each domain
  initial begin
    vif.wrst_n = 0;
    vif.rrst_n = 0;
    repeat (5) @(posedge wclk);
    vif.wrst_n = 1;
    repeat (5) @(posedge rclk);
    vif.rrst_n = 1;
  end

  initial begin
    uvm_config_db#(virtual fifo_if)::set(null, "uvm_test_top.*", "vif", vif);
    run_test("fifo_random_test");
  end

  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
