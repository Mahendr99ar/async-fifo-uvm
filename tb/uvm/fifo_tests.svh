// -----------------------------------------------------------------------------
// Tests
//   fifo_random_test : balanced random traffic
//   fifo_full_test   : fast writer, slow reader  -> exercises FULL / overflow
//   fifo_empty_test  : slow writer, fast reader  -> exercises EMPTY / underflow
// Run with: +UVM_TESTNAME=<test>  (clock ratio via +WCLK_PERIOD / +RCLK_PERIOD)
// -----------------------------------------------------------------------------
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)

  fifo_env env;

  int unsigned n_items  = 500;
  int unsigned wr_min = 0, wr_max = 3;
  int unsigned rd_min = 0, rd_max = 3;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = fifo_env::type_id::create("env", this);
    if ($value$plusargs("N_ITEMS=%d", n_items))
      `uvm_info("TEST", $sformatf("N_ITEMS overridden to %0d", n_items), UVM_LOW)
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    wr_seq ws;
    rd_seq rs;
    int unsigned waited = 0;

    phase.raise_objection(this);

    ws = wr_seq::type_id::create("ws");
    rs = rd_seq::type_id::create("rs");
    ws.n_items   = n_items;
    ws.min_delay = wr_min;  ws.max_delay = wr_max;
    rs.min_delay = rd_min;  rs.max_delay = rd_max;

    `uvm_info("TEST", $sformatf("%s: %0d writes, wr_delay=[%0d:%0d] rd_delay=[%0d:%0d]",
              get_type_name(), n_items, wr_min, wr_max, rd_min, rd_max), UVM_LOW)

    fork
      rs.start(env.ragt.sqr);          // reader runs in background
    join_none

    ws.start(env.wagt.sqr);            // all writes issued

    // drain: wait until every accepted write has been read back
    while (env.sb.pending() != 0 && waited < 100000) begin
      #10ns;
      waited++;
    end
    if (env.sb.pending() != 0)
      `uvm_error("TEST", "timeout waiting for FIFO to drain")

    #200ns;
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    uvm_report_server rs = uvm_report_server::get_server();
    int errs = rs.get_severity_count(UVM_ERROR) + rs.get_severity_count(UVM_FATAL);
    $display("\n==============================================");
    $display("  %s : %s", get_type_name(), (errs == 0) ? "PASSED" : "FAILED");
    $display("==============================================\n");
  endfunction
endclass

class fifo_random_test extends fifo_base_test;
  `uvm_component_utils(fifo_random_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class fifo_full_test extends fifo_base_test;
  `uvm_component_utils(fifo_full_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    wr_min = 0; wr_max = 0;    // write every cycle
    rd_min = 3; rd_max = 8;    // read slowly
  endfunction
endclass

class fifo_empty_test extends fifo_base_test;
  `uvm_component_utils(fifo_empty_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    wr_min = 3; wr_max = 8;    // write slowly
    rd_min = 0; rd_max = 0;    // read every cycle
  endfunction
endclass
