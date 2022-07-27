#!/bin/bash
# file: simulate.sh

# Show commands as they are executed
set -x

NEORV32_LOCAL_RTL="../neorv32/rtl"

# Add files to the project
ghdl -i --std=08 --workdir=build --work=neorv32 ./neorv32_amp_tb.vhd
ghdl -i --std=08 --workdir=build --work=neorv32 ./neorv32_amp_sim.vhd
ghdl -i --std=08 --workdir=build --work=neorv32 ./adc.vhd
# NEORV32 files
ghdl -i --std=08 --workdir=build --work=neorv32 ${NEORV32_LOCAL_RTL}/core/*.vhd
ghdl -i --std=08 --workdir=build --work=neorv32 ${NEORV32_LOCAL_RTL}/core/mem/*.vhd

# Make: Analysis and elaboration
ghdl -m --std=08 --workdir=build --work=neorv32  neorv32_amp_tb

# Run the simulation
ghdl -r --std=08 --workdir=build --work=neorv32 neorv32_amp_tb --stop-time=100us --wave=cpu.ghw

