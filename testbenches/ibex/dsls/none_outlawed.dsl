# Example outlawed instruction specification

# Outlaw all multiply and divide instructions (RV32M extension)

# Outlaw specific patterns
# Example: Outlaw ADD when destination is x0 (NOP-like behavior)

# Low-level pattern example
# pattern 0x00000013 mask 0xFFFFFFFF  # ADDI x0, x0, 0 (canonical NOP)
