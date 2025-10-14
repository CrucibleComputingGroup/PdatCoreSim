# Example: RISC-V with only 16 registers (x0-x15)
# This demonstrates using register constraints to reduce the register file

# Specify valid instruction set
require RV32I

# Limit to 16 registers (effectively RV32E)
require_registers x0-x15

# Still outlaw multiplication if not needed
# (Even though we don't require RV32M, we can be explicit)
instruction MUL
instruction MULH
instruction MULHSU
instruction MULHU
instruction DIV
instruction DIVU
instruction REM
instruction REMU
