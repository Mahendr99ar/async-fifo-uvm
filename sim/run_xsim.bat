@echo off
REM -----------------------------------------------------------------------------
REM Run the UVM testbench in Vivado xsim (Windows)
REM
REM   Open "Vivado 20xx.x Tcl Shell" (or run settings64.bat), then:
REM     cd <repo>\sim
REM     run_xsim.bat                         -> fifo_random_test
REM     run_xsim.bat fifo_full_test
REM     run_xsim.bat fifo_empty_test 25 7    -> test, wclk ns, rclk ns
REM     run_xsim.bat fifo_full_test 10 17 gui -> open waveform viewer
REM -----------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

set TEST=%1
if "%TEST%"=="" set TEST=fifo_random_test
set WCLK=%2
if "%WCLK%"=="" set WCLK=10
set RCLK=%3
if "%RCLK%"=="" set RCLK=17
set MODE=-R
if /i "%4"=="gui" set MODE=-gui

call xvlog -sv -L uvm -i ..\tb\uvm ^
  ..\rtl\sync_2ff.sv ^
  ..\rtl\async_fifo.sv ^
  ..\tb\uvm\fifo_if.sv ^
  ..\tb\uvm\fifo_pkg.sv ^
  ..\tb\uvm\fifo_sva.sv ^
  ..\tb\uvm\tb_top.sv
if errorlevel 1 exit /b 1

call xelab tb_top -L uvm -timescale 1ns/1ps -debug typical -s fifo_sim
if errorlevel 1 exit /b 1

call xsim fifo_sim %MODE% -log xsim_%TEST%.log ^
  -testplusarg UVM_TESTNAME=%TEST% ^
  -testplusarg WCLK_PERIOD=%WCLK% ^
  -testplusarg RCLK_PERIOD=%RCLK%

if exist xsim.covdb (
  call xcrg -report_format html -dir xsim.covdb -report_dir cov_report >nul 2>&1
  echo Coverage report: sim\cov_report\index.html
)
endlocal
