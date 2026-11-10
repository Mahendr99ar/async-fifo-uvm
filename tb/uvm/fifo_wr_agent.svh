// -----------------------------------------------------------------------------
// Write agent : sequencer + driver + monitor (wclk domain)
// -----------------------------------------------------------------------------

typedef uvm_sequencer #(wr_item) wr_sequencer;

// Drives winc/wdata. It does NOT look at wfull on purpose, so tests can
// attempt writes while full and check that the DUT drops them.
class wr_driver extends uvm_driver #(wr_item);
  `uvm_component_utils(wr_driver)

  virtual fifo_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface not set for wr_driver")
  endfunction

  task run_phase(uvm_phase phase);
    vif.winc  <= 1'b0;
    vif.wdata <= '0;
    wait (vif.wrst_n === 1'b1);

    forever begin
      seq_item_port.try_next_item(req);
      if (req == null) begin
        @(vif.wdrv_cb);
        vif.wdrv_cb.winc <= 1'b0;
      end else begin
        repeat (req.delay) begin
          @(vif.wdrv_cb);
          vif.wdrv_cb.winc <= 1'b0;
        end
        @(vif.wdrv_cb);
        vif.wdrv_cb.winc  <= 1'b1;
        vif.wdrv_cb.wdata <= req.data;
        seq_item_port.item_done();
      end
    end
  endtask
endclass

// Publishes every ACCEPTED write (winc && !wfull) and collects coverage
class wr_monitor extends uvm_monitor;
  `uvm_component_utils(wr_monitor)

  virtual fifo_if               vif;
  uvm_analysis_port #(wr_item)  ap;

  int unsigned n_accepted, n_dropped;

  // sampled values for coverage
  bit              s_winc, s_wfull;
  bit [DSIZE-1:0]  s_wdata;

  covergroup wr_cg;
    option.per_instance = 1;
    cp_winc  : coverpoint s_winc;
    cp_wfull : coverpoint s_wfull;
    x_inc_full : cross cp_winc, cp_wfull;    // includes "write while full"
    cp_data  : coverpoint s_wdata iff (s_winc && !s_wfull) {
      bins zero = {0};
      bins low  = {[1 : (1<<(DSIZE-1))-1]};
      bins high = {[(1<<(DSIZE-1)) : (1<<DSIZE)-2]};
      bins ones = {(1<<DSIZE)-1};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap    = new("ap", this);
    wr_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface not set for wr_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    wr_item tr;
    forever begin
      @(vif.wmon_cb);
      if (vif.wrst_n !== 1'b1) continue;

      s_winc  = vif.wmon_cb.winc;
      s_wfull = vif.wmon_cb.wfull;
      s_wdata = vif.wmon_cb.wdata;
      wr_cg.sample();

      if (s_winc && !s_wfull) begin
        tr = wr_item::type_id::create("tr");
        tr.data = s_wdata;
        n_accepted++;
        ap.write(tr);
      end else if (s_winc && s_wfull) begin
        n_dropped++;
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("WRMON", $sformatf("writes accepted=%0d dropped(full)=%0d  coverage=%0.1f%%",
              n_accepted, n_dropped, wr_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("WRMON", $sformatf("  cp_winc=%0.1f%% cp_wfull=%0.1f%% x_inc_full=%0.1f%% cp_data=%0.1f%%",
              wr_cg.cp_winc.get_inst_coverage(), wr_cg.cp_wfull.get_inst_coverage(),
              wr_cg.x_inc_full.get_inst_coverage(), wr_cg.cp_data.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

class wr_agent extends uvm_agent;
  `uvm_component_utils(wr_agent)

  wr_sequencer sqr;
  wr_driver    drv;
  wr_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = wr_sequencer::type_id::create("sqr", this);
    drv = wr_driver   ::type_id::create("drv", this);
    mon = wr_monitor  ::type_id::create("mon", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
