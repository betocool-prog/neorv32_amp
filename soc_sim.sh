#!/bin/bash
# file: simulate.sh

# Show commands as they are executed
# set -x

NEORV32_LOCAL_RTL="../neorv32/rtl"

# Add files to the project
ghdl -i --std=08 --workdir=build --work=neorv32 \
            ./neorv32_amp_tb.vhd \
            ./neorv32_amp_sim.vhd \
            ./adc.vhd \
            ${NEORV32_LOCAL_RTL}/core/*.vhd \
            ${NEORV32_LOCAL_RTL}/core/mem/neorv32_dmem.default.vhd \
            ${NEORV32_LOCAL_RTL}/core/mem/neorv32_imem.default.vhd

if [ "$?" -ne "0" ]; then
  echo "Sorry, couldn't find a file"
  exit 1
fi



# Make: Analysis and elaboration
ghdl -m --std=08 --workdir=build --work=neorv32  neorv32_amp_tb
if [ "$?" -ne "0" ]; then
  echo "Error during analysis and elaboration"
  exit 1
fi

# Run the simulation
ghdl -r --std=08 --workdir=build --work=neorv32 neorv32_amp_tb --ieee-asserts=disable --stop-time=50us --wave=cpu.ghw

