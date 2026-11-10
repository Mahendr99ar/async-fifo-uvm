# Free-tool targets (Icarus Verilog + Verilator). Used by GitHub Actions.
# For the full UVM testbench use sim/run_xsim.sh (Vivado xsim).

RTL = rtl/sync_2ff.sv rtl/async_fifo.sv

.PHONY: all lint directed uvm clean

all: lint directed

lint:
	verilator --lint-only -Wall --top-module async_fifo $(RTL)
	@echo "Lint: clean"

directed:
	iverilog -g2012 -o sim/directed.vvp $(RTL) tb/directed/tb_fifo_directed.sv
	vvp -n sim/directed.vvp | tee sim/directed.log
	@grep -q "RESULT: PASS" sim/directed.log

uvm:
	./sim/run_xsim.sh all

clean:
	rm -rf sim/*.vvp sim/*.log sim/xsim.dir sim/xsim.covdb sim/cov_report \
	       sim/*.jou sim/*.pb sim/*.wdb sim/*.vcd *.vcd
