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

entity neorv32_amp is
  generic (
    -- adapt these for your setup --
    CLOCK_FREQUENCY   				: natural := 100000000; -- clock frequency of clk_i in Hz
    MEM_INT_DMEM_SIZE 				: natural := 32*1024;     -- size of processor-internal data memory in bytes
    MEM_INT_IMEM_EN              : boolean := false;  -- implement processor-internal instruction memory
    MEM_INT_IMEM_SIZE            : natural := 16*1024; -- size of processor-internal instruction memory in bytes
    IO_XIP_EN                    : boolean := true;   -- implement execute in place module (XIP)?
    INT_BOOTLOADER_EN            : boolean := true  -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM

  );
  port (
    -- Global control --
    clk_i       : in  std_ulogic; -- global clock, rising edge
    rstn_i      : in  std_ulogic; -- global reset, low-active, async
    
    -- GPIO --
    gpio_o      : out std_ulogic_vector(7 downto 0); -- parallel output
    
    -- UART0 --
    uart0_txd_o : out std_ulogic; -- UART0 send data
    uart0_rxd_i : in  std_ulogic;  -- UART0 receive data
    
    -- XIP --
    xip_clk_o   : out std_ulogic; -- serial clock
    xip_sdo_o   : out std_ulogic; -- controller data output
    xip_sdi_i   : in  std_ulogic; -- device data input
    xip_csn_o   : out std_ulogic;	 -- chip-select, low-active

    -- ADC --
    adc_csn_o	  :	out std_logic;  -- Chip Select (inv)
    adc_data_o	:	out std_logic;  -- Serial data out (Channel select)
    adc_data_i	:	in  std_logic;  -- Serial data in
    adc_clk_o	  :	out std_logic;  -- Serial clock
	 
	 -- Test --
	 -- Pin D3
	 test_d3_o	: out std_logic
  );
end entity;

architecture neorv32_amp_rtl of neorv32_amp is

  -- QSys Components ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------

  component platform is
    port (
      clk_src_i_clk         : in  std_logic := 'X'; -- clk
      clk_src_rst_i_reset_n : in  std_logic := 'X'; -- reset_n
      clk_src_o_clk         : out std_logic;        -- clk
      clk_src_rst_o_reset_n : out std_logic;        -- reset_n
      pll0_clk_o_clk        : out std_logic;        -- clk
      pll0_rst_i_reset      : in  std_logic := 'X'; -- reset
      pll0_clk_i_clk        : in  std_logic := 'X'; -- clk
      pll1_clk_i_clk        : in  std_logic := 'X'; -- clk
      pll1_rst_i_reset      : in  std_logic := 'X'; -- reset
      pll1_clk_o_clk        : out std_logic         -- clk
    );
end component platform;

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
	
	-- QSys interface
  signal main_clk: std_logic;
  signal pll0_clk: std_logic;
  signal pll1_clk: std_logic;
  signal resetn: std_logic;
  signal reset: std_logic;
  
  signal test: std_logic;
  
  -- NEORV32 LEDs
  signal con_gpio_o : std_ulogic_vector(63 downto 0):= (others => '0');    
  
  -- Wishbone bus interface (available if MEM_EXT_EN = true) --
  -- signal wb_tag_o       : std_ulogic_vector(02 downto 0); -- request tag
  signal wb_adr         : std_ulogic_vector(31 downto 0):= (others => '0'); -- address
  signal wb_dat_sl_o    : std_ulogic_vector(31 downto 0) := (others => '0'); -- read data
  signal wb_dat_sl_i    : std_ulogic_vector(31 downto 0):= (others => '0'); -- write data
  signal wb_we          : std_ulogic; -- read/write
  signal wb_sel         : std_ulogic_vector(03 downto 0); -- byte enable
  signal wb_stb         : std_ulogic; -- strobe
  signal wb_cyc         : std_ulogic; -- valid cycle
  signal wb_ack         : std_ulogic := 'L'; -- transfer acknowledge
  signal wb_err         : std_ulogic := 'L'; -- transfer error

  -- ADC input data registers
  signal adc_par_dat_o    : std_ulogic_vector(15 downto 0) := X"0000";

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN            => INT_BOOTLOADER_EN,              -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    
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
    -- clk_i       => clk_i,                           -- global clock, rising edge
    clk_i       => pll0_clk,                           -- global clock, rising edge
    rstn_i      => resetn,                             -- global reset, low-active, async

    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o      => con_gpio_o,                         -- parallel output

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
    wb_err_i    => wb_err,                              -- transfer error

    -- XIP (execute in place via SPI) signals (available if IO_XIP_EN = true) --
    xip_clk_o => xip_clk_o,		                         -- SPI serial clock
    xip_sdo_o => xip_sdo_o,		                         -- controller data out, peripheral data in
    xip_sdi_i => xip_sdi_i,		                         -- controller data in, peripheral data out
    xip_csn_o => xip_csn_o			                       -- chip-select
  );
 
  -- QSys Components ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------

QSYS : component platform
    port map (
      clk_src_i_clk         => clk_i,         --     clk_src_i.clk
      clk_src_rst_i_reset_n => rstn_i, -- clk_src_rst_i.reset_n
      clk_src_o_clk         => main_clk,         --     clk_src_o.clk
      clk_src_rst_o_reset_n => resetn, -- clk_src_rst_o.reset_n
      pll0_clk_o_clk        => pll0_clk,        --    pll0_clk_o.clk
      pll0_rst_i_reset      => reset,      --    pll0_rst_i.reset
      pll0_clk_i_clk        => main_clk,        --    pll0_clk_i.clk
      pll1_clk_i_clk        => main_clk,        --    pll1_clk_i.clk
      pll1_rst_i_reset      => reset,      --    pll1_rst_i.reset
      pll1_clk_o_clk        => pll1_clk         --    pll1_clk_o.clk
    );

-- Generate this ADC if it's not a simulation
adc0: component adc
    port map (
      adc_clk_i	            => pll1_clk,
      adc_cpu_clk_i         => pll0_clk,
      adc_rst_i	            => reset,
      adc_csn_o	            => adc_csn_o,
      adc_data_o	          => adc_data_o,
      adc_data_i	          => adc_data_i,
      adc_clk_o	            => test,
      
      -- Wishbone bus
      wb_adr_i	            => wb_adr,
      wb_dat_i	            => wb_dat_sl_i,
      wb_dat_o	            => wb_dat_sl_o,
      wb_we_i 	            => wb_we,
      wb_sel_i	            => wb_sel,
      wb_stb_i	            => wb_stb,
      wb_cyc_i	            => wb_cyc,
      wb_ack_o	            => wb_ack,
      wb_err_o	            => wb_err
    );
  
  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);
  reset <= not resetn;
  adc_clk_o <= test;
  test_d3_o <= test;
  

end architecture; --neorv32_amp
