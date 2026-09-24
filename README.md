# Basys 3 Sample Project

A minimal "hello world" Vivado project for the Digilent Basys 3 board
(Xilinx Artix-7 XC7A35T-1CPG236C), meant as a starting point for new
designs.

## What it does

- The 16 slide switches (`sw[15:0]`) drive the 16 LEDs (`led[15:0]`)
  directly, so you can confirm I/O is working.
- The center button (`btnC`) is a synchronous reset.
- A 16-bit counter increments once per second and is shown in hex on the
  4-digit 7-segment display.
- A small UART command/response protocol runs over the board's onboard
  USB-UART bridge (no extra wiring — the same USB cable used to program the
  board), so a PC script can read the switches and counter and trigger a
  reset. See [UART test harness](#uart-test-harness) below.

This exercises the board's clock, switches, LEDs, one pushbutton, the
7-segment display, and UART — the most commonly used I/O on the board — in
a small design that's easy to read and extend.

## Project layout

```
Basys3_Sample_Project/
├── src/
│   ├── top.v                    top-level module
│   ├── clock_divider.v          divides 100 MHz down to a 1 kHz mux tick and 1 Hz seconds tick
│   ├── seven_seg_hex.v          hex-to-7-segment decoder + digit multiplexer
│   ├── uart_rx.v                8-N-1 UART receiver
│   ├── uart_tx.v                8-N-1 UART transmitter
│   └── uart_test_harness.v      command/response protocol (see below)
├── sim/
│   ├── top_tb.v                 testbench for the switch/LED/reset logic
│   └── uart_test_harness_tb.v   self-checking testbench for the UART protocol
├── python/
│   ├── basys3_test_harness.py   host-side automated test script (pyserial)
│   └── requirements.txt
├── constraints/
│   └── Basys3_Master.xdc        Digilent's master XDC; only the pins this
│                                 project uses are uncommented
└── scripts/
    └── create_project.tcl       regenerates the Vivado project from these sources
```

Only sources and this script are checked in — the generated `vivado/`
project directory (`.xpr`, `.cache`, `.runs`, etc.) is left out, which is
the normal way to keep an FPGA project readable in git.

## Requirements

- Xilinx Vivado (Web/Standard edition is fine) — developed against the
  2019.x/2020.x-era toolchain; any reasonably current Vivado version will
  work with the Artix-7 part `xc7a35tcpg236-1`.
- A Digilent Basys 3 board (rev B/C/D use the same pinout).

## Building the project

1. Launch Vivado.
2. In the Tcl Console, run:
   ```tcl
   cd /path/to/basys3_sample_project/scripts
   source create_project.tcl
   ```
   This creates `../vivado/basys3_sample_project.xpr` with `top` as the
   top-level module, `top_tb` as the simulation top, and the constraints
   file already attached.
3. Open the generated `.xpr` in the GUI (or stay in batch mode), then run
   **Run Synthesis → Run Implementation → Generate Bitstream** as usual.
4. Open Hardware Manager, connect to the board over USB, and program the
   device with the generated `.bit` file.

Alternatively, skip the GUI and do it all from the Tcl console:

```tcl
source create_project.tcl
launch_runs synth_1
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
```

## Simulation

`sim/top_tb.v` drives the switches and reset and checks that `led` tracks
`sw`. In Vivado: **Flow Navigator → Simulation → Run Simulation → Run
Behavioral Simulation**, or from the Tcl console:

```tcl
launch_simulation
run all
```

`create_project.tcl` adds both `top_tb.v` and `uart_test_harness_tb.v` to
the sim fileset but only one can be the simulation top at a time (it sets
`top_tb` by default). To run the UART protocol testbench instead:

```tcl
set_property top uart_test_harness_tb [get_filesets sim_1]
launch_simulation
run all
```

## UART test harness

`src/uart_test_harness.v` runs a tiny command/response protocol over the
board's onboard USB-UART bridge (`RsRx`/`RsTx`, pins B18/A18) at 115200
8-N-1. No extra wiring is needed — it's the same USB cable already used to
program the board; Windows enumerates it as a "USB Serial Port (COMx)"
once the bitstream is loaded (check Device Manager for the COM number).

| Host sends | FPGA replies | Meaning |
|---|---|---|
| `'S'` (0x53) | 2 bytes: `sw[15:8]`, `sw[7:0]` | current switch positions |
| `'C'` (0x43) | 2 bytes: `count[15:8]`, `count[7:0]` | the free-running 1 Hz counter |
| `'R'` (0x52) | `"OK"` | resets the counter to 0 |
| `'T'` (0x54) | `0x01` | self-test / BIST placeholder |
| anything else | `"?"` | unrecognized command |

This is meant as a stand-in for a bench automated-test setup: a host script
sends commands and checks the responses, the same way ATE software talks
to a unit under test, instead of a person reading switches and the display
by eye.

`python/basys3_test_harness.py` is that host script. After programming the
board:

```bash
cd python
pip install -r requirements.txt
python basys3_test_harness.py --list          # find the board's COM port
python basys3_test_harness.py --port COM5      # run the test sequence
```

It runs a self-test check, reads back the switch positions, resets and
re-reads the counter, times the counter's tick rate over a few seconds to
confirm it's actually running at 1 Hz (not e.g. 2x fast — the kind of bug
that's easy to introduce and only a timed test like this will catch), and
checks that an unrecognized command is handled gracefully. It exits 0 on
success, 1 if anything failed, and prints a PASS/FAIL line per check plus
a summary — pipe it into whatever CI or bench-test logging you'd normally
use.

## Extending it

The remaining unused board I/O (other four buttons, Pmod headers, VGA,
PS/2, Quad SPI) is present but commented out in
`constraints/Basys3_Master.xdc` — uncomment what you need, add matching
ports to `top.v`, add any new source files to `scripts/create_project.tcl`
(list them explicitly like the existing lines — a `glob`-based `add_files`
didn't pick up files reliably in this Vivado install), and re-run
`create_project.tcl`.

## Pin reference (used in this project)

| Signal | Pin(s) |
|---|---|
| `clk` | W5 (100 MHz) |
| `sw[15:0]` | V17, V16, W16, W17, W15, V15, W14, W13, V2, T3, T2, R3, W2, U1, T1, R2 |
| `led[15:0]` | U16, E19, U19, V19, W18, U15, U14, V14, V13, V3, W3, U3, P3, N3, P1, L1 |
| `btnC` | U18 |
| `seg[6:0]` | W7, W6, U8, V8, U5, V5, U7 |
| `dp` | V7 |
| `an[3:0]` | U2, U4, V4, W4 |
| `RsRx` | B18 |
| `RsTx` | A18 |

Source: [Digilent Basys-3-Master.xdc](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).
