// -----------------------------------------------------------------------------
// Sequences (traffic shape controlled by delay ranges)
// -----------------------------------------------------------------------------
class wr_seq extends uvm_sequence #(wr_item);
  `uvm_object_utils(wr_seq)

  int unsigned n_items   = 500;
  int unsigned min_delay = 0;
  int unsigned max_delay = 3;

  function new(string name = "wr_seq");
    super.new(name);
  endfunction

  task body();
    repeat (n_items) begin
      req = wr_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { delay inside {[min_delay:max_delay]}; })
        `uvm_fatal("RAND", "wr_item randomization failed")
      finish_item(req);
    end
  endtask
endclass

// Runs until the test ends (killed when the objection drops)
class rd_seq extends uvm_sequence #(rd_item);
  `uvm_object_utils(rd_seq)

  int unsigned min_delay = 0;
  int unsigned max_delay = 3;

  function new(string name = "rd_seq");
    super.new(name);
  endfunction

  task body();
    forever begin
      req = rd_item::type_id::create("req");
      start_item(req);
      if (!req.randomize() with { delay inside {[min_delay:max_delay]}; })
        `uvm_fatal("RAND", "rd_item randomization failed")
      finish_item(req);
    end
  endtask
endclass
