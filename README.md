# FPGA Switching Controller — Marx-Based HV Pulse Generator (Design 1)

Digital switching controller for **Design 1** of a boost-assisted Marx high-voltage pulse
generator, developed as part of my B.Sc. graduation project in Electrical Engineering
(Electronics). The module generates the exact gate-drive timing sequence — `SL`, `SC`,
`S1`–`S4` — needed to charge the boost inductor, charge the Marx capacitors, and discharge
them in series onto the load, with built-in dead-time protection against shoot-through.

## Overview

- Design 1 is the higher-amplitude configuration used for cancer-cell ablation via
  irreversible electroporation (IRE).
- Switching timing is derived from the period `Ts = 1/fs` and the duty ratios described in
  the accompanying design report, based on the reference topology of Kholgh Khiz & Banaei
  (*Int. J. Circuit Theory Appl.*, 2022).
- All outputs are registered (glitch-free) and separated by a configurable dead time so that
  `SL` and `SC` can never be high at the same time.
- A short textual overview of the full project (both designs, simulation results) is on my
  LinkedIn profile; the complete design report is available on request.

## Repository structure

```
├── src/
│   └── marx_gen1_controller.v      # Main controller module
├── tb/
│   └── tb_marx_gen1_controller.v   # Self-checking testbench
├── README.md
├── LICENSE
└── .gitignore
```

## Module: `marx_gen1_controller`

**Parameters**

| Parameter           | Default    | Description                                         |
|----------------------|-----------|------------------------------------------------------|
| `CLK_FREQ_HZ`        | 50,000,000 | FPGA system clock (Hz)                              |
| `PWM_FREQ_HZ`        | 1,000      | Pulse repetition frequency `fs` (Hz)                |
| `DISCHARGE_X10000`   | 625        | Discharge window (`5·τ / Ts`) × 10000               |
| `D1_X10000`          | 9088       | `SL` duty ratio `D1` × 10000                        |
| `DEAD_TIME_CYCLES`   | 50         | Dead time around every `SL` ↔ `SC` transition (clk cycles) |

**Ports**

| Port     | Dir | Description                              |
|----------|-----|-------------------------------------------|
| `clk`    | in  | System clock                              |
| `rst_n`  | in  | Asynchronous active-low reset             |
| `enable` | in  | Global enable (LOW → all outputs off)     |
| `SL`     | out | Input-inductor charging switch            |
| `SC`     | out | Capacitor-charging switch                 |
| `S1..S4` | out | Module discharge switches                 |

Outputs are logic-level signals meant to drive the LED side of isolated gate-driver
opto-couplers (e.g. HCPL-3120) — **not** the power MOSFET/IGBT gates directly.

## Simulation

`tb/tb_marx_gen1_controller.v` is a self-checking testbench that:

- Instantiates the controller with a 50 MHz clock and runs 3 full switching periods (3 ms at `fs = 1 kHz`).
- Continuously asserts that `SL` and `SC` are never high at the same clock edge, and stops
  immediately with a `FATAL` message if they are (this is exactly the condition that would
  short-circuit `Vin` in real hardware).
- Dumps a `.vcd` waveform (`marx_gen1_tb.vcd`) for viewing in GTKWave or your simulator.

Run with Icarus Verilog:

```bash
iverilog -o sim.out src/marx_gen1_controller.v tb/tb_marx_gen1_controller.v
vvp sim.out
gtkwave marx_gen1_tb.vcd
```

Or add both files to a Vivado / ModelSim project and run a behavioral simulation.

## Status

This repository currently covers the **Design 1** controller only. The second design
(lower-amplitude, for differential cancer-cell detection) uses the same architecture with
different timing parameters.

## License

Released under the MIT License — see [LICENSE](LICENSE).
