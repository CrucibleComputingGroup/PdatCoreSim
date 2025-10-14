#!/bin/bash
# End-to-end script: DSL file → Randomized Ibex Simulation with VCDs
#
# Usage: ./test_ibex_random.sh <rules.dsl> [OPTIONS]

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Defaults
FLUSH_CYCLES=100
RANDOM_CYCLES=1000
WRITEBACK_STAGE=false
CONSTANTS_ONLY=false
OUTPUT_DIR="${PROJECT_ROOT}/output"

# ============================================================================
# Parse Arguments
# ============================================================================

show_help() {
    cat << EOF
Usage: $0 <rules.dsl> [OPTIONS]

Generate and run randomized simulation of Ibex core with instruction constraints

Arguments:
  rules.dsl           DSL file with instruction constraints

Options:
  --flush-cycles N    Number of NOP cycles for reset/flush (default: 100)
  --random-cycles N   Number of randomized cycles to simulate (default: 1000)
  --3stage            Enable Ibex 3-stage pipeline (WritebackStage=1)
  --constants-only    Only output constant (0/1) signal correspondences in JSON
  --output-dir DIR    Output directory for VCDs and logs (default: output/)
  -h, --help          Show this help message

Examples:
  # Basic simulation with default settings
  $0 dsls/example_outlawed.dsl

  # Custom cycle counts
  $0 dsls/example_outlawed.dsl --flush-cycles 200 --random-cycles 5000

  # 3-stage pipeline
  $0 dsls/example_outlawed.dsl --3stage

Output Files:
  <output_dir>/instr_random_constraints.sv - Generated constraint class
  <output_dir>/ibex_reset_state.vcd        - State snapshot at cycle FLUSH_CYCLES
  <output_dir>/ibex_random_sim.vcd         - Full trace during random phase
  simv_ibex_random                          - VCS executable (in current dir)

EOF
}

# Parse command line
DSL_FILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --flush-cycles)
            FLUSH_CYCLES="$2"
            shift 2
            ;;
        --random-cycles)
            RANDOM_CYCLES="$2"
            shift 2
            ;;
        --3stage)
            WRITEBACK_STAGE=true
            shift
            ;;
        --constants-only)
            CONSTANTS_ONLY=true
            shift
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -*)
            echo "ERROR: Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$DSL_FILE" ]; then
                DSL_FILE="$1"
            else
                echo "ERROR: Multiple DSL files specified"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate
if [ -z "$DSL_FILE" ]; then
    echo "ERROR: DSL file required"
    show_help
    exit 1
fi

if [ ! -f "$DSL_FILE" ]; then
    echo "ERROR: DSL file not found: $DSL_FILE"
    exit 1
fi

# Validate cycle counts
if ! [[ "$FLUSH_CYCLES" =~ ^[0-9]+$ ]] || [ "$FLUSH_CYCLES" -lt 1 ]; then
    echo "ERROR: --flush-cycles must be a positive integer"
    exit 1
fi

if ! [[ "$RANDOM_CYCLES" =~ ^[0-9]+$ ]] || [ "$RANDOM_CYCLES" -lt 1 ]; then
    echo "ERROR: --random-cycles must be a positive integer"
    exit 1
fi

# Convert DSL_FILE to absolute path before changing directory
DSL_FILE=$(realpath "$DSL_FILE")

# Create output directory
mkdir -p "$OUTPUT_DIR"

CONSTRAINTS_FILE="${OUTPUT_DIR}/instr_random_constraints.sv"

# ============================================================================
# Summary
# ============================================================================

echo "=========================================="
echo "Ibex Randomized Simulation"
echo "=========================================="
echo "DSL File:       $DSL_FILE"
echo "Flush Cycles:   $FLUSH_CYCLES"
echo "Random Cycles:  $RANDOM_CYCLES"
echo "Output Dir:     $OUTPUT_DIR"
echo "Pipeline:       $([ "$WRITEBACK_STAGE" = true ] && echo '3-stage' || echo '2-stage')"
echo ""

TOTAL_STEPS=5

# ============================================================================
# Step 1: Generate Constraints
# ============================================================================

echo "[1/$TOTAL_STEPS] Generating randomization constraints from DSL..."
pdat-dsl random-constraints "$DSL_FILE" "$CONSTRAINTS_FILE" -v

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to generate constraints"
    exit 1
fi

echo "  → Generated: $CONSTRAINTS_FILE"
echo ""

# ============================================================================
# Step 2: Compile with VCS
# ============================================================================

echo "[2/$TOTAL_STEPS] Compiling testbench with VCS..."

COMPILE_OPTS="--constraints $CONSTRAINTS_FILE"
if [ "$WRITEBACK_STAGE" = true ]; then
    COMPILE_OPTS+=" --3stage"
fi

"${PROJECT_ROOT}/scripts/ibex/compile_vcs.sh" $COMPILE_OPTS

if [ $? -ne 0 ]; then
    echo "ERROR: VCS compilation failed"
    exit 1
fi

echo ""

# ============================================================================
# Step 3: Run Simulation
# ============================================================================

echo "[3/$TOTAL_STEPS] Running randomized simulation..."
echo ""

# Run VCS simulation (executable is in PROJECT_ROOT after compilation)
"${PROJECT_ROOT}/simv_ibex_random" \
    +FLUSH_CYCLES=$FLUSH_CYCLES \
    +RANDOM_CYCLES=$RANDOM_CYCLES

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Simulation failed"
    exit 1
fi

echo ""

# ============================================================================
# Step 4: Split VCD into two files
# ============================================================================

echo "[3.5/$TOTAL_STEPS] Splitting VCD into initial state and random execution traces..."

# Calculate split time in picoseconds
# Clock period is 10ns = 10000ps, split at cycle FLUSH_CYCLES
SPLIT_TIME_PS=$((FLUSH_CYCLES * 10000))

# VCD files are created in current directory by VCS, move them to output
if [ -f "ibex_combined.vcd" ]; then
    python3 "${PROJECT_ROOT}/scripts/ibex/split_vcd.py" \
        ibex_combined.vcd \
        $SPLIT_TIME_PS \
        "${OUTPUT_DIR}/ibex_reset_state.vcd" \
        "${OUTPUT_DIR}/ibex_random_sim.vcd"

    if [ $? -eq 0 ]; then
        # Remove combined VCD after successful split
        rm -f ibex_combined.vcd
        echo "  → Split complete"
    else
        echo "  → Warning: VCD split failed, keeping combined VCD"
    fi
elif [ -f "ibex_reset_state.vcd" ] && [ -f "ibex_random_sim.vcd" ]; then
    # Already split, just move them
    mv ibex_reset_state.vcd "${OUTPUT_DIR}/"
    mv ibex_random_sim.vcd "${OUTPUT_DIR}/"
    echo "  → VCDs already split, moved to output directory"
else
    echo "  → Warning: VCD files not found"
fi

echo ""

# ============================================================================
# Step 5: Convert Initial State VCD to JSON
# ============================================================================

echo "[4/5] Converting initial state VCD to JSON..."

INITIAL_STATE_JSON="${OUTPUT_DIR}/initial_state.json"

pdat-dsl vcd-to-state \
    "${OUTPUT_DIR}/ibex_reset_state.vcd" \
    "$INITIAL_STATE_JSON"

if [ $? -eq 0 ]; then
    echo "  → Generated: $INITIAL_STATE_JSON"
else
    echo "  → Warning: Initial state JSON conversion failed"
fi

echo ""

# ============================================================================
# Step 6: Find Signal Correspondences
# ============================================================================

echo "[5/5] Analyzing signal correspondences..."

CORRESP_JSON="${OUTPUT_DIR}/signal_correspondences.json"
CORRESP_REPORT="${OUTPUT_DIR}/signal_correspondences.txt"

CORRESP_OPTS=""
if [ "$CONSTANTS_ONLY" = true ]; then
    CORRESP_OPTS="--constants-only"
    CORRESP_JSON="${OUTPUT_DIR}/signal_correspondences_constants.json"
    CORRESP_REPORT="${OUTPUT_DIR}/signal_correspondences_constants.txt"
fi

pdat-dsl find-correspondences \
    "${OUTPUT_DIR}/ibex_random_sim.vcd" \
    "$CORRESP_JSON" \
    --report "$CORRESP_REPORT" \
    $CORRESP_OPTS

if [ $? -eq 0 ]; then
    echo "  → Generated: $CORRESP_JSON"
    echo "  → Report: $CORRESP_REPORT"
else
    echo "  → Warning: Correspondence analysis failed"
fi

echo ""

# ============================================================================
# Success
# ============================================================================

echo "=========================================="
echo "SUCCESS!"
echo "=========================================="
echo "Generated files:"
echo "  - $CONSTRAINTS_FILE (randomization constraints)"
echo "  - ${OUTPUT_DIR}/ibex_reset_state.vcd (initial state VCD)"
echo "  - ${OUTPUT_DIR}/initial_state.json (initial state as JSON)"
echo "  - ${OUTPUT_DIR}/ibex_random_sim.vcd (random execution trace)"
echo "  - $CORRESP_JSON (signal equivalence classes)"
echo "  - $CORRESP_REPORT (human-readable report)"
echo ""
echo "Signal Correspondence Analysis:"
NUM_CLASSES=$(python3 -c "import json; data=json.load(open('$CORRESP_JSON')); print(data['summary']['total_equivalence_classes'])" 2>/dev/null || echo "N/A")
NUM_SIGNALS=$(python3 -c "import json; data=json.load(open('$CORRESP_JSON')); print(data['summary']['total_signals_in_classes'])" 2>/dev/null || echo "N/A")
NUM_ARB_CONST=$(python3 -c "import json; data=json.load(open('$CORRESP_JSON')); print(data['summary']['total_arbitrary_constants'])" 2>/dev/null || echo "N/A")
echo "  - Equivalence classes: $NUM_CLASSES"
echo "  - Signals in classes: $NUM_SIGNALS"
echo "  - Arbitrary constants: $NUM_ARB_CONST"
if [ "$CONSTANTS_ONLY" = true ]; then
    echo "  - Mode: Constants-only (CONSTANT_ZERO/ONES only)"
fi
echo ""
echo "To view VCDs:"
echo "  gtkwave ${OUTPUT_DIR}/ibex_reset_state.vcd"
echo "  gtkwave ${OUTPUT_DIR}/ibex_random_sim.vcd"
echo ""
echo "To view analysis results:"
echo "  python3 -m json.tool ${OUTPUT_DIR}/initial_state.json | less"
echo "  python3 -m json.tool $CORRESP_JSON | less"
echo "  cat $CORRESP_REPORT"
echo ""
