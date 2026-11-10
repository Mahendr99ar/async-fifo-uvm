`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// async_fifo : dual-clock FIFO with Gray-code pointer synchronization
//
//  * Depth  = 2**ASIZE entries, width = DSIZE bits
//  * Pointers are ASIZE+1 bits (extra MSB distinguishes full from empty)
//  * Write pointer is synchronized into rclk domain, read pointer into wclk
//  * Show-ahead read: rdata is valid whenever rempty == 0; rinc pops it
//  * Writes when full and reads when empty are ignored (overflow/underflow safe)
//
//  Reference: C. Cummings, "Simulation and Synthesis Techniques for
//  Asynchronous FIFO Design", SNUG 2002.
// -----------------------------------------------------------------------------
module async_fifo #(
  parameter int DSIZE = 8,
  parameter int ASIZE = 4
) (
  // write domain
  input  logic             wclk,
  input  logic             wrst_n,
  input  logic             winc,
  input  logic [DSIZE-1:0] wdata,
  output logic             wfull,
  // read domain
  input  logic             rclk,
  input  logic             rrst_n,
  input  logic             rinc,
  output logic [DSIZE-1:0] rdata,
  output logic             rempty
);

  localparam int DEPTH = 1 << ASIZE;

  logic [DSIZE-1:0] mem [0:DEPTH-1];

  // binary and gray pointers
  logic [ASIZE:0] wbin, wptr, wbinnext, wgraynext;
  logic [ASIZE:0] rbin, rptr, rbinnext, rgraynext;
  // synchronized pointers
  logic [ASIZE:0] wq2_rptr;   // read ptr seen in write domain
  logic [ASIZE:0] rq2_wptr;   // write ptr seen in read domain

  logic wfull_val, rempty_val;

  // ---------------------------------------------------------------------------
  // Write domain
  // ---------------------------------------------------------------------------
  assign wbinnext  = wbin + {{ASIZE{1'b0}}, (winc & ~wfull)};
  assign wgraynext = (wbinnext >> 1) ^ wbinnext;

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin <= '0;
      wptr <= '0;
    end else begin
      wbin <= wbinnext;
      wptr <= wgraynext;
    end
  end

  // Full: next gray write ptr equals sync'd read ptr with the two MSBs inverted
  assign wfull_val = (wgraynext == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) wfull <= 1'b0;
    else         wfull <= wfull_val;
  end

  always_ff @(posedge wclk) begin
    if (winc && !wfull) mem[wbin[ASIZE-1:0]] <= wdata;
  end

  // ---------------------------------------------------------------------------
  // Read domain
  // ---------------------------------------------------------------------------
  assign rbinnext  = rbin + {{ASIZE{1'b0}}, (rinc & ~rempty)};
  assign rgraynext = (rbinnext >> 1) ^ rbinnext;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin <= '0;
      rptr <= '0;
    end else begin
      rbin <= rbinnext;
      rptr <= rgraynext;
    end
  end

  // Empty: next gray read ptr equals sync'd write ptr
  assign rempty_val = (rgraynext == rq2_wptr);

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) rempty <= 1'b1;
    else         rempty <= rempty_val;
  end

  assign rdata = mem[rbin[ASIZE-1:0]];

  // ---------------------------------------------------------------------------
  // Clock-domain crossing synchronizers
  // ---------------------------------------------------------------------------
  sync_2ff #(.WIDTH(ASIZE+1)) u_sync_r2w (
    .clk(wclk), .rst_n(wrst_n), .d(rptr), .q(wq2_rptr)
  );

  sync_2ff #(.WIDTH(ASIZE+1)) u_sync_w2r (
    .clk(rclk), .rst_n(rrst_n), .d(wptr), .q(rq2_wptr)
  );

endmodule
