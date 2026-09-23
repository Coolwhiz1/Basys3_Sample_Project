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

This exercises the board's clock, switches, LEDs, one pushbutton, and the
7-segment display — the most commonly used I/O on the board — in a single
small design that's easy to read and extend.

## Project layout

```
basys3_sample_project/
├── src/
│   ├── top.v               top-level module
│   ├── clock_divider.v     divides 100 MHz down to a 1 kHz mux tick and 1 Hz seconds tick
│   └── seven_seg_hex.v     hex-to-7-segment decoder + digit multiplexer
├── sim/
│   └── top_tb.v            simulation-only testbench (not synthesized)
├── constraints/
│   └── Basys3_Master.xdc   Digilent's master XDC; only the pins this
│                            project uses are uncommented
└── scripts/
    └── create_project.tcl  regenerates the Vivado project from these sources
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

## Extending it

The unused board I/O (other four buttons, Pmod headers, VGA, USB-RS232,
PS/2, Quad SPI) is present but commented out in
`constraints/Basys3_Master.xdc` — uncomment what you need, add matching
ports to `top.v`, and re-run `create_project.tcl` (it re-adds all files
under `src/`, `sim/`, and the constraints file automatically).

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

Source: [Digilent Basys-3-Master.xdc](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).
