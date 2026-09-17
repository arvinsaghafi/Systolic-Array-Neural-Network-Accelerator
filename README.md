# Systolic Array Neural Network Accelerator

A hardware acceleration project connecting high-level neural-network development in PyTorch with low-level RTL design in SystemVerilog. This repository contains a parameterized 4×4 weight-stationary systolic-array core, a self-checking verification environment, an INT8 quantization pipeline, and a Quartus project targeting the Intel MAX 10 FPGA used on the DE10-Lite.

The current implementation verifies one 4×4 tile of the first MNIST fully connected layer. It is an accelerator core rather than a complete board-level MNIST inference system.

## Overview

Matrix-vector multiplication is a fundamental operation in neural-network inference. This project accelerates that operation using a 4×4 grid of processing elements that reuse stationary weights while activations and partial sums move through the array.

The default design contains 16 signed INT8 multiply-accumulate processing elements, an input-skew buffer for data alignment, 32-bit partial sums, and per-column output-valid tracking.

**Key Features:**

- **Weight-Stationary Architecture:** Weights are loaded into the processing elements and held constant while consecutive input vectors move through the array.
- **Pipelined Dataflow:** The skew buffer delays each input row by 0–3 cycles, allowing the array to accept one four-element vector per cycle after weight loading.
- **Self-Checking Verification:** Questa testbenches automatically verify reset, weight loading, signed arithmetic, accumulation, output values, and pipeline timing.
- **INT8 Quantization:** A PyTorch script quantizes 50,816 MLP weights from FP32 to INT8, reducing packed weight storage by 75%.
- **MAX 10 Synthesis:** Quartus successfully synthesizes and fits the core for the `10M50DAF484C7G` at a constrained 50 MHz clock frequency.

## Architecture

The design consists of four SystemVerilog modules:

1. **Processing Element (`pe.sv`):** Contains a signed 8×8 multiplier, a stationary weight register, a 32-bit partial-sum register, and an activation-forwarding register.

2. **Input-Skew Buffer (`input_skew.sv`):** Delays input row `i` by `i` clock cycles so that values arrive at the correct array diagonal.

3. **Systolic Array (`systolic_array.sv`):** Instantiates the parameterized grid of processing elements. Activations move horizontally while partial sums move vertically.

4. **Top-Level Wrapper (`sanna.sv`):** Selects between weight-loading and compute paths, bypasses the skew buffer during weight loading, and generates one valid signal for each output column.

Each processing element computes:

```text
y_out = y_in + (weight × x_in)
```

## Performance Metrics

Quartus Prime Lite 25.1 successfully synthesized and fitted the default 4×4 configuration for the Intel MAX 10 `10M50DAF484C7G`.

| Metric | Result |
|---|---:|
| Processing elements | 16 |
| Clock constraint | 50 MHz |
| Input and weight precision | Signed INT8 |
| Partial-sum precision | Signed INT32 |
| Logic elements | 672 / 49,760 (1%) |
| Registers | 663 |
| Embedded multiplier elements | 16 / 288 (6%) |
| Worst-case setup slack | +8.057 ns |
| Worst-case hold slack | +0.423 ns |
| Theoretical peak throughput | 1.6 GOPS |

The theoretical throughput is calculated as:

```text
50 MHz × 16 MACs/cycle = 800 MMAC/s
800 MMAC/s × 2 operations/MAC = 1.6 GOPS
```

The 1.6 GOPS figure is a theoretical steady-state peak that counts multiplication and addition as separate operations. It does not include weight-loading, pipeline-fill, memory-transfer, or other system-level overhead.

The timing results apply to the internal accelerator core. External I/O timing and physical DE10-Lite pin assignments are not currently defined.

## Software Pipeline

`software/train_mnist.py` performs the following steps:

1. Trains a bias-free `784 → 64 → 10` multilayer perceptron for one epoch on the MNIST training set.
2. Evaluates the FP32 model on the MNIST test set.
3. Symmetrically quantizes the FC1 and FC2 weight matrices to signed INT8.
4. Reevaluates the model using weights reconstructed from the INT8 values and their scale factors.
5. Exports both weight matrices and one test image in hexadecimal format for SystemVerilog `$readmemh`.
6. Saves the measured accuracy, quantization scales, weight counts, and storage requirements in `quantization_report.json`.

### Quantization Results

| Metric | Result |
|---|---:|
| Training images | 60,000 |
| Test images | 10,000 |
| FP32 test accuracy | 89.08% |
| INT8 weight-quantized test accuracy | 89.15% |
| Accuracy change | +0.07 percentage points |
| Total weights | 50,816 |
| Packed FP32 weight storage | 203,264 bytes |
| Packed INT8 weight storage | 50,816 bytes |
| Weight-storage reduction | 75% |

The accuracy result measures weight quantization in PyTorch. It is not a full integer-arithmetic or RTL classification result. The storage comparison refers to packed numerical weights rather than the size of the human-readable hexadecimal files.

## Repository Structure

```text
├── rtl/
│   ├── sanna.sv                  # Top-level wrapper and valid pipeline
│   ├── systolic_array.sv         # Parameterized PE grid
│   ├── pe.sv                     # Multiply-accumulate processing element
│   └── input_skew.sv             # Input-alignment buffer
├── sim/
│   ├── tb_pe.sv                  # Self-checking PE testbench
│   ├── tb_sanna.sv               # Self-checking array testbench
│   └── sanna_verify.mpf          # Questa simulation project
├── software/
│   ├── train_mnist.py            # Training, evaluation, and quantization
│   ├── fc1_weights.txt           # 50,176 hexadecimal INT8 FC1 weights
│   ├── fc2_weights.txt           # 640 hexadecimal INT8 FC2 weights
│   ├── test_image.txt            # 784 hexadecimal INT8 pixels
│   └── quantization_report.json  # Accuracy and storage measurements
├── sanna.qpf                     # Quartus project
├── sanna.qsf                     # Quartus project settings
├── sanna.sdc                     # 50 MHz timing constraint
└── README.md
```

## Quick Start

### Prerequisites

- Python 3.10 or later
- PyTorch, Torchvision, and NumPy
- Siemens Questa or another SystemVerilog simulator
- Intel Quartus Prime Lite

The project was tested with Questa Altera Starter FPGA Edition 2025.2 and Quartus Prime Lite 25.1.

### 1. Train and Quantize the MLP

Create a virtual environment:

```bash
python3 -m venv .venv
```

Activate it on Linux or macOS:

```bash
source .venv/bin/activate
```

Activate it on Windows:

```powershell
.venv\Scripts\activate
```

Install the required packages:

```bash
python -m pip install --upgrade pip
python -m pip install numpy torch torchvision
```

Run the software pipeline from the repository root:

```bash
python software/train_mnist.py
```

This generates:

- `software/fc1_weights.txt`
- `software/fc2_weights.txt`
- `software/test_image.txt`
- `software/quantization_report.json`

### 2. Run the Self-Checking Simulations

Ensure the Questa executables are available through your system `PATH`, then run:

```bash
vlib work

vlog -sv \
  rtl/pe.sv \
  rtl/input_skew.sv \
  rtl/systolic_array.sv \
  rtl/sanna.sv \
  sim/tb_pe.sv \
  sim/tb_sanna.sv

vsim -c work.tb_pe \
  -do "run -all; quit -f"

vsim -c work.tb_sanna \
  -do "run -all; quit -f"
```

Successful simulations end with:

```text
PE SELF-CHECK PASSED: 8 checks completed
SANNA SELF-CHECK PASSED: 8 results from 2 back-to-back vectors verified
```

### 3. Compile the Quartus Project

Open `sanna.qpf` in Quartus Prime Lite and select Start Compilation.

Alternatively, if the Quartus executables are available through your system `PATH`, run:

```bash
quartus_sh --flow compile sanna
```

## Verification and Results

The verification environment loads the Python-generated hexadecimal weights and pixels into simulated memory.

### Processing-Element Verification

`tb_pe.sv` performs eight directed checks covering:

- Asynchronous reset
- Positive and negative weight loading
- Positive and negative multiplication
- Incoming partial-sum accumulation
- Two negative operands
- Reset during activity

All eight checks pass with zero simulation errors.

### Systolic-Array Verification

`tb_sanna.sv` loads the first 4×4 FC1 weight tile and injects two four-element input vectors on consecutive cycles. A signed reference model inside the testbench checks every output value and each column’s valid cycle.

| Check | Input vector | Output column | RTL result | Reference result | Valid cycle | Status |
|---:|---:|---:|---:|---:|---:|:---:|
| 0 | 0 | 0 | 6985 | 6985 | 3 | Pass |
| 1 | 1 | 0 | -697 | -697 | 4 | Pass |
| 2 | 0 | 1 | 11684 | 11684 | 4 | Pass |
| 3 | 1 | 1 | -1314 | -1314 | 5 | Pass |
| 4 | 0 | 2 | 6985 | 6985 | 5 | Pass |
| 5 | 1 | 2 | 269 | 269 | 6 | Pass |
| 6 | 0 | 3 | 6223 | 6223 | 6 | Pass |
| 7 | 1 | 3 | -3179 | -3179 | 7 | Pass |

All eight results match the SystemVerilog reference model. Column 0 becomes valid first, followed by columns 1–3 on successive cycles.

The verified Questa run completed with:

- 0 compilation errors
- 0 compilation warnings
- 8/8 PE checks passed
- 8/8 array outputs passed

## Current Limitations

- The RTL verifies one 4×4 tile of the FC1 layer rather than complete `784 × 64` FC1 computation.
- FC2 weights are trained and exported but are not consumed by the RTL.
- MNIST classification accuracy is measured in PyTorch rather than through complete RTL inference.
- External I/O timing and physical DE10-Lite pin assignments are not defined.
- The core has been synthesized and fitted for the MAX 10 but has not been demonstrated on physical hardware.

## Contact

**Arvin Saghafi**  
LinkedIn: https://www.linkedin.com/in/arvinsaghafi/