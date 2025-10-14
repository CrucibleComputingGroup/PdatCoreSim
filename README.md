# CoreSim - RISC-V Processor Simulation Framework

Constrained-random simulation framework for RISC-V processor cores with VCD-based signal correspondence analysis.

## Overview

CoreSim provides testbenches and tools for simulating RISC-V processor cores with DSL-constrained instruction sequences. It generates VCD traces for RTL-level signal correspondence analysis and formal verification.

## Supported Cores

- **Ibex** - lowRISC's 2-stage/3-stage RV32IMC core
- *(Future: CVA6, Rocket, BOOM, etc.)*

## Features

- DSL-driven constrained-random instruction generation
- Two-phase simulation (reset/flush + randomized execution)
- VCD generation for signal correspondence analysis
- VCS-based simulation with full debug access
- Automatic JSON extraction (initial state + equivalence classes)

## Quick Start

### Installation

```bash
# 1. Install PdatDsl package
cd ../PdatDsl
pip install -e .

# 2. Initialize core submodules
cd ../CoreSim
git submodule update --init --recursive

# 3. Run Ibex simulation
./run_ibex_random.sh testbenches/ibex/dsls/example_outlawed.dsl
```

### Requirements

- **VCS** (Synopsys) - Commercial simulator required
- **Python 3.7+**
- **pdat-dsl** - Install from ../PdatDsl

## Usage

### Ibex Core Simulation

```bash
./run_ibex_random.sh <dsl_file> [OPTIONS]
```

**Options:**
- `--flush-cycles N` - NOP cycles for reset (default: 100)
- `--random-cycles N` - Random execution cycles (default: 1000)
- `--3stage` - Enable 3-stage pipeline
- `--constants-only` - Filter to constant signals only
- `--output-dir DIR` - Output directory (default: output/)

**Examples:**
```bash
# Basic simulation
./run_ibex_random.sh testbenches/ibex/dsls/example_16reg.dsl

# Extended simulation with 3-stage pipeline
./run_ibex_random.sh testbenches/ibex/dsls/example_outlawed.dsl \
    --flush-cycles 200 --random-cycles 5000 --3stage

# Constants-only analysis
./run_ibex_random.sh testbenches/ibex/dsls/rv32im.dsl --constants-only
```

## Output Files

Each simulation produces:

| File | Description |
|------|-------------|
| `instr_random_constraints.sv` | Generated SV constraint class |
| `ibex_reset_state.vcd` | Initial state at cycle FLUSH_CYCLES |
| `initial_state.json` | Initial FF values as JSON |
| `ibex_random_sim.vcd` | Full randomized execution trace |
| `signal_correspondences.json` | Equivalence classes from trace hashing |
| `signal_correspondences.txt` | Human-readable report |
| `simv_ibex_random` | VCS executable |

## Architecture

### Directory Structure

```
CoreSim/
├── cores/                    # Processor core submodules
│   └── ibex/                # lowRISC Ibex (git submodule)
├── testbenches/
│   └── ibex/
│       ├── tb_ibex_random.sv      # Top-level testbench
│       ├── tb_modules/
│       │   ├── instr_mem_randomizer.sv
│       │   └── simple_data_mem.sv
│       ├── dsls/              # Example DSL files
│       └── README.md
├── scripts/
│   └── ibex/
│       ├── compile_vcs.sh    # VCS compilation
│       └── split_vcd.py      # VCD splitting utility
└── run_ibex_random.sh        # Main entry point
```

### Workflow

1. **DSL → Constraints**: `pdat-dsl random-constraints` generates SV constraint class
2. **Compile**: VCS compiles Ibex + testbench + constraints
3. **Simulate**: Two-phase execution (NOP flush + randomized)
4. **Extract**: VCDs converted to JSON for signal analysis
5. **Analyze**: Hash-based equivalence class discovery

## Integration with RTL-scorr

The generated JSON files are designed for the Yosys `rtl_scorr` plugin:

```bash
# After CoreSim generates JSONs
yosys -m rtl_scorr.so -p "
  read_verilog ibex_core.v
  rtl_scorr output/signal_correspondences_constants.json \
            output/initial_state.json \
            -apply-opt -k 2
"
```

## Adding New Cores

To add support for another core (e.g., CVA6):

1. Add core as submodule: `git submodule add <url> cores/cva6`
2. Create testbench: `testbenches/cva6/`
3. Create compile script: `scripts/cva6/compile_vcs.sh`
4. Create run script: `run_cva6_random.sh`
5. Copy/adapt DSL files to `testbenches/cva6/dsls/`

## License

CC-BY-NC-SA-4.0 - Copyright 2025 Nathan Bleier (nbleier@umich.edu)

Free for non-commercial use. Contact for commercial licensing.

## Related Projects

- **PdatDsl** - DSL for ISA subset specification
- **RtlScorr** - RTL signal correspondence verification (Yosys plugin)
- **ScorrPdat** - Complete RTL scorecard framework
