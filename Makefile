
# Modify this variable to fit your NEORV32 setup (neorv32 home folder)
NEORV32_HOME ?= ../neorv32

include $(NEORV32_HOME)/sw/common/common.mk

# QUARTUS_DIR=/media/disk_512gb/tools/intelFPGA_lite/21.1/quartus/bin
QUARTUS_DIR=/home/betocool/opt/intelFPGA_lite/21.1/quartus/bin
QUARTUS_MAP=$(QUARTUS_DIR)/quartus_map
QUARTUS_FIT=$(QUARTUS_DIR)/quartus_fit
QUARTUS_ASM=$(QUARTUS_DIR)/quartus_asm
QUARTUS_STA=$(QUARTUS_DIR)/quartus_sta
QUARTUS_CPF=$(QUARTUS_DIR)/quartus_cpf
QUARTUS_NPP=$(QUARTUS_DIR)/quartus_npp
QUARTUS_PGM=$(QUARTUS_DIR)/quartus_pgm

fpga:: syn fit fgpa-asm sta cpf

syn::
	$(QUARTUS_MAP) --read_settings_files=on --write_settings_files=off neorv32_amp -c neorv32_amp

fit::
	$(QUARTUS_FIT) --read_settings_files=off --write_settings_files=off neorv32_amp -c neorv32_amp

fgpa-asm::
	$(QUARTUS_ASM) --read_settings_files=off --write_settings_files=off neorv32_amp -c neorv32_amp

sta::
	$(QUARTUS_STA) neorv32_amp -c neorv32_amp
	
cpf::
	$(QUARTUS_CPF) -c neorv32_amp.cof
	$(QUARTUS_CPF) -c neorv32_amp_flash.cof

npp::
	$(QUARTUS_NPP) neorv32_amp -c neorv32_amp --netlist_type=sgate

pgm::
	$(QUARTUS_PGM) -c USB-Blaster ./neorv32_amp.cdf

flash::
	$(QUARTUS_PGM) -c USB-Blaster ./neorv32_amp_flash.cdf

NEORV32_LOCAL_RTL=../neorv32/rtl
FIFO_RTL=../fifo

GHDL=~/ghdl/bin/ghdl

# Simulate all
sim_all:: sim_add sim_analysis sim_run

# Add files to the project
sim_add::
	$(GHDL) -i --std=08 --workdir=build --work=neorv32 \
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
	$(GHDL) -m --std=08 --workdir=build --work=neorv32 neorv32_amp_tb

# Run the simulation
sim_run::
	$(GHDL) -r --std=08 --workdir=build --work=neorv32 neorv32_amp_tb --ieee-asserts=disable --stop-time=170us --wave=cpu.ghw

sim_clean::
	rm -rf ./build/*

#
# DAC Simulation
#

DAC_FILES=		./dac.vhd \
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

# Run the simulation
sim_dac_run::
	$(GHDL) -r --std=08 --workdir=build --work=dac  $(DAC_TB) --ieee-asserts=disable --stop-time=5ms --wave=dac.ghw 

sim_dac_clean::
	rm -rf ./build/*