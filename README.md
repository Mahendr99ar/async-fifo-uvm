# Async FIFO — RTL Design and UVM Verification

[![CI](https://github.com/YOUR_USERNAME/async-fifo-uvm/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/async-fifo-uvm/actions/workflows/ci.yml)
![SystemVerilog](https://img.shields.io/badge/SystemVerilog-UVM%201.2-blue)
![Vivado](https://img.shields.io/badge/Vivado-2025.2%20xsim-orange)

**Status: all 3 regression tests passing, 100 % merged functional coverage**
Author: [YOUR NAME](https://github.com/YOUR_USERNAME)

A parameterized dual-clock FIFO that moves data safely between two unrelated clock domains,
verified with a two-agent constrained-random UVM testbench, SystemVerilog Assertions and
functional coverage. FIFOs like this sit at every clock boundary in networking and
data-center ASICs — for example between a SerDes recovered clock and the core clock.

```
          WRITE CLOCK DOMAIN (wclk)                         READ CLOCK DOMAIN (rclk)

   winc, wdata ──► ┌──────────────┐   waddr   ┌──────────┐   raddr   ┌──────────────┐ ◄── rinc
                   │ write pointer│──────────►│ dual-port│◄──────────│ read pointer │
                   │ binary + gray│           │   RAM    │──► rdata  │ binary + gray│
   wfull ◄──────── │  full logic  │           │ 16 x 8b  │           │ empty logic  │ ──────► rempty
                   └──────┬───────┘           └──────────┘           └──────┬───────┘
                          │ gray wptr                                gray rptr │
                          │            ┌──────────────────┐                    │
                          └───────────►│ 2-FF synchronizer│──► (to read side)  │
                   (to write side) ◄───│ 2-FF synchronizer│◄───────────────────┘
                                       └──────────────────┘
```

![Waveform: FIFO filling up and blocking writes when full](docs/waveform_full.png)

## Features

| Area | Implementation |
|------|----------------|
| Design | Parameterized depth (`2^ASIZE`) and width (`DSIZE`); Gray-coded pointers; 2-flop synchronizers; show-ahead read |
| Safety | Writes when full and reads when empty are ignored by the hardware (no overflow / underflow) |
| UVM environment | Separate write and read agents (sequencer, driver, monitor), in-order scoreboard, environment, 3 tests |
| Stimulus | Constrained-random data and idle delays; weighted `dist` for corner values (`0x00`, `0xFF`) |
| Checking | Scoreboard compares every accepted read with the expected write; SVA bound into the RTL |
| Assertions | Gray pointer changes ≤ 1 bit per clock; pointer does not advance on write-when-full or read-when-empty |
| Coverage | Covergroups on both sides: `winc × wfull`, `rinc × rempty`, data value bins; per-coverpoint reporting |
| Clock ratios | Clock periods set from the command line (`+WCLK_PERIOD`, `+RCLK_PERIOD`) |
| CI | GitHub Actions runs Verilator lint and an Icarus self-checking test on every push |

## Results

Simulator: Vivado 2025.2 xsim, UVM 1.2, 500 write attempts per test.

| Test | Clocks (w:r) | Writes accepted | Writes blocked (full) | Reads ignored (empty) | Mismatches | Result |
|------|--------------|-----------------|-----------------------|-----------------------|------------|--------|
| `fifo_random_test` | 10 : 17 ns | 306 | 194 | 4 | 0 | PASSED |
| `fifo_full_test` | 10 : 17 ns | 87 | 413 | 3 | 0 | PASSED |
| `fifo_empty_test` | 17 : 10 ns | 500 | 0 | 2914 | 0 | PASSED |

UVM_ERROR: 0 · UVM_FATAL: 0 · Assertion failures: 0

Full 6.3 µs run of `fifo_full_test`: the writer requests every cycle (`winc` high) while `wfull`
toggles as each slow read frees one slot; `rempty` is high only at start and end.

![Waveform overview of fifo_full_test](docs/waveform_overview.png)

**Coverage closure.** The first regression reported 93.8 % write-side coverage: the
single-value data bins (`0x00`, `0xFF`) were rarely produced by uniform random data. A weighted
`dist` constraint was added; a first attempt using the unsized literal `'1` still gave 93.8 %,
so it was replaced with an explicit `{DSIZE{1'b1}}` and per-coverpoint reporting was added.
After the fix every coverpoint reports 100 %. Each test targets one scenario (the empty test
never fills the FIFO, so it alone shows 75 % write-side coverage); closure is measured on the
merged regression.

| Covergroup | random | full | empty | Merged |
|------------|--------|------|-------|--------|
| Write side | 93.8 %* | 100 % | 75 % | **100 %** |
| Read side | 100 % | 100 % | 91.7 % | **100 %** |

\* run before the coverage fix.

**Testbench sanity check.** To confirm the checkers really catch bugs, the full-flag comparison
was deliberately broken (only the MSB inverted instead of the top two bits). The FIFO then
reported full too early and overwrote data, and the self-checking test failed immediately with
`wfull not set` and `data mismatch` errors.

## Quick start

**Vivado GUI (recommended for waveforms)**
1. Vivado → **Tools → Run Tcl Script…** → `sim/create_vivado_project.tcl`
2. **Run Simulation → Run Behavioral Simulation**
3. To change the test: **Simulation Settings → Simulation → `xsim.simulate.xsim.more_options`**
   ```
   -testplusarg UVM_TESTNAME=fifo_full_test
   -testplusarg UVM_TESTNAME=fifo_empty_test -testplusarg WCLK_PERIOD=17 -testplusarg RCLK_PERIOD=10
   ```

**Vivado command line**
```bash
# Linux: source <Vivado>/settings64.sh      Windows: run <Vivado>\settings64.bat
cd sim
./run_xsim.sh fifo_full_test          # Windows: run_xsim.bat fifo_full_test
./run_xsim.sh fifo_empty_test 17 10   # test, wclk ns, rclk ns
./run_xsim.sh all                     # 3 tests x 3 clock ratios
```

**Free tools (same checks as CI)**
```bash
make lint        # Verilator -Wall
make directed    # Icarus Verilog self-checking test
```

## Project structure

```
async-fifo-uvm/
├── rtl/
│   ├── async_fifo.sv            FIFO: pointers, full/empty logic, memory
│   └── sync_2ff.sv              2-flop synchronizer
├── tb/
│   ├── uvm/
│   │   ├── tb_top.sv            clocks, resets, DUT, run_test()
│   │   ├── fifo_if.sv           interface with per-domain clocking blocks
│   │   ├── fifo_pkg.sv          package including all classes below
│   │   ├── fifo_items.svh       write / read sequence items + constraints
│   │   ├── fifo_wr_agent.svh    write driver, monitor (+covergroup), agent
│   │   ├── fifo_rd_agent.svh    read driver, monitor (+covergroup), agent
│   │   ├── fifo_scoreboard.svh  in-order reference model
│   │   ├── fifo_env.svh         environment
│   │   ├── fifo_seqs.svh        write / read sequences
│   │   ├── fifo_tests.svh       random, full, empty tests
│   │   └── fifo_sva.sv          assertions, bound into async_fifo
│   └── directed/
│       └── tb_fifo_directed.sv  lightweight test for CI
├── sim/                         Vivado scripts (Tcl project, .sh, .bat)
├── docs/                        verification plan, screenshots
└── .github/workflows/ci.yml     lint + directed test on every push
```

Feature-to-check mapping: [docs/verification_plan.md](docs/verification_plan.md)

## Design decisions

- **Gray-coded pointers across clock domains.** Only one bit changes per increment, so if the
  synchronizer samples during a transition the result is either the old or the new value —
  never a random one. Binary pointers can change many bits at once and are unsafe to sync.
- **Pointers one bit wider than the address.** With `ASIZE+1` bits, equal pointers mean
  *empty*; pointers equal except for the top two Gray bits mean *full*.
- **Pessimistic flags.** Because of the 2-cycle synchronizer delay, `wfull` and `rempty` may
  stay asserted a little longer than necessary, but they are never wrong. This trades a few
  cycles of throughput for guaranteed correctness.
- **Drivers ignore full/empty on purpose.** The UVM drivers keep trying to write when full and
  read when empty, so the protection logic is exercised in every test. The monitors only report
  *accepted* transactions to the scoreboard.
- **Separate clocking blocks per domain.** Drivers and monitors use clocking blocks, which
  removes race conditions between testbench and design at the clock edge.
- **Assertions bound, not embedded.** `fifo_sva` is attached with `bind`, so the RTL stays
  clean and synthesizable.

## Limitations and next steps

- Vivado xsim ignores `cover property` statements; the same scenarios are covered with
  covergroup crosses instead.
- Clock ratio is fixed during a run; dynamic frequency changes are not tested.
- No gate-level simulation or X-propagation checks yet.
- Next: add almost-full / almost-empty flags, prove the Gray-code property formally
  (SymbiYosys), and run the design through an RTL-to-GDS flow (OpenLane, sky130).

![Regression log: fifo_full_test passing with 100 % coverage](docs/regression_log.png)

Full simulator log: [docs/fifo_full_test_xsim_log.txt](docs/fifo_full_test_xsim_log.txt)
