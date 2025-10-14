#!/bin/bash
# VCS Compilation Script for Ibex Randomized Test-Bench
#
# This script compiles the Ibex core with the randomized testbench for VCS simulation.

set -e

# ============================================================================
# Configuration
# ============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$SCRIPTS_ROOT")"

# Default paths
IBEX_ROOT="${PROJECT_ROOT}/cores/ibex"
TB_DIR="${PROJECT_ROOT}/testbenches/ibex"
TB_MODULES_DIR="${TB_DIR}/tb_modules"
OUTPUT_DIR="${PROJECT_ROOT}/output"

# Ibex RTL directories
IBEX_RTL="${IBEX_ROOT}/rtl"
IBEX_VENDOR="${IBEX_ROOT}/vendor/lowrisc_ip"

# VCS options
VCS_OPTS="-sverilog +vcs+lic+wait -full64"
VCS_OPTS+=" -debug_access+all"         # Full debug access for VCD
VCS_OPTS+=" +lint=TFIPC-L"              # Lint warnings
VCS_OPTS+=" -timescale=1ns/1ps"        # Timescale
VCS_OPTS+=" -o simv_ibex_random"       # Output executable name

# Defines
DEFINES="+define+SYNTHESIS"

# ============================================================================
# Parse Arguments
# ============================================================================

CONSTRAINTS_FILE=""
WRITEBACK_STAGE=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --constraints)
            CONSTRAINTS_FILE="$2"
            shift 2
            ;;
        --3stage)
            WRITEBACK_STAGE=1
            DEFINES+=" +define+WRITEBACK_STAGE=1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Compile Ibex randomized testbench with VCS"
            echo ""
            echo "Options:"
            echo "  --constraints FILE  Path to generated constraints file (instr_random_constraints.sv)"
            echo "  --3stage            Enable 3-stage pipeline (WritebackStage=1)"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================================================
# Validate
# ============================================================================

if [ -z "$CONSTRAINTS_FILE" ]; then
    echo "ERROR: --constraints option is required"
    echo "Run with --help for usage information"
    exit 1
fi

if [ ! -f "$CONSTRAINTS_FILE" ]; then
    echo "ERROR: Constraints file not found: $CONSTRAINTS_FILE"
    exit 1
fi

# ============================================================================
# File List Generation
# ============================================================================

echo "=========================================="
echo "VCS Compilation for Ibex Randomized TB"
echo "=========================================="
echo "Ibex RTL:       $IBEX_RTL"
echo "Testbench:      $TB_DIR"
echo "Constraints:    $CONSTRAINTS_FILE"
echo "Output:         simv_ibex_random"
echo ""

# Create temporary file list
FILELIST=$(mktemp)
trap "rm -f $FILELIST" EXIT

cat > "$FILELIST" <<EOF
// Ibex package
${IBEX_RTL}/ibex_pkg.sv

// Ibex RTL files (order matters for dependencies)
${IBEX_RTL}/ibex_alu.sv
${IBEX_RTL}/ibex_compressed_decoder.sv
${IBEX_RTL}/ibex_controller.sv
${IBEX_RTL}/ibex_counter.sv
${IBEX_RTL}/ibex_csr.sv
${IBEX_RTL}/ibex_cs_registers.sv
${IBEX_RTL}/ibex_decoder.sv
${IBEX_RTL}/ibex_ex_block.sv
${IBEX_RTL}/ibex_fetch_fifo.sv
${IBEX_RTL}/ibex_id_stage.sv
${IBEX_RTL}/ibex_if_stage.sv
${IBEX_RTL}/ibex_load_store_unit.sv
${IBEX_RTL}/ibex_multdiv_fast.sv
${IBEX_RTL}/ibex_multdiv_slow.sv
${IBEX_RTL}/ibex_prefetch_buffer.sv
${IBEX_RTL}/ibex_pmp.sv
${IBEX_RTL}/ibex_wb_stage.sv
${IBEX_RTL}/ibex_register_file_ff.sv
${IBEX_RTL}/ibex_core.sv

// Lowrisc IP primitives
${IBEX_VENDOR}/ip/prim/rtl/prim_assert.sv

// Constraints (generated from DSL)
${CONSTRAINTS_FILE}

// Testbench modules
${TB_MODULES_DIR}/simple_data_mem.sv
${TB_MODULES_DIR}/instr_mem_randomizer.sv

// Top-level testbench
${TB_DIR}/tb_ibex_random.sv
EOF

# ============================================================================
# Compile with VCS
# ============================================================================

echo "Compiling with VCS..."
echo ""

# Include paths
INCDIR="+incdir+${IBEX_RTL}"
INCDIR+=" +incdir+${IBEX_VENDOR}/ip/prim/rtl"
INCDIR+=" +incdir+${IBEX_VENDOR}/dv/sv/dv_utils"
INCDIR+=" +incdir+${TB_MODULES_DIR}"

# Run VCS
vcs $VCS_OPTS $DEFINES $INCDIR -f "$FILELIST"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Compilation Successful!"
    echo "=========================================="
    echo "Executable: simv_ibex_random"
    echo ""
    echo "To run simulation:"
    echo "  ./simv_ibex_random"
    echo ""
    echo "To run with custom parameters:"
    echo "  ./simv_ibex_random +FLUSH_CYCLES=100 +RANDOM_CYCLES=1000"
    echo ""
else
    echo ""
    echo "ERROR: VCS compilation failed"
    exit 1
fi
