#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Run the UVM testbench in Vivado xsim (Linux / WSL / Git-Bash)
#
#   source <Vivado install>/settings64.sh      # once per terminal
#   cd sim
#   ./run_xsim.sh                              # fifo_random_test
#   ./run_xsim.sh fifo_full_test
#   ./run_xsim.sh fifo_empty_test 25 7         # test, wclk ns, rclk ns
#   ./run_xsim.sh all                          # every test, 3 clock ratios
#   GUI=1 ./run_xsim.sh fifo_full_test         # open waveform viewer
# -----------------------------------------------------------------------------
set -e
cd "$(dirname "$0")"

TEST=${1:-fifo_random_test}
WCLK=${2:-10}
RCLK=${3:-17}
ROOT=..

compile() {
  xvlog -sv -L uvm -i $ROOT/tb/uvm \
    $ROOT/rtl/sync_2ff.sv \
    $ROOT/rtl/async_fifo.sv \
    $ROOT/tb/uvm/fifo_if.sv \
    $ROOT/tb/uvm/fifo_pkg.sv \
    $ROOT/tb/uvm/fifo_sva.sv \
    $ROOT/tb/uvm/tb_top.sv
  xelab tb_top -L uvm -timescale 1ns/1ps -debug typical -s fifo_sim
}

run() {   # $1 test  $2 wclk  $3 rclk
  local log="xsim_${1}_w${2}_r${3}.log"
  local mode="-R"
  [ "${GUI:-0}" = "1" ] && mode="-gui"
  xsim fifo_sim $mode -log "$log" \
    -testplusarg UVM_TESTNAME=$1 \
    -testplusarg WCLK_PERIOD=$2 \
    -testplusarg RCLK_PERIOD=$3
  grep -E "PASSED|FAILED" "$log" | tail -1
}

compile

if [ "$TEST" = "all" ]; then
  for t in fifo_random_test fifo_full_test fifo_empty_test; do
    for ratio in "10 17" "17 10" "10 10"; do
      run $t $ratio
    done
  done
else
  run "$TEST" "$WCLK" "$RCLK"
fi

# Functional + code coverage report (HTML) if a coverage DB was produced
if [ -d xsim.covdb ]; then
  xcrg -report_format html -dir xsim.covdb -report_dir cov_report >/dev/null 2>&1 \
    && echo "Coverage report: sim/cov_report/index.html"
fi
