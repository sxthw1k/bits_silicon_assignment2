# Assignment 2: Synchronous FIFO Verification

**Student ID:** 2024a3ps0378g  
**Student Name:** Sathwik Kumble

---

## Design Overview

### sync_fifo_top.v

The top-level synchronous FIFO implementation. All hardware logic lives here.

**Parameters:**
- `DATA_WIDTH` — width of each data word (default: 8 bits)
- `DEPTH` — number of entries in the FIFO (default: 16)
- `ADDR_WIDTH` — computed internally via `clog2(DEPTH)` as a `localparam`

**Ports:**

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | input | 1 | Clock — all logic on rising edge |
| `rst_n` | input | 1 | Active-low synchronous reset |
| `wr_en` | input | 1 | Write enable |
| `wr_data` | input | DATA_WIDTH | Data to write |
| `wr_full` | output | 1 | High when FIFO is full |
| `rd_en` | input | 1 | Read enable |
| `rd_data` | output | DATA_WIDTH | Data read out (registered) |
| `rd_empty` | output | 1 | High when FIFO is empty |
| `count` | output | ADDR_WIDTH+1 | Current occupancy (0 to DEPTH) |

**Internal structure:**
- `mem[0:DEPTH-1]` — register array storing data words
- `wr_ptr` — write pointer (ADDR_WIDTH bits wide)
- `rd_ptr` — read pointer (ADDR_WIDTH bits wide)
- `count_r` — occupancy counter (ADDR_WIDTH+1 bits to hold value == DEPTH)

**Functional behaviour:**
- Reset is synchronous and active-low. After reset: all pointers zero, count=0, rd_empty=1, wr_full=0.
- Write occurs when `wr_en=1` and FIFO is not full. Data written to `mem[wr_ptr]`, pointer incremented with wrap-around.
- Read occurs when `rd_en=1` and FIFO is not empty. Data read from `mem[rd_ptr]` into `rd_data`, pointer incremented with wrap-around.
- Simultaneous read and write: both pointers increment, count unchanged.
- Overflow attempt (write when full): no state change.
- Underflow attempt (read when empty): no state change.
- Flags: `wr_full = (count_r == DEPTH)`, `rd_empty = (count_r == 0)`.

**clog2 function:**  
Implemented as a Verilog function inside the module. Computes `ceil(log2(value))` using a right-shift loop. Used to derive `ADDR_WIDTH` from `DEPTH` at elaboration time.

---

### sync_fifo.v

A thin wrapper around `sync_fifo_top`. Exposes identical ports and parameters. Other modules and the testbench instantiate this. `ADDR_WIDTH` is declared as a `parameter` here (not localparam) so it can be used in the port width expression, but is not passed down to `sync_fifo_top` since `sync_fifo_top` computes its own `ADDR_WIDTH` via `clog2`.

---

## Testbench Overview

### tb_sync_fifo.v

A fully self-checking testbench. Manual waveform inspection is not required — all verification is automatic.

**Components:**

**1. DUT Instantiation**  
Instantiates `sync_fifo` with `DATA_WIDTH=8`, `DEPTH=16`, `ADDR_WIDTH=4`.

**2. Clock Generation**  
10 ns period (100 MHz). Generated with `initial clk=0` and `always #5 clk=~clk`.

**3. Golden Reference Model**  
An independent behavioral FIFO running in parallel with the DUT on the same clock edge. Makes all decisions from its own state variables (`model_count`, `model_wr_ptr`, `model_rd_ptr`) — never reads DUT output flags. This independence is what allows it to catch DUT bugs.

**4. Scoreboard**  
Runs after every clock edge (with 1 ps settle delay). Compares four DUT outputs against the golden model:
- `rd_data` vs `model_rd_data`
- `count` vs `model_count`
- `rd_empty` vs `(model_count == 0)`
- `wr_full` vs `(model_count == DEPTH)`

On any mismatch: prints detailed error message (time, cycle, test name, expected vs actual, input signals, model pointer values) and terminates simulation immediately.

**5. Eight Directed Tests:**

| Test | What it verifies |
|---|---|
| Reset Test | count=0, rd_empty=1, wr_full=0 after reset |
| Single Write/Read | Basic data integrity, flag transitions |
| Fill Test | wr_full asserted at DEPTH, overflow prevention |
| Drain Test | rd_empty asserted at 0, FIFO ordering preserved |
| Overflow Attempt | No state change on write-when-full |
| Underflow Attempt | No state change on read-when-empty |
| Simultaneous R/W | count unchanged, both pointers advance |
| Pointer Wrap-Around | Data integrity preserved across pointer boundary |

**6. Coverage Counters:**

| Counter | Meaning |
|---|---|
| `cov_full` | Cycles where FIFO was full |
| `cov_empty` | Cycles where FIFO was empty |
| `cov_wrap` | Times wr_ptr wrapped from DEPTH-1 to 0 |
| `cov_simul` | Valid simultaneous read+write cycles |
| `cov_overflow` | Write attempts while full |
| `cov_underflow` | Read attempts while empty |

All six counters must be non-zero at end of simulation for adequate coverage. A summary is printed before `$finish`.

---

## How to Simulate

### ModelSim

```
cd <project_root>/rtl
vlib work
vmap work work
vlog sync_fifo_top.v sync_fifo.v ../tb/tb_sync_fifo.v
vsim work.tb_sync_fifo
run -all
```

### Icarus Verilog

```
iverilog -o sim rtl/sync_fifo_top.v rtl/sync_fifo.v tb/tb_sync_fifo.v
vvp sim
```

---

## Expected Output

```
====================================================
  Synchronous FIFO Testbench
  DATA_WIDTH=8  DEPTH=16  ADDR_WIDTH=4  Seed=42
====================================================

[TEST 1] Reset Test
[TEST 1] PASS - count=0  rd_empty=1  wr_full=0

[TEST 2] Single Write / Read Test
[TEST 2] PASS - wrote 0xA5, read back 0xa5, count=0

[TEST 3] Fill Test
[TEST 3] PASS - FIFO full: count=16  wr_full=1

[TEST 4] Drain Test
[TEST 4] PASS - all 16 entries drained in order, count=0  rd_empty=1

[TEST 5] Overflow Attempt Test
[TEST 5] PASS - overflow blocked: count=16  wr_full=1

[TEST 6] Underflow Attempt Test
[TEST 6] PASS - underflow blocked: count=0  rd_empty=1

[TEST 7] Simultaneous Read / Write Test
[TEST 7] PASS - 8 simultaneous R/W cycles, count stayed at 8

[TEST 8] Pointer Wrap-Around Test
[TEST 8] PASS - pointer wrap-around: data integrity preserved, count=0

====================================================
  Coverage Summary
====================================================
  cov_full      = X  (cycles FIFO was full)
  cov_empty     = X  (cycles FIFO was empty)
  cov_wrap      = X  (wr_ptr wrap-around events)
  cov_simul     = X  (valid simultaneous R/W cycles)
  cov_overflow  = X  (write attempts while full)
  cov_underflow = X  (read attempts while empty)
====================================================

  ALL COVERAGE BINS HIT - adequate coverage achieved

====================================================
  ALL 8 TESTS PASSED
====================================================
```

---

## Design Decisions

**Why `count_r` is ADDR_WIDTH+1 bits wide:**  
The pointers only ever reach DEPTH-1 (15), so they fit in ADDR_WIDTH (4) bits. But the count must represent the value DEPTH (16) when the FIFO is completely full. 16 in binary is `10000` — 5 bits. Using only 4 bits would cause count to overflow to 0 when full, making the FIFO think it is empty. The extra bit prevents this.

**Why non-blocking assignments in RTL:**  
All assignments in the synchronous `always` block use `<=` (non-blocking). This ensures all right-hand sides are evaluated with the current clock-edge values before any updates occur, preventing order-dependency bugs.

**Why blocking assignments in the golden model:**  
The golden model uses `=` (blocking) intentionally. It is pure behavioral simulation code — write happens before read happens before count update, in sequence. This matches the DUT's effective behaviour since all DUT non-blocking assignments resolve at the same clock edge.

**Why the scoreboard uses `!==` not `!=`:**  
The `!==` operator is a case-inequality check that treats `X` and `Z` as distinct logic values. Using `!=` could miss cases where a DUT output is `X` (uninitialised) — `!=` would evaluate `X != 1` as `X` (unknown), not catching the error. `!==` correctly flags any `X` or `Z` mismatch.
