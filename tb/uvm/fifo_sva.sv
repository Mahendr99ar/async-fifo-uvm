`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// fifo_sva : protocol / implementation assertions, bound into async_fifo
// -----------------------------------------------------------------------------
module fifo_sva #(
  parameter int ASIZE = 4
) (
  input logic           wclk, wrst_n, winc, wfull,
  input logic [ASIZE:0] wptr, wbin,
  input logic           rclk, rrst_n, rinc, rempty,
  input logic [ASIZE:0] rptr, rbin
);

  // Gray pointers may change by at most one bit per clock (CDC safety)
  a_wptr_gray: assert property (@(posedge wclk) disable iff (!wrst_n)
    $onehot0(wptr ^ $past(wptr)))
    else $error("SVA: write gray pointer changed more than one bit");

  a_rptr_gray: assert property (@(posedge rclk) disable iff (!rrst_n)
    $onehot0(rptr ^ $past(rptr)))
    else $error("SVA: read gray pointer changed more than one bit");

  // Overflow protection: a write while full must not advance the pointer
  a_no_write_when_full: assert property (@(posedge wclk) disable iff (!wrst_n)
    (winc && wfull) |=> $stable(wbin))
    else $error("SVA: write pointer advanced while FIFO full");

  // Underflow protection: a read while empty must not advance the pointer
  a_no_read_when_empty: assert property (@(posedge rclk) disable iff (!rrst_n)
    (rinc && rempty) |=> $stable(rbin))
    else $error("SVA: read pointer advanced while FIFO empty");

  // Coverage of interesting events
  // NOTE: Vivado xsim ignores `cover property` (warning XSIM 43-4127); these
  // are kept for commercial simulators / formal. The same scenarios are
  // covered in xsim by the monitor covergroups (winc x wfull, rinc x rempty).
  c_full_seen:        cover property (@(posedge wclk) disable iff (!wrst_n) $rose(wfull));
  c_write_when_full:  cover property (@(posedge wclk) disable iff (!wrst_n) winc && wfull);
  c_empty_after_data: cover property (@(posedge rclk) disable iff (!rrst_n) $rose(rempty));
  c_read_when_empty:  cover property (@(posedge rclk) disable iff (!rrst_n) rinc && rempty);

endmodule

// Attach the checker to every async_fifo instance (connects by signal name)
bind async_fifo fifo_sva #(.ASIZE(ASIZE)) u_fifo_sva (.*);
