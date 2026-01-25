# Systolic Array Neural Network Accelerator (SANNA)

A hardware acceleration project bridging the gap between High-Level Software (PyTorch) and Low-Level Hardware (SystemVerilog). This repository contains the RTL implementation, verification environment, and software quantization pipeline for a 4x4 Weight-Stationary Systolic Array designed to accelerate Matrix-Vector Multiplication (MVM) for Deep Learning inference.

Targeted for the Intel MAX10 FPGA (DE10-Lite).

## Overview
Deep Learning models are dominated by Matrix Multiplication operations. General-purpose CPUs are often inefficient for these tasks due to the Von Neumann bottleneck (fetching data typically takes more energy than the computation itself).

This project implements a Systolic Array to solve this inefficiency. By arranging Processing Elements (PEs) in a grid and flowing data through them in a rhythmic "wave," this design maximizes data reuse and minimizes memory access latency.

**Key Features:**
- **Weight-Stationary Architecture:** Weights are pre-loaded into PEs and held constant while input vectors flow diagonally across the array.
- **INT8 Quantization:** Custom PyTorch script converts 32-bit floating-point weights to 8-bit integers, reducing memory footprint by 4x with minimal accuracy loss.
- **Hardware-Software Co-Verification:** RTL output is validated against a bit-accurate Python Golden Model.

## Architecture
The design consists of three core hardware modules:
1. **Processing Element (PE):** The fundamental computation unit. Each PE contains a MAC (Multiply-Accumulate) unit and registers to pass inputs to neighbors.
   - Input: 8-bit Integer (Operand A), 8-bit Integer (Operand B).
   - Accumulator: 32-bit Signed Integer (to prevent overflow).

2. **Skew Module:** A triangular buffer system that delays input rows by $0, 1, \dots, N-1$ clock cycles. This ensures that the input "wave" hits the correct diagonal of the array at the correct time.

4. **Systolic Grid:** A 4x4 mesh of PEs.

<img width="2000" height="3082" alt="SANNA_Block_Diagram" src="https://github.com/user-attachments/assets/0f1d7e15-63a4-4753-94cd-0eae7f160ea1" />

## Performance Metrics
- **Device:** Intel MAX10 FPGA (10M50DAF484C7G)
- **Clock Frequency:** 50 MHz
- **Precision:** INT8 Inputs / INT32 Accumulation
- **Logic Usage:** ~272 Logic Elements (< 1% utilization, highly scalable)
- **Theoretical Peak Throughput:** 1.6 GOPS (Giga-Operations per Second)
  - Calculation: $50 \text{ MHz} \times 16 \text{ PEs} \times 2 \text{ Ops/Cycle} = 1.6 \text{ GOPS}$

## Software Pipeline
The train_mnist.py script handles the full lifecycle of the Neural Network data before it reaches the hardware:
1. Training: Trains a Multi-Layer Perceptron (MLP) on the MNIST dataset using PyTorch.
2. Extraction: Extracts trained weights from the Fully Connected layers.
3. Quantization: Maps 32-bit Floating Point weights to the $[-128, 127]$ integer range.
4. Export: Generates `fc1_weights.txt` and `test_image.txt` in a Hexadecimal format compatible with SystemVerilog's `$readmemh`.

## Repository Structure
```
├── rtl/
│   ├── sanna.sv            # Top-Level Wrapper
│   ├── systolic_array.sv   # 4x4 Grid Logic
│   ├── pe.sv               # Processing Element (MAC + Regs)
│   └── input_skew.sv       # Data alignment buffers
├── sim/
│   ├── tb_sanna.sv         # Self-checking Testbench
│   └── sanna_verify.mpf    # Questa Simulation Project
├── software/
│   ├── train_mnist.py      # PyTorch Training & Quantization Script
│   ├── fc1_weights.txt     # Generated Hex Weights
│   └── test_image.txt      # Generated Hex Input Data
├── sanna.sdc               # Timing Constraints (Synopsys Design Constraints)
└── README.md
```
## Quick Start
**Prerequisites**
- Hardware Design: Intel Quartus Prime Lite (v20.1 or later) & Questa/ModelSim.
- Software: Python 3.8+ (PyTorch, NumPy).

**1. Generate Weights**

Run the Python script to train the model and generate the Hex files.
```
# Create virtual environment (Recommended)
python -m venv venv
.\venv\Scripts\activate

# Install dependencies
pip install torch torchvision numpy

# Run training
python train_mnist.py
```
*Output:* This will create `fc1_weights.txt` and `test_image.txt`.

**2. Run Simulation**

  1. Open Questa / ModelSim.
  2. Set the working directory to the project folder.
  3. Run the following TCL commands in the Transcript window:
```
vlog rtl/*.sv sim/tb_sanna.sv
vsim work.tb_sanna
add wave -position insertpoint sim:/tb_sanna/*
run 300 ns
```

## Verification & Results
The design was verified using a self-checking testbench that loads the Python-generated Hex files into simulated memory.
**Waveform Analysis**
The waveform below demonstrates the "Staggered" valid signals characteristic of a Systolic Array.
- **Row 0** becomes valid first.
- **Row 3** becomes valid 3 cycles later.
- The Hex values (e.g., `ffffff81`) correspond to the signed 32-bit result of the dot product calculation.

<img width="1709" height="525" alt="Questa_Results" src="https://github.com/user-attachments/assets/268a3560-c9e2-4891-9dba-3c807123e746" />

<br>**Mathematical Verification**
| Row  | Output (Hex) | Output (Decimal) | Python Reference | Status | 
| :--- | :----:       | :----:           | :----:           | :----: |
| 0    | `ffffff81`   | -127             | -127             | Pass   | 
| 1    | `fffffff8`   | -8               | -8               | Pass   |
| 2    | `fffffb89`   | -1143            | -1143            | Pass   |
| 3    | `fffffc08`   | -1016            | -1016            | Pass   |

## Contact
**Arvin Saghafi**<br>
LinkedIn: https://www.linkedin.com/in/arvinsaghafi/
