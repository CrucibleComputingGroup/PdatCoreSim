# Randomized Test-Bench for Ibex Core

This directory contains a randomized test-bench for the Ibex RISC-V core that generates constrained-random instruction sequences and produces VCD files for signal correspondence analysis.

## Overview

The test-bench performs two-phase simulation:

1. **Phase 1 (Reset & Flush)**: Execute NOPs for a configurable number of cycles (default 100) to reset and flush the pipeline. This is analogous to ABC's `cycle 100` preprocessing step.

2. **Phase 2 (Randomized)**: Execute constrained-random instructions that respect the assumptions defined in the DSL file.

## VCD Output

The test-bench generates a single comprehensive VCD file:

- **`ibex_random_sim.vcd`**: Complete simulation trace including:
  - **Phase 1** (Cycles 0 to FLUSH_CYCLES-1): Reset and flush with NOPs
  - **Cycle FLUSH_CYCLES**: Initial state checkpoint (post-reset/flush) for signal correspondence
  - **Phase 2** (Cycles FLUSH_CYCLES+): Randomized execution with all internal signals

This unified approach provides both the initial state and execution trace needed for RTL-level signal correspondence analysis.

## Quick Start

```bash
# From project root
./test_ibex_random.sh dsls/example_outlawed.dsl
```

This will:
1. Generate SystemVerilog constraints from the DSL
2. Compile the testbench with VCS
3. Run simulation and produce VCD files

## Usage

```bash
./test_ibex_random.sh <rules.dsl> [OPTIONS]
```

### Options

- `--flush-cycles N` - Number of NOP cycles for reset/flush (default: 100)
- `--random-cycles N` - Number of randomized cycles to simulate (default: 1000)
- `--3stage` - Enable Ibex 3-stage pipeline (WritebackStage=1)
- `--output-dir DIR` - Output directory for VCDs and logs (default: output/)

### Examples

```bash
# Basic simulation with default settings
./test_ibex_random.sh dsls/example_outlawed.dsl

# Custom cycle counts
./test_ibex_random.sh dsls/example_outlawed.dsl --flush-cycles 200 --random-cycles 5000

# 3-stage pipeline
./test_ibex_random.sh dsls/example_outlawed.dsl --3stage

# Custom output directory
./test_ibex_random.sh dsls/my_rules.dsl --output-dir output/my_test
```

## Directory Structure

```
test/
├── README.md                       # This file
├── tb_ibex_random.sv               # Top-level testbench with VCD control
├── tb_modules/                     # Testbench components
│   ├── instr_mem_randomizer.sv     # Randomized instruction memory
│   └── simple_data_mem.sv          # Simple data memory model
└── scripts/
    └── compile_vcs.sh              # VCS compilation script
```

## Architecture

### Testbench Components

1. **`tb_ibex_random.sv`**: Top-level testbench
   - Instantiates Ibex core
   - Controls clock and reset
   - Manages VCD dumping (two-phase)
   - Configurable via parameters

2. **`instr_mem_randomizer.sv`**: Instruction Memory Model
   - Phase 1: Returns NOP instructions
   - Phase 2: Returns constrained-random instructions
   - Uses SystemVerilog `randomize()` with constraints from DSL

3. **`simple_data_mem.sv`**: Data Memory Model
   - Simple behavioral memory (64KB default)
   - Single-cycle response
   - Supports byte, halfword, and word accesses

### Constraint Generation

The `scripts/generate_random_constraints.py` script converts DSL rules into SystemVerilog constraints:

```systemverilog
class instr_constraints;
    rand logic [31:0] instr_word;

    // Valid instruction encodings from required extensions
    constraint valid_encoding { ... }

    // Outlawed instruction patterns
    constraint no_outlawed_instrs { ... }

    // Register constraints (format-aware)
    constraint valid_registers { ... }
endclass
```

## Parameters

The testbench is highly parameterizable:

### Simulation Parameters
- `FLUSH_CYCLES` (default: 100) - Cycles for reset/flush phase
- `RANDOM_CYCLES` (default: 1000) - Cycles for random simulation
- `CLK_PERIOD` (default: 10) - Clock period in ns (100MHz)

### Ibex Configuration
- `PMPEnable` (default: 0) - Enable Physical Memory Protection
- `RV32M` (default: 1) - Enable M extension
- `WritebackStage` (default: 0) - Enable 3-stage pipeline
- `MemECC` (default: 0) - Enable memory ECC

### Memory Configuration
- `DATA_MEM_SIZE` (default: 65536) - Data memory size in bytes
- `DATA_BASE_ADDR` (default: 0x00010000) - Data memory base address
- `BOOT_ADDR` (default: 0x00000080) - Boot address

## Requirements

- **VCS** (Synopsys) - Required for simulation
- **Python 3.7+** - For constraint generation
- **Ibex core** - Initialized as git submodule in `cores/ibex`

## Workflow

1. **Define constraints** in DSL file (see `dsls/` for examples)
2. **Run test script**: `./test_ibex_random.sh <dsl_file>`
3. **Analyze VCDs**: Use generated VCD files for signal correspondence

### Signal Correspondence Framework Integration

The generated VCD is designed for use with RTL-level signal correspondence tools:

- **`ibex_random_sim.vcd`** provides both:
  - Initial state at cycle FLUSH_CYCLES (analogous to ABC's `cycle 100` checkpoint)
  - Signal traces during randomized execution for discovering equivalent signals

## Troubleshooting

### Randomization Failures

If you see `Failed to randomize instruction` errors:
- Check that your DSL constraints are not overly restrictive
- Ensure `require` directives specify valid extensions
- Verify register constraints are reasonable

### Compilation Errors

If VCS compilation fails:
- Verify VCS is in your PATH: `which vcs`
- Check that Ibex submodule is initialized: `git submodule update --init`
- Review file paths in `test/scripts/compile_vcs.sh`

### Simulation Hangs

If simulation appears to hang:
- Check for infinite loops in random instruction sequences
- Verify data memory address ranges
- Increase timeout in testbench if needed

## Future Enhancements

- [ ] Support for interrupts during random phase
- [ ] Debug interface randomization
- [ ] FSDB format support for large traces
- [ ] Constrained-random memory initialization
- [ ] Coverage-driven test generation
