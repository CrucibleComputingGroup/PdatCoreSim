# Formal Verification for RV32E Single-Cycle Processor

This directory contains formal verification properties and scripts for verifying the correctness of the RV32E single-cycle processor implementation.

## Verification Approach

The verification uses **instruction-level properties** rather than component-level properties. Each RV32E instruction has its own assertion that checks:

1. **For loads and stores**: Correct memory interface signals (address, data, read/write enables)
2. **For all other instructions**: Correct next state (PC and register file updates)

This approach is particularly clean for single-cycle processors since there's a direct mapping from instruction to state transition.

## Files

- `riscv_properties.sv` - SVA properties for all RV32E instructions
- `run_jasper.tcl` - JasperGold TCL script to run formal verification

## Running Verification

### Using JasperGold

```bash
cd formal
jg run_jasper.tcl
```

Or interactively:
```bash
jg -batch run_jasper.tcl
```

## Properties Verified

### Arithmetic/Logical Instructions
- ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
- ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI

### Control Flow Instructions
- JAL, JALR
- BEQ, BNE, BLT, BGE, BLTU, BGEU

### Memory Instructions
- LOAD (LB, LH, LW, LBU, LHU)
- STORE (SB, SH, SW)

### Upper Immediate Instructions
- LUI, AUIPC

### General Properties
- x0 always reads as 0
- PC correctly addresses instruction memory

## Expected Results

All properties should **prove** (not just bounded check). Since this is a single-cycle combinational design with minimal state (just PC and registers), formal verification should complete quickly and provide 100% coverage of the instruction set.

Any **failing** properties indicate bugs in the implementation that need to be fixed.
Any **inconclusive** properties may need stronger assumptions or longer proof times.
