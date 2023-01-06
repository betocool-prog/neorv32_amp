GHDL=~/ghdl/bin/ghdl

#
# DAC Simulation
#

DAC_FILES=		../fifo/fifo.vhd	\
							./dac.vhd 				\
							./dac_tb.vhd

DAC_TB = dac_tb

# Simulate dac
sim_dac:: sim_dac_add sim_dac_analysis sim_dac_run

# Add files to the project
sim_dac_add::
	$(GHDL) -i --std=08 --workdir=build --work=dac $(DAC_FILES)

# Elaborate
sim_dac_analysis::
	$(GHDL) -a --std=08 --workdir=build --work=dac $(DAC_FILES)
	$(GHDL) -e --std=08 --workdir=build --work=dac $(DAC_TB) 

# Run the simulation
sim_dac_run::
	$(GHDL) -r --std=08 --workdir=build --work=dac $(DAC_TB) --ieee-asserts=disable --stop-time=5ms --wave=dac.ghw 

sim_dac_clean::
	rm -rf ./build/*