// -----------------------------------------------------------------------------
// Sequence items
// -----------------------------------------------------------------------------

// One write attempt: wait `delay` idle cycles, then pulse winc with `data`
class wr_item extends uvm_sequence_item;
  rand bit [DSIZE-1:0] data;
  rand int unsigned    delay;

  constraint c_delay { soft delay inside {[0:3]}; }

  // Bias corner values (all-zeros / all-ones) so data coverage closes quickly
  constraint c_data  { data dist { {DSIZE{1'b0}} := 5, {DSIZE{1'b1}} := 5, [1:(1<<DSIZE)-2] :/ 90 }; }

  `uvm_object_utils_begin(wr_item)
    `uvm_field_int(data,  UVM_ALL_ON)
    `uvm_field_int(delay, UVM_ALL_ON | UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "wr_item");
    super.new(name);
  endfunction
endclass

// One read attempt: wait `delay` idle cycles, then pulse rinc.
// `data` is filled in by the read monitor (observed value).
class rd_item extends uvm_sequence_item;
  rand int unsigned delay;
  bit  [DSIZE-1:0]  data;

  constraint c_delay { soft delay inside {[0:3]}; }

  `uvm_object_utils_begin(rd_item)
    `uvm_field_int(delay, UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(data,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "rd_item");
    super.new(name);
  endfunction
endclass
