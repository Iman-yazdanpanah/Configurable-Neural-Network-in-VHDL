#  Configurable Neural Network in VHDL

A simulation-first neural-network library written in **VHDL** and developed with **AMD/Xilinx Vivado 2019**. The goal is to build a configurable, fixed-point multilayer perceptron (MLP) whose forward pass, backpropagation, and parameter updates are implemented in hardware-oriented VHDL—not delegated to Python or a software ML framework.

> **Project status:** Experimental / under development. The current training-system testbench runs in Vivado behavioral simulation. Training behavior and fixed-point update precision are still being investigated.

## Goals

- Build reusable neural-network components in VHDL.
- Configure the network architecture through generics.
- Use signed fixed-point arithmetic suitable for hardware implementation.
- Simulate the complete forward-and-training workflow without requiring a physical FPGA board.
- Develop toward a reusable library that can later be synthesized and adapted to FPGA hardware.

## Current features

- Configurable MLP layer sizes.
- Dense layers and neuron-level multiply-accumulate operations.
- ReLU activation for hidden layers and linear activation for the output layer.
- Fixed-point forward inference.
- Backpropagation for output and hidden layers.
- Sequential weight and bias updates through a parameter-memory interface.
- Configurable learning rate and training parameters.
- Testbench-driven training and evaluation with diagnostic simulation reports.

## Current configuration

The main training testbench currently uses:

| Setting | Value |
|---|---|
| Tool | Vivado 2019 |
| HDL | VHDL |
| Network architecture | `2 → 4 → 4 → 2` |
| Data width | 16 bits |
| Fractional bits | 9 (Q9) |
| Accumulator width | 40 bits |
| Gradient width | 32 bits |
| Maximum epochs | 50 |
| Learning rate | Raw Q9 value `2` |
| Samples used for training | 3 |
| Final inference check | 1 additional input |

With Q9 representation, a raw integer value is interpreted as:

\[
x_{\text{real}} = \frac{x_{\text{raw}}}{2^9}
\]

For example, raw value `512` represents `1.0`, and raw value `1024` represents `2.0`.

The learning-rate signal is a **fixed-point raw value**. Therefore, `to_signed(2, DATA_WIDTH)` represents \(2/512 = 0.00390625\), not a learning rate of `2.0`.

## Architecture overview

The current design is organized around these main modules:

| Module | Responsibility |
|---|---|
| `nn_types.vhd` | Shared types and functions for network sizes and parameter counts |
| `neuron.vhd` | Fixed-point weighted sum, bias addition, activation, and output saturation |
| `dense_layer.vhd` | Connects multiple neurons to form a dense layer |
| `dense_layer_memory.vhd` | Loads and supplies a layer's weights and biases |
| `configurable_mlp_memory.vhd` | Builds the configurable network and provides parameter memory access |
| `configurable_backpropagation.vhd` | Calculates output/hidden deltas and weight/bias gradients |
| `sequential_parameter_updater.vhd` | Applies parameter updates sequentially through the memory interface |
| `training_system.vhd` | Coordinates forward passes, gradient capture, and parameter updates |
| `training_system_tb.vhd` | Provides training samples, targets, evaluation, and simulation diagnostics |

Module names and interfaces may evolve as the project develops.

## Running the simulation

1. Open the project in **Vivado 2019**.
2. Ensure the VHDL source files and the testbench are included in the project.
3. Set `training_system_tb` as the simulation top.
4. Run **Behavioral Simulation**.
5. Inspect the Tcl console and waveform window for initialization, gradient, parameter-update, epoch-error, and final-inference reports.

The project is designed to be developed and tested in simulation; a physical FPGA board is not currently required.

## Current training experiment

The current testbench uses three training samples with two inputs and two outputs. The two output targets are intentionally identical in this experiment.

At learning-rate raw Q9 value `2`, the reported post-update evaluation error decreased from approximately **3064 at epoch 1** to **2458 at epoch 50**. This shows some improvement, but the network has **not yet demonstrated convergence** on this experiment.

A higher tested learning rate of raw value `8` caused unstable error growth. A test with raw value `4` performed worse than the raw value `2` baseline in the latest experiment, so the current baseline remains `2`.

These results are specific to the current initialization, dataset, fixed-point arithmetic, and testbench. They should not be interpreted as a general performance benchmark.

## Known limitations and next steps

- **Fixed-point update precision:** small updates can be truncated to zero when the learning-rate/gradient product is shifted right. A future improvement is to retain fractional update remainders or implement a carefully validated rounding strategy.
- **Training quality:** evaluate loss behavior across more samples and epochs, and verify convergence before drawing conclusions about model performance.
- **Validation:** add independent test cases for gradients, parameter updates, saturation, negative values, and different network architectures.
- **Configurability:** continue testing different layer sizes and activation choices.
- **Hardware synthesis:** after simulation behavior is validated, review synthesis results and resource usage for a supported FPGA target.

## Scope and expectations

This repository is a learning and engineering project focused on implementing neural-network building blocks in VHDL. It is not yet a production-ready training accelerator, and no claim is made that the current training results match floating-point software frameworks.

## License

Choose and add a license before distributing or accepting contributions. For example, an MIT license may be suitable if you want to allow broad reuse, but select the license intentionally.
