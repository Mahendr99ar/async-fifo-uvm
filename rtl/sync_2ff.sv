`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// sync_2ff : 2-flop synchronizer for a multi-bit Gray-coded bus
//
// Safe ONLY because the input is Gray coded (at most one bit changes per
// source clock), so a metastable sample resolves to either the old or the
// new value - never to an illegal value.
// -----------------------------------------------------------------------------
module sync_2ff #(
  parameter int WIDTH = 5
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);

  logic [WIDTH-1:0] meta;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      meta <= '0;
      q    <= '0;
    end else begin
      meta <= d;
      q    <= meta;
    end
  end

endmodule
