# DRISC-V

**A 4-Stage Pipelined RISC-V (RV32I) Processor with a Custom Drone Instruction Set Extension (D-ISA) for Autonomous Flight Control and Edge Intelligence**

[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue)]()
[![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Basys--3-green)]()
[![ISA](https://img.shields.io/badge/ISA-RV32I%20%2B%20D--ISA-orange)]()
[![Status](https://img.shields.io/badge/Status-Verified%20on%20FPGA-brightgreen)]()

---

## Overview

DRISC-V is a custom RISC-V processor built from scratch in Verilog HDL, designed to accelerate the computationally intensive math that autonomous drones run constantly — attitude estimation, waypoint navigation, obstacle detection, sensor fusion, and target tracking.

The standard **RV32I** instruction set doesn't have native multiplication, let alone dedicated instructions for vector dot products, magnitude estimation, or sensor fusion. Doing these in software costs dozens of cycles per operation. DRISC-V fixes that by extending RV32I with a **Drone Instruction Set Extension (D-ISA)** — 7 custom instructions executed by a dedicated **Functional Control and Acceleration Unit (FCAU)** that runs in parallel with the ALU inside the execute stage.

Across 5 representative drone benchmarks, DRISC-V cuts execution cycles by **88%** compared to an equivalent RV32I software baseline compiled with the GNU RISC-V toolchain — while running on real FPGA hardware at **55.55 MHz**.

---

## Key Features

- **4-stage pipelined RV32I core** (IF → ID → EX → MEM/WB), designed and implemented from scratch, with data forwarding for hazard resolution
- **7 custom D-ISA instructions** — R-type format, custom opcode/funct encoding, mode-sequenced multi-cycle execution
- **FCAU (Functional Control and Acceleration Unit)** running in parallel with the ALU, selected via execute-stage mux
- **Q16.16 fixed-point arithmetic** — no floating-point unit required
- **Custom hardware multiplier** (RV32I has no native `MUL`)
- **Verified on Xilinx Basys-3 FPGA** via Vivado — synthesis, timing, utilization, and power reports included
- **5 hand-written assembly benchmarks**, each cross-checked against a GNU RISC-V-compiled C software baseline

---

## The Drone Instruction Set Extension (D-ISA)

| Instruction | Function | Drone Application | Latency (cycles) |
|---|---|---|---|
| `VDOT`   | Vector dot product              | Attitude estimation      | 3 |
| `PIDACC` | PID accumulation                | Flight stabilization      | 3 |
| `VMAG`   | Vector magnitude (Alpha-Max Beta-Min) | Velocity computation | 5 |
| `VNORM`  | Vector normalization (dual-LUT reciprocal) | Direction vectors  | 4 |
| `FUSE`   | Multi-sensor fusion              | Navigation                | 2 |
| `THRESH` | Threshold detection (MAX/MIN modes) | Obstacle avoidance    | 1 |
| `SATADD` | Saturating addition (MAX/MIN modes) | Sensor processing     | 1 |
| `EVENT`  | Autonomous event trigger         | Mission logic              | 1 |

All custom instructions use the **R-type** format and are dispatched to the FCAU in parallel with the ALU; an execute-stage multiplexer selects the FCAU result for D-ISA opcodes and the ALU result otherwise.

---

## Architecture

```
        IF STAGE          ID STAGE                    EX STAGE (ALU || FCAU)              MEM / WB STAGE
   ┌───────────────┐  ┌───────────────────┐      ┌─────────────────────────────┐     ┌───────────────────┐
   │ Program        │  │ Instruction        │      │        ┌─────┐              │     │  Data Memory       │
   │ Counter        │  │ Decoder            │      │        │ ALU │──┐           │     │  (Load/Store)      │
   ├────────────────┤  ├────────────────────┤      │        └─────┘  │  ┌─────┐  │     ├────────────────────┤
   │ Instruction    │──▶│ Register File      │──▶   │        ┌─────┐  ├─▶│ MUX │──┼────▶│  Write-Back         │
   │ Memory         │  │ Immediate Generator │      │        │FCAU │──┘  └─────┘  │     │  (Register File)    │
   │                │  │ D-ISA Opcode Recog. │      │        └─────┘  sel=D-ISA?  │     │                     │
   └───────────────┘  └───────────────────┘      └─────────────────────────────┘     └───────────────────┘
          │      IF/ID reg  │        ID/EX reg    │                          EX/MEM reg │
          └──────────────────┴──────────────────────┴──────────────────────────────────┘
                                     ▲ forwarding path (data hazard resolution) ▲
```

The FCAU internally sequences multi-cycle instructions (Table above) through mode-controlled stages — e.g. `VMAG` uses a 5-stage Alpha-Max Beta-Min magnitude estimator, and `VNORM` uses two 16-entry LUTs (integer-range and fractional-range) for reciprocal approximation.

---

## Benchmark Results

Five representative autonomous-drone benchmarks — Attitude Estimation, Waypoint Navigation, Obstacle Detection, Return-to-Home, and Target Tracking — were hand-written in DRISC-V assembly and cross-checked against equivalent C code compiled for RV32I using the GNU RISC-V toolchain (no hardware multiply, no custom instructions).

| Benchmark | DRISC-V Cycles | Instructions | RV32I Baseline (Cycles) | Reduction |
|---|---|---|---|---|
| Attitude Estimation | 8 | 8 | 102 | 92% |
| Waypoint Navigation | 16 | 16 | 168 | 90% |
| Obstacle Detection | 16 | 16 | 169 | 90% |
| Return-to-Home | 16 | 16 | 168 | 90% |
| Target Tracking | 16 | 16 | 267 | 94% |
| **Total** | **99** | **72** | **874** | **88%** |

CPI = 1.375. RV32I baseline assumes software `MUL` (32 cycles) + software `SQRT` (64 cycles), since RV32I lacks hardware multiplication.

### FPGA Implementation (Xilinx Basys-3, Vivado)

| Metric | Result |
|---|---|
| Max operating frequency | **55.55 MHz** (WNS 1.503 ns, target was >50 MHz) |
| Slice LUTs | 2113 / 20800 (10%) |
| Slice Registers | 1073 / 41600 (2.6%) |
| DSP slices used | 8 |
| Total on-chip power | **0.077 W** (Dynamic 0.005 W / Static 0.072 W) |

---

## Repository Structure

```
DRISC-V/
├── prg/
│   └── program.txt            # Assembled program / instruction memory image
├── rtl/
│   ├── alu32.v                 # 32-bit ALU
│   ├── control_unit.v          # Control unit
│   ├── data_mem.v              # Data memory
│   ├── datapath.v              # Top-level datapath wiring
│   ├── ex_mem_reg.v            # EX/MEM pipeline register
│   ├── fcau.v                  # Functional Control and Acceleration Unit (D-ISA)
│   ├── forwarding_unit.v       # Data hazard forwarding logic
│   ├── id_ex_reg.v             # ID/EX pipeline register
│   ├── if_id_reg.v             # IF/ID pipeline register
│   ├── imm_gen.v               # Immediate generator
│   ├── inst_mem.v              # Instruction memory
│   ├── pc.v                    # Program counter
│   ├── regfile.v               # Register file
│   └── top_pipeline.v          # Top-level 4-stage pipelined processor
├── tb/
│   ├── fcau_tb.v               # FCAU unit testbench
│   ├── pipeline_tb.v           # Pipeline testbench
│   └── single_tb.v             # Single-cycle testbench
└── README.md
```

> This tree reflects the current state of the repository and will grow as more benchmarks, testbenches, and simulation scripts are pushed.



---

## Getting Started

### Prerequisites
- Xilinx Vivado Design Suite (tested on Basys-3 / Artix-7 XC7A35T)
- A Verilog simulator for RTL testbenches (Vivado Simulator, Icarus Verilog, or similar)
- GNU RISC-V toolchain (`riscv32-unknown-elf-gcc`) — only needed to regenerate the software baseline

### Simulation
```bash
# Pipeline testbench
iverilog -o sim_out rtl/*.v tb/pipeline_tb.v
vvp sim_out

# FCAU unit testbench
iverilog -o fcau_out rtl/fcau.v tb/fcau_tb.v
vvp fcau_out

# Single-cycle reference testbench
iverilog -o single_out rtl/*.v tb/single_tb.v
vvp single_out
```

### FPGA Implementation
1. Open Vivado, create a new project targeting the Basys-3 (`xc7a35tcpg236-1`).
2. Add all `.v` files under `rtl/` as design sources.
3. Add your Basys-3 constraints (`.xdc`) file.
4. Run Synthesis → Implementation → Generate Bitstream.
5. Program the board via `Open Hardware Manager`.

---

## Design Notes

- **Fixed-point over floating-point:** all FCAU arithmetic uses **Q16.16** fixed-point rather than a floating-point unit, trading a small amount of precision for significantly lower FPGA resource usage and latency.
- **VMAG — Alpha-Max Beta-Min vs. Newton-Raphson:** Newton-Raphson (3 iterations) gives better accuracy (1.94% worst-case error) but costs 14–16 cycles. Alpha-Max Beta-Min was chosen instead for latency (originally 2 cycles, later re-pipelined to 5 cycles to close timing — see below), accepting a higher worst-case error (~17.6%) in exchange for real-time responsiveness.
- **VNORM — dual-LUT reciprocal:** a single integer-indexed LUT badly mis-approximates the reciprocal for small fractional magnitudes (e.g. true `1/0.05 = 20`, but a single LUT would saturate). A second 16-entry fractional-range LUT (`vnorm_lut_frac`) was added specifically to fix this.
- **Timing closure:** the original 2-cycle VMAG implementation failed timing (high WNS/TNS). It was re-pipelined to 4, then 5 cycles to close timing, ultimately enabling the design to run up to 55.55 MHz.

---

## Known Limitations / Future Work

- `VDOT` is currently on the worst timing path at higher frequencies (~75 MHz) — further pipelining is a natural next step.
- VMAG accuracy could be improved with a CORDIC-based implementation (~8 cycles) as an alternative to Alpha-Max Beta-Min.
- No hazard-detection/stall unit beyond forwarding — corner cases involving multi-cycle FCAU instructions may need additional coverage.
- No branch prediction, caches, or OS support — this is a bare-metal, benchmark-driven design.
- Swarm coordination, thermal-camera integration, satellite comms, and mother-child drone (claw-based deployment) integration are proposed extensions, not implemented here.

---

## Author

**Vedika Malpani**
Department of Electronics and Communication Engineering, MNIT Jaipur
Developed during an internship at the VLSI Laboratory, Military College of Telecommunication Engineering (MCTE)

## License

Specify a license (e.g. MIT, Apache 2.0) here before publishing.
