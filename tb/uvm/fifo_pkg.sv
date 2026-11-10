`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// fifo_pkg : all UVM classes for the async FIFO testbench
// -----------------------------------------------------------------------------
package fifo_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter int DSIZE = 8;
  parameter int ASIZE = 4;

  `include "fifo_items.svh"
  `include "fifo_wr_agent.svh"
  `include "fifo_rd_agent.svh"
  `include "fifo_scoreboard.svh"
  `include "fifo_env.svh"
  `include "fifo_seqs.svh"
  `include "fifo_tests.svh"
endpackage
