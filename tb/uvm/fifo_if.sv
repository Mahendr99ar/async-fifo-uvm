`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// fifo_if : interface with separate clocking blocks per clock domain
//   *_drv_cb : used by drivers   (outputs driven 1ns after the edge)
//   *_mon_cb : used by monitors  (inputs sampled just before the edge)
// -----------------------------------------------------------------------------
interface fifo_if #(parameter int DSIZE = 8) (input logic wclk, input logic rclk);

  logic             wrst_n, rrst_n;
  logic             winc,   rinc;
  logic [DSIZE-1:0] wdata,  rdata;
  logic             wfull,  rempty;

  // ---------------- write domain ----------------
  clocking wdrv_cb @(posedge wclk);
    default input #1step output #1;
    output winc, wdata;
    input  wfull;
  endclocking

  clocking wmon_cb @(posedge wclk);
    default input #1step;
    input winc, wdata, wfull;
  endclocking

  // ---------------- read domain ----------------
  clocking rdrv_cb @(posedge rclk);
    default input #1step output #1;
    output rinc;
    input  rempty;
  endclocking

  clocking rmon_cb @(posedge rclk);
    default input #1step;
    input rinc, rdata, rempty;
  endclocking

endinterface
