-- #################################################################################################
-- # << PDM (Pulse Density Modulation) Testbench                                     >>            #
-- # ********************************************************************************************* #
-- # BSD 3-Clause License                                                                          #
-- #                                                                                               #
-- # Copyright (c) 2022, Alberto Fahrenkrog. All rights reserved.                                  #
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
-- # << PDM (Pulse Density Modulation) Testbench, Alberto Fahrenkrog                 >>            #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library pdm_test;
use pdm_test.all;

entity pdm_tb is

end pdm_tb;

architecture behav of pdm_tb is

    type mem16_t is array (0 to 15) of std_ulogic_vector(15 downto 0);

    constant test_data : mem16_t := (
              x"0111",
              x"0222",
              x"0333",
              x"0444",
              x"0555",
              x"0666",
              x"0777",
              x"0888",
              x"0999",
              x"0AAA",
              x"0BBB",
              x"0CCC",
              x"0DDD",
              x"0EEE",
              x"0FFF",
              x"0000"
    );

    signal clk_i    :   std_logic; -- 49.152 MHz
    signal data_i   :   std_ulogic_vector(15 downto 0); -- 16 bit data
    signal rstn_i   :   std_logic;
    signal pdm_out  :   std_logic;

        -- Timing
    constant clk_pdm_period: time := 20.34 ns;

begin
    -- connecting testbench signals with neorv32_amp_sim.vhd
    UUT : entity pdm
    port map (
    -- Global control --
    clk_i       => clk_i,
    rstn_i      => rstn_i,
    data_i      => data_i,
    pdm_out     => pdm_out
  );

    
      -- Clock process definition
  clk_process: process
  begin
    clk_i <= '0';
    wait for clk_pdm_period/2;
    clk_i <= '1';
    wait for clk_pdm_period/2;
  end process;

  rstn_i <= '0', '1' after 100 ns;

  data_i <= X"0000", X"3FFF" after 20 us, X"7FFF" after 40 us, X"FFFF" after 60 us;

	-- On a clock falling edge :
	-- - Push out new bit
	-- - Increment the bit counter
	-- process(adc_clk_o, rstn_i, adc_csn_o)
	-- begin
	-- 	if falling_edge(adc_clk_o) or falling_edge(adc_csn_o)then
	-- 		if rstn_i = '0' then
	-- 			bit_cnt <= X"0";
	-- 		else
    --     bit_cnt <= bit_cnt + 1;
    --     data_reg(15 downto 1) <= data_reg(14 downto 0);
    --     adc_data_i <= data_reg(15);
        
    --     if (bit_cnt = x"F") then
    --       data_reg <= test_data(to_integer(data_cnt));
    --       data_cnt <= data_cnt + 1;
    --     end if;
	-- 		end if;
	-- 	end if;
	-- end process;
    
end behav ;