# JasperGold TCL script for formal verification of RV32E processor

# Clear previous analysis
clear -all

# Read design files
analyze -sv09 \
    ../target/riscv_core.sv \
    ../target/datapath.sv \
    ../target/control.sv \
    ../target/regfile.sv \
    ../target/alu.sv \
    ../target/immgen.sv \
    ../target/branch_comp.sv \
    riscv_properties.sv

# Elaborate the design
elaborate -top RiscvSingleCycle_riscv_core

# Set up clocks
clock -infer
reset -none

# Configure proof settings
set_prove_time_limit 60s
set_prove_per_property_time_limit 30s

# Set engine mode for best performance
set_engine_mode {Hp Ht B I N}

# Prove all assertions
prove -all

# Generate reports
report

# Optional: Generate coverage report
# check_cov -init
# check_cov -prove -time_limit 120s
# check_cov -report

puts "Formal verification complete!"
puts "Check results above for any failures."
