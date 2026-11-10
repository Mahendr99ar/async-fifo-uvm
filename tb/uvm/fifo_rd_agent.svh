// -----------------------------------------------------------------------------
// Read agent : sequencer + driver + monitor (rclk domain)
// -----------------------------------------------------------------------------

typedef uvm_sequencer #(rd_item) rd_sequencer;

// Drives rinc. It does NOT look at rempty on purpose, so tests can attempt
// reads while empty and check that the DUT ignores them.
class rd_driver extends uvm_driver #(rd_item);
  `uvm_component_utils(rd_driver)

  virtual fifo_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface not set for rd_driver")
  endfunction

  task run_phase(uvm_phase phase);
    vif.rinc <= 1'b0;
    wait (vif.rrst_n === 1'b1);

    forever begin
      seq_item_port.try_next_item(req);
      if (req == null) begin
        @(vif.rdrv_cb);
        vif.rdrv_cb.rinc <= 1'b0;
      end else begin
        repeat (req.delay) begin
          @(vif.rdrv_cb);
          vif.rdrv_cb.rinc <= 1'b0;
        end
        @(vif.rdrv_cb);
        vif.rdrv_cb.rinc <= 1'b1;
        seq_item_port.item_done();
      end
    end
  endtask
endclass

// Publishes every ACCEPTED read (rinc && !rempty) with the data popped
class rd_monitor extends uvm_monitor;
  `uvm_component_utils(rd_monitor)

  virtual fifo_if               vif;
  uvm_analysis_port #(rd_item)  ap;

  int unsigned n_accepted, n_ignored;

  bit s_rinc, s_rempty;

  covergroup rd_cg;
    option.per_instance = 1;
    cp_rinc   : coverpoint s_rinc;
    cp_rempty : coverpoint s_rempty;
    x_inc_empty : cross cp_rinc, cp_rempty;  // includes "read while empty"
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap    = new("ap", this);
    rd_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "virtual interface not set for rd_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    rd_item tr;
    forever begin
      @(vif.rmon_cb);
      if (vif.rrst_n !== 1'b1) continue;

      s_rinc   = vif.rmon_cb.rinc;
      s_rempty = vif.rmon_cb.rempty;
      rd_cg.sample();

      if (s_rinc && !s_rempty) begin
        tr = rd_item::type_id::create("tr");
        tr.data = vif.rmon_cb.rdata;   // show-ahead: data valid before pop
        n_accepted++;
        ap.write(tr);
      end else if (s_rinc && s_rempty) begin
        n_ignored++;
      end
    end
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("RDMON", $sformatf("reads accepted=%0d ignored(empty)=%0d  coverage=%0.1f%%",
              n_accepted, n_ignored, rd_cg.get_inst_coverage()), UVM_LOW)
    `uvm_info("RDMON", $sformatf("  cp_rinc=%0.1f%% cp_rempty=%0.1f%% x_inc_empty=%0.1f%%",
              rd_cg.cp_rinc.get_inst_coverage(), rd_cg.cp_rempty.get_inst_coverage(),
              rd_cg.x_inc_empty.get_inst_coverage()), UVM_LOW)
  endfunction
endclass

class rd_agent extends uvm_agent;
  `uvm_component_utils(rd_agent)

  rd_sequencer sqr;
  rd_driver    drv;
  rd_monitor   mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = rd_sequencer::type_id::create("sqr", this);
    drv = rd_driver   ::type_id::create("drv", this);
    mon = rd_monitor  ::type_id::create("mon", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
