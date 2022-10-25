
all:: syn fit asm sta cpf

syn::
	quartus_map --read_settings_files=on --write_settings_files=off neorv32_amp -c neorv32_amp

fit::
	quartus_fit --read_settings_files=off --write_settings_files=off neorv32_amp -c neorv32_amp

asm::
	quartus_asm --read_settings_files=off --write_settings_files=off neorv32_amp -c neorv32_amp

sta::
	quartus_sta neorv32_amp -c neorv32_amp
	
cpf::
	quartus_cpf -c neorv32_amp.cof

npp::
	quartus_npp neorv32_amp -c neorv32_amp --netlist_type=sgate

NEORV32_LOCAL_RTL=../neorv32/rtl
FIFO_RTL=../fifo

# Simulate all
sim_all:: sim_add sim_analysis sim_run

# Add files to the project
sim_add::
	ghdl -i --std=08 --workdir=build --work=neorv32 \
				./neorv32_amp_tb.vhd \
				./neorv32_amp_sim.vhd \
				./adc.vhd \
				./dac.vhd \
				$(NEORV32_LOCAL_RTL)/core/*.vhd \
				$(NEORV32_LOCAL_RTL)/core/mem/neorv32_dmem.default.vhd \
				$(NEORV32_LOCAL_RTL)/core/mem/neorv32_imem.default.vhd \
				$(FIFO_RTL)/fifo.vhd

# Elaborate
sim_analysis::
	ghdl -m --std=08 --workdir=build --work=neorv32 neorv32_amp_tb

# Run the simulation
sim_run::
	ghdl -r --std=08 --workdir=build --work=neorv32 neorv32_amp_tb --ieee-asserts=disable --stop-time=170us --wave=cpu.ghw

sim_clean::
	rm -rf ./build/*

#
# DAC Simulation
#

# Simulate dac
sim_dac:: sim_dac_add sim_dac_analysis sim_dac_run

# Add files to the project
sim_dac_add::
	ghdl -i --std=08 --workdir=build --work=dac \
				./dac_tb.vhd \
				./dac.vhd

# Elaborate
sim_dac_analysis::
	ghdl -m --std=08 --workdir=build --work=dac dac_tb

# Run the simulation
sim_dac_run::
	ghdl -r --std=08 --workdir=build --work=dac dac_tb --ieee-asserts=disable --stop-time=2ms --wave=dac.ghw

sim_dac_clean::
	rm -rf ./build/*