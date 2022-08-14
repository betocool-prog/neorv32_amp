#!/bin/bash
# file: simulate.sh

# Show commands as they are executed
set -x

# Add files to the project
ghdl -i --std=08 --workdir=pdm_build --work=pdm_test ./pdm.vhd
ghdl -i --std=08 --workdir=pdm_build --work=pdm_test ./pdm_tb.vhd

# Make: Analysis and elaboration
ghdl -m --std=08 --workdir=pdm_build --work=pdm_test pdm_tb

# Run the simulation
ghdl -r --std=08 --workdir=pdm_build --work=pdm_test pdm_tb --stop-time=80us --wave=pdm_wave.ghw

