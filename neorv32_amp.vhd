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
    CLOCK_FREQUENCY   : natural := 100000000; -- clock frequency of clk_i in Hz
    MEM_INT_DMEM_SIZE : natural := 32*1024     -- size of processor-internal data memory in bytes
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

	 -- Parallel data interface to TOP level (SLINK)
	 adc_par_dat_o	:	out std_ulogic_vector(15 downto 0);
	 adc_slink_we_o	:	out std_logic	:= '0';
	 adc_slink_lst_o:	out std_logic	:= '0';
	 adc_slink_rdy_i:	in std_logic;
	 
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
  signal con_gpio_o : std_ulogic_vector(63 downto 0);
    
  -- RX stream interfaces (available if SLINK_NUM_RX > 0) --
  signal slink_rx_dat_i : sdata_8x32_t;                  -- input data
  signal slink_rx_val_i : std_ulogic_vector(7 downto 0); -- valid input
  signal slink_rx_rdy_o : std_ulogic_vector(7 downto 0); -- ready to receive
  signal slink_rx_lst_i : std_ulogic_vector(7 downto 0); -- last data of packet

  -- ADC input data registers
  signal adc_par_dat_o    : std_ulogic_vector(15 downto 0) := X"0000";
  signal adc_slink_we_o	  : std_ulogic := '0';
  signal adc_slink_lst_o  : std_ulogic := '0';
  signal adc_slink_rdy_i  : std_ulogic := '1';

  -- Helper sync signals
  signal adc_slink_buf    : std_ulogic_vector(2 downto 0) := "000";

begin

  -- The Core Of The Problem ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------
  neorv32_top_inst: neorv32_top
  generic map (
    -- General --
    CLOCK_FREQUENCY              => CLOCK_FREQUENCY,   -- clock frequency of clk_i in Hz
    INT_BOOTLOADER_EN            => true,              -- boot configuration: true = boot explicit bootloader; false = boot from int/ext (I)MEM
    
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
    MEM_INT_IMEM_EN              => false,             -- implement processor-internal instruction memory
    
    -- Internal Data memory --
    MEM_INT_DMEM_EN              => true,              -- implement processor-internal data memory
    MEM_INT_DMEM_SIZE            => MEM_INT_DMEM_SIZE, -- size of processor-internal data memory in bytes
    
    -- Processor peripherals --
    IO_GPIO_EN                   => true,              -- implement general purpose input/output port unit (GPIO)?
    IO_MTIME_EN                  => true,              -- implement machine system timer (MTIME)?
    IO_UART0_EN                  => true,              -- implement primary universal asynchronous receiver/transmitter (UART0)?
    
    -- XiP Peripheral, we'll do without the IMEM
    IO_XIP_EN							=> true,					           -- implement execute in place module (XIP)?
    
    -- SLink RX Interface, we'll get the data from ADC here
    -- Stream link interface (SLINK) --
    SLINK_NUM_RX                 => 1,                 -- number of TX links (0..8)
    SLINK_RX_FIFO                => 256,               -- RX fifo depth, has to be a power of two
    
    -- Internal Instruction Cache (iCACHE) --
    ICACHE_EN                    => true,              -- implement instruction cache
    ICACHE_NUM_BLOCKS            => 8,                 -- i-cache: number of blocks (min 1), has to be a power of 2
    ICACHE_BLOCK_SIZE            => 256,               -- i-cache: block size in bytes (min 4), has to be a power of 2
    ICACHE_ASSOCIATIVITY         => 1                  -- i-cache: associativity / number of sets (1=direct_mapped), has to be a power of 2
    
    -- External memory interface (WISHBONE) --
    -- MEM_EXT_EN                   => true  -- implement external memory bus interface?

  )
  port map (
    -- Global control --
    clk_i       => pll0_clk,                           -- global clock, rising edge
    rstn_i      => resetn,                             -- global reset, low-active, async

    -- GPIO (available if IO_GPIO_EN = true) --
    gpio_o      => con_gpio_o,                         -- parallel output

    -- primary UART0 (available if IO_UART0_EN = true) --
    uart0_txd_o => uart0_txd_o,                        -- UART0 send data
    uart0_rxd_i => uart0_rxd_i,                        -- UART0 receive data

    -- RX stream interfaces (available if SLINK_NUM_RX > 0) --
    slink_rx_dat_i => slink_rx_dat_i,                  -- input data
    slink_rx_val_i => slink_rx_val_i,                  -- valid input
    slink_rx_rdy_o => slink_rx_rdy_o,                  -- ready to receive
    slink_rx_lst_i => slink_rx_lst_i,                  -- last data of packet

    -- XIP (execute in place via SPI) signals (available if IO_XIP_EN = true) --
    xip_clk_o => xip_clk_o,		                         -- SPI serial clock
    xip_sdo_o => xip_sdo_o,		                         -- controller data out, peripheral data in
    xip_sdi_i => xip_sdi_i,		                         -- controller data in, peripheral data out
    xip_csn_o => xip_csn_o			                       -- chip-select
  );
 
  -- QSys Components ----------------------------------------------------------------
  -- -------------------------------------------------------------------------------------------

u0 : component platform
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

adc0: component adc
		port map (
			 adc_clk_i	      => pll1_clk,
       adc_cpu_clk_i    => pll0_clk,
			 adc_rst_i	      => reset,
			 adc_csn_o	      => adc_csn_o,
			 adc_data_o	      => adc_data_o,
			 adc_data_i	      => adc_data_i,
			 adc_clk_o	      => test,
       adc_par_dat_o	  => adc_par_dat_o,
       adc_slink_we_o	  => adc_slink_we_o,
       adc_slink_lst_o  => adc_slink_lst_o, -- always '0', we stream continuously.
       adc_slink_rdy_i  => adc_slink_rdy_i
		);
  
    -- ADC Connections to SLINK
    slink_rx_dat_i(0)(15 downto 0) <= adc_par_dat_o;
    slink_rx_dat_i(0)(31 downto 16) <= X"0000";
    slink_rx_val_i(0) <= adc_slink_we_o;
    adc_slink_rdy_i <= slink_rx_rdy_o(0);
    slink_rx_lst_i(0) <= adc_slink_lst_o;

  
  -- GPIO output --
  gpio_o <= con_gpio_o(7 downto 0);
  reset <= not resetn;
  adc_clk_o <= test;
  test_d3_o <= test;
  

end architecture; --neorv32_amp
