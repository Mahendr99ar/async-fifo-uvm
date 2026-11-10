// -----------------------------------------------------------------------------
// Scoreboard : in-order reference model
//   write side -> push expected data
//   read side  -> pop and compare
// -----------------------------------------------------------------------------
`uvm_analysis_imp_decl(_wr)
`uvm_analysis_imp_decl(_rd)

class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp_wr #(wr_item, fifo_scoreboard) wr_imp;
  uvm_analysis_imp_rd #(rd_item, fifo_scoreboard) rd_imp;

  bit [DSIZE-1:0] exp_q[$];
  int unsigned    n_match, n_mismatch, max_occupancy;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wr_imp = new("wr_imp", this);
    rd_imp = new("rd_imp", this);
  endfunction

  function void write_wr(wr_item t);
    exp_q.push_back(t.data);
    if (exp_q.size() > max_occupancy) max_occupancy = exp_q.size();
  endfunction

  function void write_rd(rd_item t);
    bit [DSIZE-1:0] exp;
    if (exp_q.size() == 0) begin
      `uvm_error("SB", $sformatf("read data %0h but no write was expected", t.data))
      n_mismatch++;
      return;
    end
    exp = exp_q.pop_front();
    if (t.data !== exp) begin
      `uvm_error("SB", $sformatf("MISMATCH expected=%0h got=%0h", exp, t.data))
      n_mismatch++;
    end else begin
      n_match++;
    end
  endfunction

  function int unsigned pending();
    return exp_q.size();
  endfunction

  function void check_phase(uvm_phase phase);
    if (exp_q.size() != 0)
      `uvm_error("SB", $sformatf("%0d writes were never read back", exp_q.size()))
    if (n_match == 0)
      `uvm_error("SB", "no transactions were checked")
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB", $sformatf("matches=%0d mismatches=%0d peak_occupancy(model)=%0d",
              n_match, n_mismatch, max_occupancy), UVM_LOW)
  endfunction
endclass
