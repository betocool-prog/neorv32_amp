-- #################################################################################################
-- # << NEORV32 - Test Setup using the UART-Bootloader to upload and run executables >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2021, Stephan Nolting. All rights reserved.                                     #
-- #                                                                                               #
-- # Redistribution and use in source and binary forms, with or without modification, are          #
-- # permitted provided that the following conditions are met:                                     #
-- #                                                                                               #
-- # 1. Redistributions of source code must retain the above copyright notice, this list of        #
-- #    conditions and the following disclaimer.                                                   #
-- #                                                                                               #
-- # 2. Redistributions in binary form must reproduce the above copyright notice, this list of     #
-- #    conditions and the following disclaimer in the documentation and/or other materials        #
-- #    provided with the distribution.                                                            #
-- #                                                                                               #
-- # 3. Neither the name of the copyright holder nor the names of its contributors may be used to  #
-- #    endorse or promote products derived from this software without specific prior written      #
-- #    permission.                                                                                #
-- #                                                                                               #
-- # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS   #
-- # OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF               #
-- # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE    #
-- # COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,     #
-- # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE #
-- # GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED    #
-- # AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING     #
-- # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED  #
-- # OF THE POSSIBILITY OF SUCH DAMAGE.                                                            #
-- # ********************************************************************************************* #
-- # The NEORV32 RISC-V Processor - https://github.com/stnolting/neorv32                           #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_amp_sim is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   			: natural := 100000000; -- clock frequency of clk_i in Hz
    MEM_INT_DMEM_SIZE 			: natural := 32*1024;     -- size of processor-internal data memory in bytesf
    MEM_INT_IMEM_EN             : boolean := true;  -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE           : natural := 16*1024; -- size of processor-internal instruction memory in bytes
    IO_XIP_EN                   : boolean := false;   -- implement execute in place module (XIP)?
    INT_BOOTLOADER_EN           : boolean := false  -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM

  );
  port (
    -- Global control --
    clk_i       :   in  std_ulogic; -- global clock, rising edge
    rstn_i      :   in  std_ulogic; -- global reset, low-active, async
    
    -- GPIO --
    gpio_o      :   out std_ulogic_vector(7 downto 0); -- parallel output
    
    -- UART0 --
    uart0_txd_o :   out std_ulogic; -- UART0 send data
    uart0_rxd_i :   in  std_ulogic;  -- UART0 receive data

    -- ADC --
    adc_clk_i   :   in std_logic;   -- Simulation only! Master 49.152 MHZ clock for ADC
    adc_csn_o	:   out std_logic;  -- Chip Select (inv)
    adc_data_o	:	out std_logic;  -- Serial data out (Channel select)
    adc_data_i	:	in  std_logic;  -- Serial data in
    adc_clk_o	:	out std_logic;  -- Serial clock

    -- DAC --
    dac_pdm_o		    :	out std_logic

  );
end entity;

architecture neorv32_amp_rtl of neorv32_amp_sim is

component adc is
	port(
		 -- ADC --
    -- Interface to the TOP level
    adc_clk_i	: 	in std_logic;
    adc_rst_i	:	in std_logic;

    -- CPU clock input
    adc_cpu_clk_i	: 	in std_logic;

    --  wb_tag_i       : in std_ulogic_vector(02 downto 0); -- request tag
    wb_adr_i       : in std_ulogic_vector(31 downto 0) := (others => '0'); -- address
    wb_dat_i       : in  std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
    wb_dat_o       : out std_ulogic_vector(31 downto 0); -- write data
    wb_we_i        : in std_ulogic; -- read/write
    wb_sel_i       : in std_ulogic_vector(03 downto 0); -- byte enable
    wb_stb_i       : in std_ulogic; -- strobe
    wb_cyc_i       : in std_ulogic; -- valid cycle
    wb_ack_o       : out  std_ulogic := '0'; -- transfer acknowledge
    wb_err_o       : out  std_ulogic := '0'; -- transfer error
	 
    -- SPI interface to chip --
    adc_csn_o	:	out std_logic;
    adc_data_o	:	out std_logic;
    adc_data_i	:	in std_logic	:= 'X';
    adc_clk_o	:	out std_logic
	);
end component adc;

component dac is
	port(
		 -- DAC --
    -- Interface to the TOP level
    dac_clk_i	: 	in std_logic;
    dac_rst_i	:	in std_logic;

    -- CPU clock input
    dac_cpu_clk_i	: 	in std_logic;

    --  wb_tag_i       : in std_ulogic_vector(02 downto 0); -- request tag
    wb_adr_i       : in std_ulogic_vector(31 downto 0) := (others => '0'); -- address
    wb_dat_i       : in  std_ulogic_vector(31 downto 0) := (others => 'U'); -- read data
    wb_dat_o       : out std_ulogic_vector(31 downto 0); -- write data
    wb_we_i        : in std_ulogic; -- read/write
    wb_sel_i       : in std_ulogic_vector(03 downto 0); -- byte enable
    wb_stb_i       : in std_ulogic; -- strobe
    wb_cyc_i       : in std_ulogic; -- valid cycle
    wb_ack_o       : out  std_ulogic := '0'; -- transfer acknowledge
    wb_err_o       : out  std_ulogic := '0'; -- transfer error
   
    -- DAC Output --
    dac_pdm_o		    :	out std_logic	:= '1'
	);
end component dac;
  
  -- Wishbone bus interface (available if MEM_EXT_EN = true) --
  -- signal wb_tag_o       : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_adr         : std_ulogic_vector(31 downto 0):= (others => '0'); -- address
  signal wb_dat_sl_i    : std_ulogic_vector(31 downto 0):= (others => '0'); -- write data
  signal wb_we          : std_ulogic; -- read/write
  signal wb_sel         : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_stb         : std_ulogic; -- strobe
  signal wb_cyc         : std_ulogic; -- valid cycle
  signal wb_dat_sl_o    : std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
  signal wb_ack         : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_err         : std_ulogic := 'L'; -- transfer error

  -- ADC output signals
  signal wb_adc_dat_sl_o    : std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
  signal wb_adc_ack         : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_adc_err         : std_ulogic := 'L'; -- transfer error

  -- DAC output signals
  signal wb_dac_dat_sl_o    : std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
  signal wb_dac_ack         : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_dac_err         : std_ulogic := 'L'; -- transfer error

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN            => INT_BOOTLOADER_EN, -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    
    -- RISC-V CPU Extensions --
    CPU_EXTENSION_RISCV_B        => true,              -- implement bit-manipulation extension?
    CPU_EXTENSION_RISCV_C        => true,              -- implement compressed extension?
    CPU_EXTENSION_RISCV_M        => true,              -- implement mul/div extension?
    CPU_EXTENSION_RISCV_Zicsr    => true,              -- implement CSR system?
    CPU_EXTENSION_RISCV_Zicntr   => true,              -- implement base counters?
    CPU_EXTENSION_RISCV_Zfinx    => true,  				     -- implement 32-bit floating-point extension (using INT regs!)
    
    -- Tuning Options --
    FAST_MUL_EN                  => true,  				     -- use DSPs for M extension's multiplier
    FAST_SHIFT_EN                => true,  				     -- use barrel shifter for shift operations
    
    -- Internal Instruction memory --
    MEM_INT_IMEM_EN              => MEM_INT_IMEM_EN,             -- implement processor-internal instruction memory
    
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes
    
    -- Processor peripherals --
    IO_GPIO_EN                   => true,              -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_EN                  => true,              -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,              -- implement primary universal asynchronous receiver/transmitter (UART0)?
    
    -- XiP Peripheral, we'll do without the IMEM
    IO_XIP_EN							=> IO_XIP_EN,					           -- implement execute in place module (XIP)?

    -- External memory interface (WISHBONE) --
    MEM_EXT_EN                   => true,  -- implement external memory bus interface?
    MEM_EXT_TIMEOUT              => 255,    -- cycles after a pending bus access auto-terminates (0 = disabled)
    -- MEM_EXT_PIPE_MODE            : boolean := false;  -- protocol: false=classic/standard wishbone mode, true=pipelined wishbone mode
    -- MEM_EXT_BIG_ENDIAN           : boolean := false;  -- byte order: true=big-endian, false=little-endian
    -- MEM_EXT_ASYNC_RX             : boolean := false;  -- use register buffer for RX data when false
    -- MEM_EXT_ASYNC_TX             : boolean := false;  -- use register buffer for TX data when false
    
    -- Internal Instruction Cache (iCACHE) --
    ICACHE_EN                    => true,              -- implement instruction cache
    ICACHE_NUM_BLOCKS            => 8,                 -- i-cache: number of blocks (min 1), has to be a power of 2
    ICACHE_BLOCK_SIZE            => 256,               -- i-cache: block size in bytes (min 4), has to be a power of 2
    ICACHE_ASSOCIATIVITY         => 1                  -- i-cache: associativity / number of sets (1=direct_mapped), has to be a power of 2
  )
  port map (
    -- Global control --
    clk_i       => clk_i,                           -- global clock, rising edge
    -- clk_i       => pll0_clk,                           -- global clock, rising edge
    rstn_i      => rstn_i,                             -- global reset, low-active, async

    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o,                        -- UART0 send data
    uart0_rxd_i => uart0_rxd_i,                        -- UART0 receive data

    -- Wishbone bus interface (available if MEM_EXT_EN = true) --
    -- wb_tag_o    =>
    wb_adr_o    => wb_adr,                              -- address
    wb_dat_i    => wb_dat_sl_o,                         -- read data
    wb_dat_o    => wb_dat_sl_i,                         -- write data
    wb_we_o     => wb_we,                               -- read/write
    wb_sel_o    => wb_sel,                              -- byte enable
    wb_stb_o    => wb_stb,                              -- strobe
    wb_cyc_o    => wb_cyc,                              -- valid cycle
    wb_ack_i    => wb_ack,                              -- transfer acknowledge
    wb_err_i    => wb_err                              -- transfer error
  );

-- Use this component for ADC simulation
adc0: component adc
    port map (
    adc_clk_i	          => adc_clk_i,
    adc_cpu_clk_i       => clk_i,
    adc_rst_i	          => not rstn_i,
    adc_csn_o	          => adc_csn_o,
    adc_data_o	        => adc_data_o,
    adc_data_i	        => adc_data_i,
    adc_clk_o	          => adc_clk_o,
    
    -- Wishbone bus
    wb_adr_i	          => wb_adr,
    wb_dat_i	          => wb_dat_sl_i,
    wb_dat_o	          => wb_adc_dat_sl_o,
    wb_we_i 	          => wb_we,
    wb_sel_i	          => wb_sel,
    wb_stb_i	          => wb_stb,
    wb_cyc_i	          => wb_cyc,
    wb_ack_o	          => wb_adc_ack,
    wb_err_o	          => wb_adc_err
    ); 

    -- Use this component for DAC simulation
    dac0: component dac
      port map (
      dac_clk_i	          => adc_clk_i,
      dac_cpu_clk_i         => clk_i,
      dac_rst_i	          => not rstn_i,
      
      -- Wishbone bus
      wb_adr_i	          => wb_adr,
      wb_dat_i	          => wb_dat_sl_i,
      wb_dat_o	          => wb_dac_dat_sl_o,
      wb_we_i 	          => wb_we,
      wb_sel_i	          => wb_sel,
      wb_stb_i	          => wb_stb,
      wb_cyc_i	          => wb_cyc,
      wb_ack_o	          => wb_dac_ack,
      wb_err_o	          => wb_dac_err,

      -- DAC output
      dac_pdm_o           => dac_pdm_o
    );

  wb_ack <= wb_adc_ack or wb_dac_ack;
  wb_err <= wb_adc_err or wb_dac_err;

  process(wb_adc_ack, wb_dac_ack)
  begin
    if ((wb_adc_ack = '1')) then
      wb_dat_sl_o <= wb_adc_dat_sl_o;
    elsif ((wb_dac_ack = '1')) then
      wb_dat_sl_o <= wb_dac_dat_sl_o;
    else
      wb_dat_sl_o <= (others => '0');
    end if;
  end process;

end architecture; --neorv32_amp_sim
