-- #################################################################################################
-- # << ADC Testbench for the DE0 Nano												                       >>            #
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
-- # ADC Testbench for the DE0 Nano - Alberto Fahrenkrog					                       #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_amp_tb is

end neorv32_amp_tb;

architecture behav of neorv32_amp_tb is

    -- CPU
    signal clk_i        :   std_ulogic  := '0';
    signal rstn_i       :   std_ulogic  := '0';
    signal gpio_o       :   std_ulogic_vector(7 downto 0);
    signal uart0_txd_o  :   std_ulogic;
    signal uart0_rxd_i  :   std_ulogic;
    -- CPU - ADC
    signal adc_clk_i  : std_logic;   -- Simulation only! Master 49.152 MHZ clock for ADC
    signal adc_csn_o	: std_logic;  -- Chip Select (inv)
    signal adc_data_o	:	std_logic;  -- Serial data out (Channel select)
    signal adc_data_i	:	std_logic;  -- Serial data in
    signal adc_clk_o	:	std_logic;  -- Serial clock
    signal test_d3_o  : std_logic;  -- TEST PIN

    -- Timing
    constant clk_adc_period: time := 20.34 ns;
    constant clk_cpu_period: time := 10 ns;

    -- Memory holding test data
    type mem16_t is array (natural range <>) of std_ulogic_vector(15 downto 0); -- memory with 16-bit entries

    constant test_data : mem16_t := (
              x"0123",
              x"4567",
              x"89ab",
              x"cdef",
              x"fedc",
              x"ba98",
              x"7654",
              x"3210",
              x"0011",
              x"2233",
              x"4455",
              x"6677",
              x"8899",
              x"aabb",
              x"ccdd",
              x"eeff"
    );

    -- Data output signals
  	signal data_cnt 		:	unsigned(3 downto 0) := X"0";
  	signal bit_cnt 		  :	unsigned(3 downto 0) := X"0";
    signal data_reg     : std_ulogic_vector(15 downto 0) := x"0000";

begin
    -- connecting testbench signals with neorv32_amp_sim.vhd
    UUT : entity neorv32.neorv32_amp_sim 
    generic map(
        MEM_INT_IMEM_EN     => true,
        MEM_INT_IMEM_SIZE   => 128 * 1024,
        IO_XIP_EN           => false,
        INT_BOOTLOADER_EN   => false
    )
    port map (
    -- Global control --
    clk_i       => clk_i,
    rstn_i      => rstn_i,
    
    -- UART0 --
    uart0_txd_o => uart0_txd_o,
    uart0_rxd_i => uart0_rxd_i,

    -- ADC --
    adc_clk_i   => adc_clk_i,
    adc_csn_o	=> adc_csn_o,
    adc_data_o	=> adc_data_o,
    adc_data_i	=> adc_data_i,
    adc_clk_o	=> adc_clk_o
  );

    
      -- Clock process definition
  clk_process: process
  begin
    adc_clk_i <= '0';
    wait for clk_adc_period/2;
    adc_clk_i <= '1';
    wait for clk_adc_period/2;
  end process;  
  
  cpu_clk_process: process
  begin
    clk_i <= '0';
    wait for clk_cpu_period/2;
    clk_i <= '1';
    wait for clk_cpu_period/2;
  end process;

  rstn_i <= '0', '1' after 100 ns;

	-- On a clock falling edge :
	-- - Push out new bit
	-- - Increment the bit counter
	process(adc_clk_o, rstn_i, adc_csn_o)
	begin
		if falling_edge(adc_clk_o) or falling_edge(adc_csn_o)then
			if rstn_i = '0' then
				bit_cnt <= X"0";
			else
        bit_cnt <= bit_cnt + 1;
        data_reg(15 downto 1) <= data_reg(14 downto 0);
        adc_data_i <= data_reg(15);
        
        if (bit_cnt = x"F") then
          data_reg <= test_data(to_integer(data_cnt));
          data_cnt <= data_cnt + 1;
        end if;
			end if;
		end if;
	end process;
    
end behav ;