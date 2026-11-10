# Verification Plan — Async FIFO

| ID | Feature | How it is verified | Where |
|----|---------|--------------------|-------|
| F1 | Data integrity (in-order, no loss, no duplication) | Scoreboard compares every accepted read with the queued write | `fifo_scoreboard.svh` |
| F2 | `wfull` asserts when FIFO holds 2^ASIZE entries | `fifo_full_test`, cover `c_full_seen` | test + SVA cover |
| F3 | Write while full is dropped (no overflow) | Driver ignores `wfull`; assertion `a_no_write_when_full`; cross `winc × wfull` | SVA + coverage |
| F4 | `rempty` asserts when FIFO drained | `fifo_empty_test`, cover `c_empty_after_data` | test + SVA cover |
| F5 | Read while empty is ignored (no underflow) | Assertion `a_no_read_when_empty`; cross `rinc × rempty` | SVA + coverage |
| F6 | Gray pointers change ≤ 1 bit per clock (CDC safety) | `a_wptr_gray`, `a_rptr_gray` | SVA |
| F7 | Works for any clock ratio | Every test re-run at wclk:rclk = 10:17, 17:10, 10:10 | `run_xsim.sh all` |
| F8 | Independent resets per domain | `tb_top` releases `wrst_n` before `rrst_n` | `tb_top.sv` |
| F9 | Full data range | Coverpoint `cp_data` (zero / low / high / all-ones) | `wr_monitor` |

## Coverage goals
- Functional coverage (covergroups): **100 %**
- All SVA cover properties hit at least once *(commercial simulators; Vivado xsim ignores `cover property`, so the equivalent covergroup crosses are used there)*
- 0 UVM_ERROR / UVM_FATAL across all 9 runs (3 tests × 3 clock ratios)

## Known limitations / future work
- No X-propagation or gate-level simulation
- Clock ratio is fixed per run (no dynamic frequency change)
- Add almost-full / almost-empty flags and verify them
- Formal proof of the gray-code property (SymbiYosys)
