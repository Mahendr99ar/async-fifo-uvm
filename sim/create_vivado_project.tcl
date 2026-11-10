# -----------------------------------------------------------------------------
# Creates a Vivado GUI project for the async FIFO UVM testbench.
#
# In Vivado:  Tools -> Run Tcl Script...  -> select this file
# or in the Tcl Console:
#   source C:/vlsi/async-fifo-uvm/sim/create_vivado_project.tcl
#
# Then: Flow Navigator -> Run Simulation -> Run Behavioral Simulation
# -----------------------------------------------------------------------------
set script_dir [file dirname [file normalize [info script]]]
set root       [file normalize "$script_dir/.."]
set proj_dir   "$root/vivado_proj"

puts "Repo root : $root"
puts "Project   : $proj_dir"

create_project fifo_uvm $proj_dir -force

# ---- Design sources ----
add_files -norecurse [list "$root/rtl/sync_2ff.sv" "$root/rtl/async_fifo.sv"]
set_property top async_fifo [get_filesets sources_1]

# ---- UVM testbench (simulation only) ----
add_files -fileset sim_1 -norecurse [glob "$root/tb/uvm/*.sv" "$root/tb/uvm/*.svh"]
set_property include_dirs [list "$root/tb/uvm"] [get_filesets sim_1]
set_property top     tb_top         [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# ---- UVM + run settings ----
set sim [get_filesets sim_1]
set_property -name {xsim.compile.xvlog.more_options}   -value {-L uvm} -objects $sim
set_property -name {xsim.elaborate.xelab.more_options} -value {-L uvm} -objects $sim
set_property -name {xsim.simulate.xsim.more_options} \
             -value {-testplusarg UVM_TESTNAME=fifo_random_test} -objects $sim
set_property -name {xsim.simulate.runtime} -value {all} -objects $sim

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "Project ready."
puts "Next: Flow Navigator -> Run Simulation -> Run Behavioral Simulation"
puts "To change test: Settings -> Simulation -> Simulation tab -> xsim.simulate.xsim.more_options"
puts "   e.g. -testplusarg UVM_TESTNAME=fifo_full_test"
