// -----------------------------------------------------------------------------
// Environment
// -----------------------------------------------------------------------------
class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)

  wr_agent        wagt;
  rd_agent        ragt;
  fifo_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wagt = wr_agent       ::type_id::create("wagt", this);
    ragt = rd_agent       ::type_id::create("ragt", this);
    sb   = fifo_scoreboard::type_id::create("sb",   this);
  endfunction

  function void connect_phase(uvm_phase phase);
    wagt.mon.ap.connect(sb.wr_imp);
    ragt.mon.ap.connect(sb.rd_imp);
  endfunction
endclass
